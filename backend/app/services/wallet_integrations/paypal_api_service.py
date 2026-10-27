"""
PayPal REST API v2 (Orders) Integration — SANDBOX ONLY

Client bas niveau pour l'API officielle PayPal Orders v2 :
- POST /v1/oauth2/token                    (client_credentials)
- POST /v2/checkout/orders                 (création de commande, intent=CAPTURE)
- GET  /v2/checkout/orders/{id}            (vérification du statut côté serveur)
- POST /v2/checkout/orders/{id}/capture    (capture après approbation du payeur)

Référence : https://developer.paypal.com/docs/api/orders/v2/

Règles de sécurité :
- Les identifiants (client_id / client_secret) et le jeton d'accès ne sont jamais journalisés.
- Chaque écriture (création / capture) envoie un en-tête PayPal-Request-Id pour l'idempotence.
- Une erreur réseau n'est jamais interprétée comme un échec : elle lève PayPalNetworkError
  (résultat inconnu) pour que l'appelant vérifie le statut avant toute nouvelle tentative.
"""

import re
import logging
import requests
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional

from ...config import settings

logger = logging.getLogger("PayPalAPI")

ORDER_ID_PATTERN = re.compile(r"^[A-Z0-9]{8,64}$")


class PayPalConfigurationError(Exception):
    """Les identifiants sandbox PayPal ne sont pas configurés côté backend."""


class PayPalNetworkError(Exception):
    """Timeout ou erreur de connexion : le résultat de l'opération est inconnu."""


class PayPalAPIError(Exception):
    """Réponse d'erreur HTTP explicite renvoyée par PayPal."""

    def __init__(self, status_code: int, name: str = "", issue: str = "", message: str = "", debug_id: str = ""):
        self.status_code = status_code
        self.name = name or "PAYPAL_ERROR"
        self.issue = issue or ""
        self.message = message or ""
        self.debug_id = debug_id or ""
        super().__init__(f"PayPal {status_code} {self.name}/{self.issue} (debug_id={self.debug_id}): {self.message}")


