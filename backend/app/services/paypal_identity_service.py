"""
SIKA Pay — Connexion avec PayPal (Log in with PayPal, OpenID Connect, sandbox).

Parcours :
1. GET  /api/v1/sika/auth/paypal/start  → URL d'autorisation PayPal + `state` signé (10 min).
2. L'utilisateur s'authentifie sur PayPal, qui redirige vers PAYPAL_LOGIN_REDIRECT_URI
   (sikapay://paypal/login?code=…&state=…), intercepté par l'application.
3. POST /api/v1/sika/auth/paypal {code, state} → le serveur vérifie `state`, échange le code avec
   le secret client (jamais exposé à l'application), lit le profil PayPal et ouvre la session SIKA.

Le statut « compte vérifié par PayPal » provient uniquement de la réponse userinfo de PayPal.
"""

import uuid
import logging
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional
from urllib.parse import urlencode

import jwt
from fastapi import HTTPException

from ..config import settings
from ..database import SessionLocal
from ..models.user import UserModel
from .user_profile import profile_status
from .wallet_integrations.paypal_api_service import (
    paypal_api_service, PayPalAPIError, PayPalNetworkError, PayPalConfigurationError,
)

logger = logging.getLogger("SikaPayPalIdentity")

_STATE_PURPOSE = "paypal_login"
_STATE_TTL = timedelta(minutes=10)


def _truthy(value: Any) -> bool:
    return value is True or str(value).strip().lower() == "true"


def normalize_userinfo(info: Dict[str, Any]) -> Dict[str, Any]:
    """Extrait les champs utiles d'une réponse userinfo PayPal (schéma paypalv1.1 ou openid)."""
    emails = info.get("emails") or []
    primary = next((e for e in emails if e.get("primary")), emails[0] if emails else {})
    email = (primary.get("value") or info.get("email") or "").strip().lower()
    email_confirmed = _truthy(primary.get("confirmed")) if primary else _truthy(info.get("email_verified"))
    address = info.get("address") or {}
    return {
        "payer_id": info.get("payer_id") or None,
        "user_id": info.get("user_id") or info.get("sub") or None,
        "name": (info.get("name") or " ".join(filter(None, [info.get("given_name"), info.get("family_name")]))).strip(),
        "email": email,
        "email_confirmed": email_confirmed,
        "country": (address.get("country") or "").strip().upper() or None,
        "verified_account": _truthy(info.get("verified_account")),
    }


