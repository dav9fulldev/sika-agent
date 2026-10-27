"""
SIKA Pay — Abonnements PayPal (sandbox).

- Les plans du SIKA Demo Store sont créés côté marchand via le serveur MCP de PayPal
  (scripts/paypal_seed_subscription_plans.py) ; leur prix est relu auprès de PayPal avant toute souscription.
- L'agent peut chercher et préparer un abonnement, jamais le souscrire : un paiement récurrent est toujours
  confirmé par l'utilisateur dans l'app, puis approuvé par le payeur sur PayPal.
- Le statut affiché est toujours celui renvoyé par PayPal (retour du payeur, webhook ou vérification).
"""

import logging
import time
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from ..config import settings
from ..database import engine
from ..models.paypal_subscription import PayPalSubscriptionModel
from . import demo_subscriptions
from .wallet_integrations.paypal_api_service import (
    paypal_api_service, PayPalAPIError, PayPalNetworkError, PayPalConfigurationError,
)

logger = logging.getLogger("SikaPayPalSubscriptions")

PLAN_CACHE_SECONDS = 600
PAYPAL_TO_SIKA = {
    "APPROVAL_PENDING": "AWAITING_PAYPAL_APPROVAL",
    "APPROVED": "APPROVED",
    "ACTIVE": "ACTIVE",
    "SUSPENDED": "SUSPENDED",
    "CANCELLED": "CANCELLED",
    "EXPIRED": "EXPIRED",
}
TERMINAL = ("CANCELLED", "EXPIRED", "FAILED")


class SubscriptionError(Exception):
    def __init__(self, code: str, message: str, http_status: int = 400, data: Optional[Dict[str, Any]] = None):
        self.code = code
        self.message = message
        self.http_status = http_status
        self.data = data or {}
        super().__init__(f"{code}: {message}")

    def to_dict(self) -> Dict[str, Any]:
        return {"success": False, "error_code": self.code, "message": self.message, **self.data}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    return (dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)).isoformat()