class PayPalAPIService:
    """Client PayPal Orders v2 limité au sandbox."""

    def __init__(self, session: Optional[requests.Session] = None):
        self._session = session or requests.Session()
        self._cached_token: Optional[str] = None
        self._token_expires_at: Optional[datetime] = None

    # ------------------------------------------------------------------
    # Configuration
    # ------------------------------------------------------------------

    @property
    def base_url(self) -> str:
        return settings.PAYPAL_API_BASE

    def is_configured(self) -> bool:
        return settings.paypal_configured

    def _timeout(self):
        return (10, settings.PAYPAL_HTTP_TIMEOUT_SECONDS)

    def reset_token_cache(self):
        self._cached_token = None
        self._token_expires_at = None

    # ------------------------------------------------------------------
    # OAuth2
    # ------------------------------------------------------------------

    def _get_access_token(self) -> str:
        if not self.is_configured():
            raise PayPalConfigurationError(
                "PAYPAL_CLIENT_ID et PAYPAL_CLIENT_SECRET (sandbox) doivent être définis dans backend/.env."
            )

        if self._cached_token and self._token_expires_at and datetime.utcnow() < self._token_expires_at:
            return self._cached_token

        try:
            resp = self._session.post(
                f"{self.base_url}/v1/oauth2/token",
                auth=(settings.PAYPAL_CLIENT_ID, settings.PAYPAL_CLIENT_SECRET),
                data={"grant_type": "client_credentials"},
                headers={"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"},
                timeout=self._timeout(),
            )
        except requests.exceptions.RequestException as e:
            raise PayPalNetworkError(f"OAuth2 PayPal injoignable: {type(e).__name__}") from e

        if resp.status_code != 200:
            body = _safe_json(resp)
            logger.warning(f"[PayPal OAuth] Échec d'authentification sandbox (HTTP {resp.status_code}, error={body.get('error')})")
            raise PayPalAPIError(
                resp.status_code,
                name=str(body.get("error") or "AUTHENTICATION_FAILURE"),
                message=str(body.get("error_description") or "Authentification PayPal refusée."),
            )

        body = _safe_json(resp)
        token = body.get("access_token")
        if not token:
            raise PayPalAPIError(resp.status_code, name="AUTHENTICATION_FAILURE", message="Réponse OAuth2 sans access_token.")

        expires_in = int(body.get("expires_in", 300))
        self._cached_token = token
        self._token_expires_at = datetime.utcnow() + timedelta(seconds=max(expires_in - 60, 30))
        logger.info("[PayPal OAuth] Jeton d'accès sandbox obtenu.")
        return token

    # ------------------------------------------------------------------
    # HTTP
    # ------------------------------------------------------------------

    def _request(self, method: str, path: str, json_body: Optional[dict] = None, request_id: Optional[str] = None,
                 _retry_auth: bool = True) -> Dict[str, Any]:
        token = self._get_access_token()
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Prefer": "return=representation",
        }
        if request_id:
            headers["PayPal-Request-Id"] = request_id

        try:
            resp = self._session.request(method, f"{self.base_url}{path}", json=json_body, headers=headers, timeout=self._timeout())
        except requests.exceptions.RequestException as e:
            logger.error(f"[PayPal API] {method} {path} : erreur réseau ({type(e).__name__}) — résultat inconnu.")
            raise PayPalNetworkError(f"{method} {path} : {type(e).__name__}") from e

        if resp.status_code == 401 and _retry_auth:
            # Jeton expiré ou révoqué : un seul renouvellement
            self.reset_token_cache()
            return self._request(method, path, json_body, request_id, _retry_auth=False)

        body = _safe_json(resp)
        if resp.status_code >= 400:
            details = body.get("details") or []
            first = details[0] if details and isinstance(details[0], dict) else {}
            err = PayPalAPIError(
                resp.status_code,
                name=str(body.get("name") or ""),
                issue=str(first.get("issue") or ""),
                message=str(first.get("description") or body.get("message") or ""),
                debug_id=str(body.get("debug_id") or resp.headers.get("Paypal-Debug-Id", "")),
            )
            logger.warning(f"[PayPal API] {method} {path} rejeté : HTTP {err.status_code} {err.name}/{err.issue} debug_id={err.debug_id}")
            raise err

        logger.info(f"[PayPal API] {method} {path} -> HTTP {resp.status_code} status={body.get('status')} id={body.get('id')}")
        return body

    # ------------------------------------------------------------------
    # Orders v2
    # ------------------------------------------------------------------

    def create_order(self, *, reference_id: str, currency: str, total: str, items: List[Dict[str, Any]],
                     description: str, request_id: str, custom_id: str) -> Dict[str, Any]:
        """Crée une commande intent=CAPTURE. Aucun débit n'a lieu à cette étape."""
        body = {
            "intent": "CAPTURE",
            "purchase_units": [
                {
                    "reference_id": reference_id,
                    "custom_id": custom_id,
                    "description": description[:127],
                    "amount": {
                        "currency_code": currency,
                        "value": total,
                        "breakdown": {"item_total": {"currency_code": currency, "value": total}},
                    },
                    "items": items,
                }
            ],
            "payment_source": {
                "paypal": {
                    "experience_context": {
                        "brand_name": settings.PAYPAL_BRAND_NAME[:127],
                        "shipping_preference": "NO_SHIPPING",
                        # CONTINUE : le payeur revient dans SIKA pour la revue finale avant capture
                        "user_action": "CONTINUE",
                        "return_url": settings.PAYPAL_RETURN_URL,
                        "cancel_url": settings.PAYPAL_CANCEL_URL,
                    }
                }
            },
        }
        return self._request("POST", "/v2/checkout/orders", json_body=body, request_id=request_id)

    def get_order(self, order_id: str) -> Dict[str, Any]:
        _validate_order_id(order_id)
        return self._request("GET", f"/v2/checkout/orders/{order_id}")

    def capture_order(self, order_id: str, request_id: str) -> Dict[str, Any]:
        _validate_order_id(order_id)
        return self._request("POST", f"/v2/checkout/orders/{order_id}/capture", json_body={}, request_id=request_id)

    # ------------------------------------------------------------------
    # Webhooks (Notifications v1)
    # ------------------------------------------------------------------

    def list_webhooks(self) -> List[Dict[str, Any]]:
        return self._request("GET", "/v1/notifications/webhooks").get("webhooks") or []

    def create_webhook(self, url: str, event_types: List[str]) -> Dict[str, Any]:
        body = {"url": url, "event_types": [{"name": n} for n in event_types]}
        return self._request("POST", "/v1/notifications/webhooks", json_body=body)

    def verify_webhook_signature(self, *, headers: Dict[str, str], event: Dict[str, Any], webhook_id: str) -> bool:
        """Vérification officielle de la signature (POST /v1/notifications/verify-webhook-signature)."""
        body = {
            "auth_algo": headers.get("paypal-auth-algo", ""),
            "cert_url": headers.get("paypal-cert-url", ""),
            "transmission_id": headers.get("paypal-transmission-id", ""),
            "transmission_sig": headers.get("paypal-transmission-sig", ""),
            "transmission_time": headers.get("paypal-transmission-time", ""),
            "webhook_id": webhook_id,
            "webhook_event": event,
        }
        result = self._request("POST", "/v1/notifications/verify-webhook-signature", json_body=body)
        return result.get("verification_status") == "SUCCESS"

    # ------------------------------------------------------------------
    # Log in with PayPal (OpenID Connect)
    # ------------------------------------------------------------------

    def exchange_authorization_code(self, code: str) -> Dict[str, Any]:
        """Échange le code d'autorisation de l'utilisateur contre son jeton (POST /v1/oauth2/token)."""
        if not self.is_configured():
            raise PayPalConfigurationError("PAYPAL_CLIENT_ID et PAYPAL_CLIENT_SECRET (sandbox) doivent être définis.")
        try:
            resp = self._session.post(
                f"{self.base_url}/v1/oauth2/token",
                auth=(settings.PAYPAL_CLIENT_ID, settings.PAYPAL_CLIENT_SECRET),
                data={"grant_type": "authorization_code", "code": code},
                headers={"Accept": "application/json", "Content-Type": "application/x-www-form-urlencoded"},
                timeout=self._timeout(),
            )
        except requests.exceptions.RequestException as e:
            raise PayPalNetworkError(f"OAuth2 PayPal injoignable: {type(e).__name__}") from e
        body = _safe_json(resp)
        if resp.status_code != 200 or not body.get("access_token"):
            logger.warning(f"[PayPal Login] Échange du code refusé (HTTP {resp.status_code}, error={body.get('error')})")
            raise PayPalAPIError(resp.status_code, name=str(body.get("error") or "INVALID_GRANT"),
                                 message=str(body.get("error_description") or "Code d'autorisation PayPal invalide ou expiré."))
        return body

    def get_userinfo(self, user_access_token: str) -> Dict[str, Any]:
        """Profil du payeur connecté (GET /v1/identity/oauth2/userinfo?schema=paypalv1.1)."""
        try:
            resp = self._session.request(
                "GET",
                f"{self.base_url}/v1/identity/oauth2/userinfo?schema=paypalv1.1",
                headers={"Authorization": f"Bearer {user_access_token}", "Accept": "application/json"},
                timeout=self._timeout(),
            )
        except requests.exceptions.RequestException as e:
            raise PayPalNetworkError(f"userinfo PayPal injoignable: {type(e).__name__}") from e
        body = _safe_json(resp)
        if resp.status_code != 200:
            raise PayPalAPIError(resp.status_code, name=str(body.get("name") or body.get("error") or "USERINFO_FAILED"),
                                 message=str(body.get("message") or body.get("error_description") or ""))
        return body

    # ------------------------------------------------------------------
    # Helpers de lecture des réponses
    # ------------------------------------------------------------------

    @staticmethod
    def extract_approve_url(order: Dict[str, Any]) -> Optional[str]:
        for link in order.get("links") or []:
            if link.get("rel") in ("payer-action", "approve") and link.get("href"):
                return link["href"]
        return None

    @staticmethod
    def extract_capture(order: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        for unit in order.get("purchase_units") or []:
            captures = ((unit.get("payments") or {}).get("captures")) or []
            if captures:
                return captures[0]
        return None


def _validate_order_id(order_id: str):
    if not order_id or not ORDER_ID_PATTERN.match(str(order_id)):
        raise ValueError("Identifiant de commande PayPal invalide.")


def _safe_json(resp) -> Dict[str, Any]:
    try:
        data = resp.json()
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


paypal_api_service = PayPalAPIService()
