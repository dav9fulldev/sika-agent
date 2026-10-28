"""
SIKA Pay — Compte PayPal enregistré (PayPal Vault v3).

Libre choix de l'utilisateur :
- sans compte relié, chaque paiement est approuvé sur PayPal (parcours standard) ;
- avec un compte relié ET une autorisation active, SIKA paie dans les limites de l'autorisation, sans redirection.

Relier le compte demande une approbation explicite sur PayPal ; le délier supprime le jeton chez PayPal.
Le modèle d'IA n'a accès à aucune de ces opérations : seuls l'utilisateur (routes authentifiées) et le serveur
(confirmation sous autorisation) s'en servent.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from ..config import settings
from ..database import engine
from ..models.paypal_vault import PayPalVaultModel
from .wallet_integrations.paypal_api_service import (
    paypal_api_service, PayPalAPIError, PayPalConfigurationError, PayPalNetworkError,
)

logger = logging.getLogger("SikaPayPalVault")


class VaultError(Exception):
    def __init__(self, code: str, message: str, http_status: int = 400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.http_status = http_status

    def to_dict(self) -> Dict[str, Any]:
        return {"success": False, "error_code": self.code, "message": self.message}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _mask_email(email: Optional[str]) -> Optional[str]:
    if not email or "@" not in email:
        return None
    name, domain = email.split("@", 1)
    return f"{name[:2]}***@{domain}"[:127]


def _is_paypal_url(url: Optional[str]) -> bool:
    return bool(url) and url.startswith(("https://www.sandbox.paypal.com/", "https://sandbox.paypal.com/"))


class PayPalVaultService:
    def __init__(self, api=None):
        self.api = api or paypal_api_service

    @staticmethod
    def _return_urls() -> Dict[str, str]:
        base = settings.PUBLIC_BASE_URL.rstrip("/")
        return {"return_url": f"{base}/api/v1/paypal/vault-return", "cancel_url": f"{base}/api/v1/paypal/vault-cancel"}

    @staticmethod
    def _active(db: Session, user_id: int) -> Optional[PayPalVaultModel]:
        return (db.query(PayPalVaultModel)
                .filter(PayPalVaultModel.user_id == user_id, PayPalVaultModel.status == "ACTIVE")
                .order_by(PayPalVaultModel.created_at.desc()).first())

    def active_payment_token(self, db: Session, user_id: int) -> Optional[str]:
        """Jeton utilisable pour payer à la place de l'utilisateur (sous autorisation), sinon None."""
        row = self._active(db, user_id)
        return row.payment_token_id if row else None

    def status(self, user_id: int) -> Dict[str, Any]:
        with Session(engine) as db:
            row = self._active(db, user_id)
            if not row:
                return {"linked": False}
            return {"linked": True, "payer_email": row.payer_email_masked,
                    "linked_at": row.updated_at.replace(tzinfo=timezone.utc).isoformat()}

    def start_link(self, user_id: int) -> Dict[str, Any]:
        """Crée un setup token ; l'utilisateur l'approuve sur PayPal (lien renvoyé à l'app)."""
        if not self.api.is_configured():
            raise VaultError("PAYPAL_NOT_CONFIGURED", "PayPal is not configured on the SIKA backend.", 503)
        request_id = f"sika-vault-{uuid.uuid4().hex}"
        try:
            token = self.api.create_vault_setup_token(request_id=request_id, **self._return_urls())
        except PayPalNetworkError:
            raise VaultError("PAYPAL_UNREACHABLE", "PayPal could not be reached. Nothing was saved; try again.", 503)
        except (PayPalAPIError, PayPalConfigurationError) as e:
            logger.warning(f"[VAULT] Setup token refused: {type(e).__name__}")
            raise VaultError("PAYPAL_REJECTED", "PayPal could not start linking your account. Nothing was saved.", 502)

        setup_id = str(token.get("id") or "")
        approve_url = self.api.extract_approve_url(token)
        if not setup_id or not _is_paypal_url(approve_url):
            raise VaultError("PAYPAL_REJECTED", "PayPal did not return a valid approval link. Nothing was saved.", 502)
        with Session(engine) as db:
            db.add(PayPalVaultModel(user_id=user_id, setup_token_id=setup_id, request_id=request_id,
                                    status="PENDING_APPROVAL", created_at=_now(), updated_at=_now()))
            db.commit()
        return {"approve_url": approve_url, "linked": False}

    def complete_link(self, setup_token_id: str) -> str:
        """Retour de PayPal après approbation : échange le setup token contre un jeton de paiement.

        Appelé par la page de retour (sans session) : le setup token, approuvé par le payeur sur PayPal, est
        rattaché à l'utilisateur qui l'a créé. Renvoie le statut obtenu.
        """
        with Session(engine) as db:
            row = db.query(PayPalVaultModel).filter(PayPalVaultModel.setup_token_id == setup_token_id).first()
            if not row:
                return "UNKNOWN"
            if row.status != "PENDING_APPROVAL":
                return row.status
            try:
                token = self.api.create_vault_payment_token(setup_token_id, request_id=f"{row.request_id}-pt")
            except PayPalNetworkError:
                return "PENDING_APPROVAL"  # la page de retour peut être rechargée : même PayPal-Request-Id
            except (PayPalAPIError, ValueError) as e:
                row.status, row.last_error_code, row.updated_at = "FAILED", type(e).__name__[:80], _now()
                db.commit()
                return "FAILED"

            payment_token_id = str(token.get("id") or "")
            paypal_source = (token.get("payment_source") or {}).get("paypal") or {}
            if not payment_token_id:
                row.status, row.last_error_code, row.updated_at = "FAILED", "NO_PAYMENT_TOKEN", _now()
                db.commit()
                return "FAILED"

            # Un seul compte relié à la fois : l'ancien est délié chez PayPal
            for old in db.query(PayPalVaultModel).filter(PayPalVaultModel.user_id == row.user_id,
                                                          PayPalVaultModel.status == "ACTIVE").all():
                self._delete_remote(old.payment_token_id)
                old.status, old.updated_at = "REVOKED", _now()

            row.payment_token_id = payment_token_id
            row.customer_id = str((token.get("customer") or {}).get("id") or "")[:64] or None
            row.payer_email_masked = _mask_email(paypal_source.get("email_address"))
            row.status, row.updated_at = "ACTIVE", _now()
            db.commit()
            logger.info(f"[VAULT] PayPal account linked for user {row.user_id}")
            return "ACTIVE"

    def unlink(self, user_id: int) -> Dict[str, Any]:
        with Session(engine) as db:
            rows = db.query(PayPalVaultModel).filter(PayPalVaultModel.user_id == user_id,
                                                     PayPalVaultModel.status.in_(("ACTIVE", "PENDING_APPROVAL"))).all()
            for row in rows:
                if row.payment_token_id:
                    self._delete_remote(row.payment_token_id)
                row.status, row.updated_at = "REVOKED", _now()
            db.commit()
        return {"linked": False}

    def _delete_remote(self, payment_token_id: Optional[str]):
        if not payment_token_id:
            return
        try:
            self.api.delete_vault_payment_token(payment_token_id)
        except PayPalAPIError as e:
            if e.status_code != 404:
                logger.warning(f"[VAULT] PayPal refused to delete a payment token: {e.issue or e.name}")
        except (PayPalNetworkError, ValueError) as e:
            # Le jeton n'est plus utilisé par SIKA dans tous les cas (statut REVOKED)
            logger.warning(f"[VAULT] Payment token deletion not confirmed: {type(e).__name__}")


paypal_vault_service = PayPalVaultService()