class PayPalIdentityService:
    def __init__(self, api=None):
        self.api = api or paypal_api_service

    def _secret(self) -> str:
        from .auth_service import oauth2_auth_service
        return oauth2_auth_service.SECRET_KEY

    def start(self) -> Dict[str, Any]:
        if not self.api.is_configured():
            raise HTTPException(status_code=503, detail={"error_code": "PAYPAL_NOT_CONFIGURED",
                                                         "message": "La connexion PayPal n'est pas configurée sur le serveur."})
        now = datetime.now(timezone.utc)
        state = jwt.encode({"purpose": _STATE_PURPOSE, "nonce": uuid.uuid4().hex, "iat": now, "exp": now + _STATE_TTL},
                           self._secret(), algorithm="HS256")
        query = urlencode({
            "flowEntry": "static",
            "client_id": settings.PAYPAL_CLIENT_ID,
            "response_type": "code",
            "scope": settings.PAYPAL_LOGIN_SCOPES,
            "redirect_uri": settings.PAYPAL_LOGIN_REDIRECT_URI,
            "state": state,
        })
        return {
            "authorize_url": f"{settings.PAYPAL_WEB_BASE}/connect?{query}",
            "redirect_uri": settings.PAYPAL_LOGIN_REDIRECT_URI,
            "environment": "sandbox",
        }

    def _verify_state(self, state: str):
        try:
            payload = jwt.decode(state or "", self._secret(), algorithms=["HS256"])
        except jwt.InvalidTokenError:
            raise HTTPException(status_code=400, detail={"error_code": "INVALID_STATE",
                                                         "message": "La connexion PayPal a expiré ou est invalide. Recommencez."})
        if payload.get("purpose") != _STATE_PURPOSE:
            raise HTTPException(status_code=400, detail={"error_code": "INVALID_STATE", "message": "Paramètre state invalide."})

    def complete(self, code: str, state: str) -> Dict[str, Any]:
        self._verify_state(state)
        if not code or len(code) > 2048:
            raise HTTPException(status_code=400, detail={"error_code": "INVALID_CODE", "message": "Code PayPal manquant."})
        try:
            tokens = self.api.exchange_authorization_code(code)
            info = normalize_userinfo(self.api.get_userinfo(tokens["access_token"]))
        except PayPalConfigurationError as e:
            raise HTTPException(status_code=503, detail={"error_code": "PAYPAL_NOT_CONFIGURED", "message": str(e)})
        except PayPalNetworkError:
            raise HTTPException(status_code=503, detail={"error_code": "PAYPAL_UNREACHABLE",
                                                         "message": "PayPal est injoignable. Réessayez dans un instant."})
        except PayPalAPIError as e:
            raise HTTPException(status_code=401, detail={"error_code": "PAYPAL_LOGIN_REFUSED",
                                                         "message": f"PayPal a refusé la connexion ({e.name})."})

        if not info["payer_id"] and not info["user_id"]:
            raise HTTPException(status_code=502, detail={"error_code": "PAYPAL_PROFILE_INCOMPLETE",
                                                         "message": "PayPal n'a pas renvoyé d'identifiant de compte."})
        if not info["email"]:
            raise HTTPException(status_code=400, detail={"error_code": "PAYPAL_EMAIL_MISSING",
                                                         "message": "Autorisez le partage de votre e-mail PayPal pour continuer."})
        return self._sign_in(info)

    def _sign_in(self, info: Dict[str, Any]) -> Dict[str, Any]:
        from .auth_service import oauth2_auth_service
        payer_key = info["payer_id"] or info["user_id"]
        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.paypal_payer_id == payer_key).first()
            if not user:
                existing = db.query(UserModel).filter(UserModel.email == info["email"]).first()
                if existing:
                    # Rattachement à un compte existant uniquement si PayPal confirme l'adresse e-mail
                    if not info["email_confirmed"]:
                        raise HTTPException(status_code=409, detail={
                            "error_code": "EMAIL_NOT_CONFIRMED",
                            "message": "Un compte SIKA Pay utilise déjà cet e-mail. Confirmez-le chez PayPal ou connectez-vous par e-mail."})
                    if existing.paypal_payer_id and existing.paypal_payer_id != payer_key:
                        raise HTTPException(status_code=409, detail={
                            "error_code": "ACCOUNT_ALREADY_LINKED",
                            "message": "Ce compte SIKA Pay est déjà relié à un autre compte PayPal."})
                    user = existing
                else:
                    user = UserModel(email=info["email"], full_name=info["name"] or "", auth_provider="paypal", kyc_status="none")
                    db.add(user)
                user.paypal_payer_id = payer_key

            # Compléter le profil sans écraser ce que l'utilisateur a déjà saisi
            if info["name"] and (not user.full_name or user.full_name == "David YAO"):
                user.full_name = info["name"]
            if info["country"] and not user.country:
                user.country = info["country"]
            if info["verified_account"]:
                user.kyc_status = "paypal"
                user.is_kyc_verified = True
            db.commit()
            db.refresh(user)

            user_data = {
                "id": str(user.id),
                "full_name": user.full_name,
                "email": user.email,
                "auth_provider": user.auth_provider,
                "is_paypal_auth": True,
            }
            token = oauth2_auth_service.create_access_token(user_data)
            logger.info(f"[SIKA PAY LOGIN] Utilisateur {user.id} connecté via PayPal (vérifié={info['verified_account']}).")
            return {
                "access_token": token,
                "token_type": "bearer",
                "expires_in": oauth2_auth_service.TOKEN_EXPIRE_HOURS * 3600,
                "user": {**user_data, "phone": user.phone, "country": user.country},
                "profile": profile_status(user),
            }
        finally:
            db.close()


paypal_identity_service = PayPalIdentityService()