class PayPalSubscriptionService:
    def __init__(self, api=None):
        self.api = api or paypal_api_service
        self._plans: Dict[str, str] = {}
        self._plans_at = 0.0

    # ------------------------------------------------------------------
    # Plans (créés via MCP, relus en REST)
    # ------------------------------------------------------------------

    def _plan_ids(self) -> Dict[str, str]:
        if self._plans and time.time() - self._plans_at < PLAN_CACHE_SECONDS:
            return self._plans
        found, page = {}, 1
        while page <= 10:
            res = self.api.list_plans(page)
            for plan in res.get("plans") or []:
                desc = plan.get("description") or ""
                if plan.get("status") == "ACTIVE" and desc.startswith(demo_subscriptions.PLAN_TAG):
                    found.setdefault(desc[len(demo_subscriptions.PLAN_TAG):].split(" ", 1)[0], plan["id"])
            if page >= int(res.get("total_pages") or 1):
                break
            page += 1
        self._plans, self._plans_at = found, time.time()
        return found

    def verified_plan(self, key: str) -> Dict[str, str]:
        """Plan du catalogue dont le prix mensuel est confirmé par PayPal (jamais un prix venant du modèle)."""
        entry = demo_subscriptions.get_plan(key)
        if not entry:
            raise SubscriptionError("UNKNOWN_PLAN", f"No subscription plan '{key}' in the SIKA Demo Store.", 404)
        try:
            plan_id = self._plan_ids().get(key)
            if not plan_id:
                raise SubscriptionError("PLAN_UNAVAILABLE", "This plan is not available on PayPal yet.", 503)
            plan = self.api.get_plan(plan_id)
        except (PayPalNetworkError, PayPalConfigurationError):
            raise SubscriptionError("PAYPAL_UNREACHABLE", "PayPal could not be reached to verify the plan.", 503)
        except PayPalAPIError as e:
            raise SubscriptionError("PLAN_UNAVAILABLE", f"PayPal could not return this plan ({e.issue or e.name}).", 503)
        cycles = [c for c in plan.get("billing_cycles") or [] if c.get("tenure_type") == "REGULAR"]
        fixed = ((cycles[0].get("pricing_scheme") or {}).get("fixed_price") or {}) if cycles else {}
        if plan.get("status") != "ACTIVE" or fixed.get("currency_code") != demo_subscriptions.CURRENCY \
                or Decimal(str(fixed.get("value") or "0")) != Decimal(entry["price"]):
            raise SubscriptionError("PLAN_MISMATCH", "The PayPal plan does not match the SIKA catalog. It was not offered.", 409)
        return {**entry, "plan_id": plan_id, "price": f"{Decimal(str(fixed['value'])):.2f}"}

    # ------------------------------------------------------------------
    # Vues
    # ------------------------------------------------------------------

    @staticmethod
    def to_public(row: PayPalSubscriptionModel) -> Dict[str, Any]:
        return {
            "type": "paypal_subscription",
            "subscription_ref": row.subscription_ref,
            "plan_key": row.plan_key,
            "name": row.name,
            "price": row.price,
            "currency": row.currency,
            "interval": "month",
            "status": row.status,
            "paypal": {
                "subscription_id": row.paypal_subscription_id,
                "status": row.paypal_status or None,
                "approve_url": row.approve_url if row.status == "AWAITING_PAYPAL_APPROVAL" else None,
                "next_billing_time": row.next_billing_time,
            },
            "price_verified_with_paypal": True,
            "last_error": {"code": row.last_error_code, "message": row.last_error_message} if row.last_error_code else None,
            "created_at": _iso(row.created_at),
            "updated_at": _iso(row.updated_at),
        }

    def _owned(self, db: Session, user_id: int, ref: str) -> PayPalSubscriptionModel:
        row = db.get(PayPalSubscriptionModel, str(ref))
        if not row or row.user_id != user_id:
            raise SubscriptionError("NOT_FOUND", "Subscription not found.", 404)
        return row

    def list(self, user_id: int, sync: bool = False) -> List[Dict[str, Any]]:
        with Session(engine) as db:
            rows = db.query(PayPalSubscriptionModel).filter(
                PayPalSubscriptionModel.user_id == user_id,
                PayPalSubscriptionModel.status != "AWAITING_USER_CONFIRMATION",
            ).order_by(PayPalSubscriptionModel.updated_at.desc()).limit(20).all()
            refs = [r.subscription_ref for r in rows]
        if sync:
            for ref in refs[:5]:
                try:
                    self.sync(user_id, ref)
                except SubscriptionError:
                    pass
        with Session(engine) as db:
            return [self.to_public(db.get(PayPalSubscriptionModel, r)) for r in refs]

    # ------------------------------------------------------------------
    # Parcours : préparer → confirmer (utilisateur) → approuver (PayPal) → actif
    # ------------------------------------------------------------------

    def prepare(self, user_id: int, plan_key: str) -> Dict[str, Any]:
        plan = self.verified_plan(plan_key)
        now = _now()
        with Session(engine) as db:
            for old in db.query(PayPalSubscriptionModel).filter(PayPalSubscriptionModel.user_id == user_id,
                                                                PayPalSubscriptionModel.status == "AWAITING_USER_CONFIRMATION").all():
                old.status, old.updated_at = "CANCELLED", now
                old.last_error_code, old.last_error_message = "REPLACED_BY_NEW_REQUEST", "A newer subscription request replaced this one."
            row = PayPalSubscriptionModel(
                subscription_ref=f"sub_{uuid.uuid4().hex[:24]}", user_id=user_id, plan_key=plan["key"],
                plan_id=plan["plan_id"], name=plan["name"], price=plan["price"], currency=demo_subscriptions.CURRENCY,
                status="AWAITING_USER_CONFIRMATION", request_id=f"sika-sub-{uuid.uuid4()}", created_at=now, updated_at=now,
            )
            db.add(row)
            db.commit()
            db.refresh(row)
            return self.to_public(row)

    def confirm(self, user_id: int, ref: str) -> Dict[str, Any]:
        """Confirmation explicite de l'utilisateur : crée l'abonnement PayPal et renvoie le lien d'approbation."""
        with Session(engine) as db:
            row = self._owned(db, user_id, ref)
            if row.status == "AWAITING_PAYPAL_APPROVAL":
                return self.to_public(row)
            if row.status != "AWAITING_USER_CONFIRMATION":
                raise SubscriptionError("INVALID_STATE", f"This subscription cannot be confirmed (status {row.status}).", 409)
            locked = db.query(PayPalSubscriptionModel).filter(
                PayPalSubscriptionModel.subscription_ref == row.subscription_ref,
                PayPalSubscriptionModel.status == "AWAITING_USER_CONFIRMATION",
            ).update({"status": "CREATING", "updated_at": _now()}, synchronize_session=False)
            if locked != 1:
                db.rollback()
                raise SubscriptionError("CONCURRENT_REQUEST", "This subscription is already being processed.", 409)
            db.commit()
            db.refresh(row)
            try:
                created = self.api.create_subscription(
                    plan_id=row.plan_id, custom_id=row.subscription_ref, request_id=row.request_id,
                    brand_name=settings.PAYPAL_BRAND_NAME,
                    return_url=f"{settings.PUBLIC_BASE_URL}/api/v1/paypal/subscriptions-return",
                    cancel_url=f"{settings.PUBLIC_BASE_URL}/api/v1/paypal/subscriptions-cancel",
                )
            except (PayPalNetworkError, PayPalConfigurationError):
                # Le même PayPal-Request-Id est réutilisé à la prochaine tentative : pas de doublon
                row.status, row.updated_at = "AWAITING_USER_CONFIRMATION", _now()
                db.commit()
                raise SubscriptionError("PAYPAL_UNREACHABLE", "PayPal could not be reached. Nothing was set up; you can retry.", 503)
            except PayPalAPIError as e:
                row.status, row.updated_at = "FAILED", _now()
                row.last_error_code, row.last_error_message = (e.issue or e.name)[:80], (e.message or "PayPal refused the subscription.")[:255]
                db.commit()
                raise SubscriptionError("PAYPAL_REJECTED", f"PayPal refused the subscription ({e.issue or e.name}).", 502)
            approve = next((l.get("href") for l in created.get("links") or [] if l.get("rel") == "approve"), None)
            row.paypal_subscription_id = created.get("id")
            row.paypal_status = str(created.get("status") or "")
            row.status = PAYPAL_TO_SIKA.get(row.paypal_status, "AWAITING_PAYPAL_APPROVAL")
            row.approve_url = approve if approve and approve.startswith("https://") and ".paypal.com/" in approve else None
            row.updated_at = _now()
            db.commit()
            db.refresh(row)
            logger.info(f"[SIKA PAY] Subscription {row.subscription_ref} created at PayPal: {row.paypal_status}")
            return self.to_public(row)

    def _apply_paypal(self, db: Session, row: PayPalSubscriptionModel) -> None:
        sub = self.api.get_subscription(row.paypal_subscription_id)
        row.paypal_status = str(sub.get("status") or row.paypal_status)
        row.status = PAYPAL_TO_SIKA.get(row.paypal_status, row.status)
        row.next_billing_time = ((sub.get("billing_info") or {}).get("next_billing_time")) or row.next_billing_time
        row.updated_at = _now()
        if row.status in ("ACTIVE", "APPROVED"):
            row.last_error_code = row.last_error_message = None
        db.commit()

    def sync(self, user_id: int, ref: str) -> Dict[str, Any]:
        with Session(engine) as db:
            row = self._owned(db, user_id, ref)
            if row.paypal_subscription_id and row.status not in ("FAILED",):
                try:
                    self._apply_paypal(db, row)
                except (PayPalNetworkError, PayPalConfigurationError):
                    pass  # dernier statut vérifié conservé
                except PayPalAPIError as e:
                    logger.warning(f"[SIKA PAY] Subscription sync failed: {e.issue or e.name}")
            return self.to_public(row)

    def cancel(self, user_id: int, ref: str) -> Dict[str, Any]:
        """Résiliation demandée par l'utilisateur dans l'app (jamais par l'agent)."""
        with Session(engine) as db:
            row = self._owned(db, user_id, ref)
            if row.status in TERMINAL:
                return self.to_public(row)
            if row.paypal_subscription_id and row.status in ("ACTIVE", "SUSPENDED", "APPROVED"):
                try:
                    self.api.cancel_subscription(row.paypal_subscription_id, "Cancelled by the subscriber in SIKA Pay")
                    self._apply_paypal(db, row)
                except (PayPalNetworkError, PayPalConfigurationError):
                    raise SubscriptionError("PAYPAL_UNREACHABLE", "PayPal could not be reached. The subscription is still active.", 503)
                except PayPalAPIError as e:
                    raise SubscriptionError("PAYPAL_REJECTED", f"PayPal refused the cancellation ({e.issue or e.name}).", 502)
            else:
                # Jamais approuvé sur PayPal : rien n'est facturé, on clôt la demande
                row.status, row.updated_at = "CANCELLED", _now()
                row.last_error_code, row.last_error_message = "USER_CANCELLED", "Cancelled before approval. Nothing was charged."
                db.commit()
            return self.to_public(row)

    # ------------------------------------------------------------------
    # Retour PayPal et webhooks (statut toujours relu auprès de PayPal)
    # ------------------------------------------------------------------

    def refresh_by_paypal_id(self, paypal_subscription_id: str) -> Optional[str]:
        with Session(engine) as db:
            row = db.query(PayPalSubscriptionModel).filter(
                PayPalSubscriptionModel.paypal_subscription_id == str(paypal_subscription_id)).first()
            if not row:
                return None
            try:
                self._apply_paypal(db, row)
            except (PayPalNetworkError, PayPalAPIError, PayPalConfigurationError, ValueError) as e:
                logger.warning(f"[SIKA PAY] Subscription refresh failed: {type(e).__name__}")
            return row.status


paypal_subscription_service = PayPalSubscriptionService()
