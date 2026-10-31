"""
SIKA Pay — Tableau de bord web (AG Studio), en lecture seule.

Connexion : l'app (utilisateur connecté) demande un code à usage unique valable 10 minutes ;
le navigateur l'échange contre un jeton limité au tableau de bord (scope « dashboard », 2 heures).
Ce jeton ne permet ni de payer ni de modifier le compte : il n'est accepté que par les routes du tableau de bord.

Données : les paiements PayPal de l'utilisateur, les produits suivis, les changements signalés,
les abonnements et l'autorisation accordée à SIKA. Montants et statuts viennent de la base, jamais de l'IA.
"""

import hashlib
import secrets
import threading
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from ..database import engine
from ..models.dashboard_login_code import DashboardLoginCodeModel
from ..models.paypal_checkout import PayPalCheckoutModel
from ..models.paypal_subscription import PayPalSubscriptionModel
from ..models.price_watch import PriceWatchModel, UserNotificationModel
from ..models.user import UserModel
from . import demo_catalog

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # sans 0/O ni 1/I : lisible à l'écran
CODE_LENGTH = 8
CODE_TTL = timedelta(minutes=10)
SESSION_TTL = timedelta(hours=2)
MAX_FAILURES_PER_IP = 10
FAILURE_WINDOW_SECONDS = 600

STATUS_LABELS = {
    "COMPLETED": "Paid",
    "AWAITING_USER_CONFIRMATION": "Awaiting your confirmation",
    "AWAITING_PAYPAL_APPROVAL": "Awaiting PayPal approval",
    "APPROVED": "Approved on PayPal",
    "CAPTURING": "Capturing",
    "CANCELLED": "Cancelled",
    "EXPIRED": "Expired",
    "FAILED": "Failed",
    "UNKNOWN_RESULT": "Being verified",
    "REFUNDED": "Refunded",
    "DECLINED": "Declined by PayPal",
    "PENDING": "Pending at PayPal",
}
CHANGE_LABELS = {
    "target_reached": "Target price reached",
    "price_drop": "Price drop",
    "price_rise": "Price increase",
    "back_in_stock": "Back in stock",
    "out_of_stock": "Out of stock",
    "new_offer": "Cheaper offer",
    "offer_removed": "Offer removed",
}


class DashboardError(Exception):
    def __init__(self, code: str, message: str, http_status: int = 400):
        self.code = code
        self.message = message
        self.http_status = http_status
        super().__init__(f"{code}: {message}")

    def to_dict(self) -> Dict[str, Any]:
        return {"success": False, "error_code": self.code, "message": self.message}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _iso(dt: Optional[datetime]) -> Optional[str]:
    return _aware(dt).isoformat() if dt else None


def _num(value: Any) -> Optional[float]:
    try:
        return float(Decimal(str(value))) if value not in (None, "") else None
    except (InvalidOperation, ValueError):
        return None


def normalize_code(code: str) -> str:
    return "".join(c for c in (code or "").upper() if c in CODE_ALPHABET)


def _hash(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


class DashboardService:
    def __init__(self):
        self._failures: Dict[str, List[float]] = {}
        self._lock = threading.Lock()

    # ------------------------------------------------------------------
    # Connexion par code
    # ------------------------------------------------------------------

    def create_code(self, user_id: int) -> Dict[str, Any]:
        code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(CODE_LENGTH))
        now = _now()
        with Session(engine) as db:
            # Un seul code valide à la fois par utilisateur
            db.query(DashboardLoginCodeModel).filter(DashboardLoginCodeModel.user_id == user_id,
                                                     DashboardLoginCodeModel.used_at.is_(None)).delete()
            db.add(DashboardLoginCodeModel(code_hash=_hash(code), user_id=user_id, expires_at=now + CODE_TTL, created_at=now))
            db.commit()
        return {"code": f"{code[:4]}-{code[4:]}", "expires_in": int(CODE_TTL.total_seconds())}

    def _too_many_failures(self, client_ip: str) -> bool:
        cutoff = time.time() - FAILURE_WINDOW_SECONDS
        with self._lock:
            recent = [t for t in self._failures.get(client_ip, []) if t > cutoff]
            self._failures[client_ip] = recent
            return len(recent) >= MAX_FAILURES_PER_IP

    def _record_failure(self, client_ip: str) -> None:
        with self._lock:
            self._failures.setdefault(client_ip, []).append(time.time())

    def exchange_code(self, code: str, client_ip: str = "unknown") -> Dict[str, Any]:
        from .auth_service import oauth2_auth_service

        if self._too_many_failures(client_ip):
            raise DashboardError("TOO_MANY_ATTEMPTS", "Too many attempts. Wait a few minutes and try again.", 429)
        clean = normalize_code(code)
        invalid = DashboardError("INVALID_CODE", "This code is not valid or has expired. Show a new code in the app.", 400)
        if len(clean) != CODE_LENGTH:
            self._record_failure(client_ip)
            raise invalid
        now = _now()
        with Session(engine) as db:
            row = db.get(DashboardLoginCodeModel, _hash(clean))
            if not row or row.used_at is not None or _aware(row.expires_at) < now:
                self._record_failure(client_ip)
                raise invalid
            row.used_at = now  # usage unique
            user = db.get(UserModel, row.user_id)
            db.commit()
            if not user:
                raise invalid
            token = oauth2_auth_service.create_access_token(
                {"user_id": user.id, "email": user.email, "name": user.full_name, "scope": "dashboard"},
                expires_delta=SESSION_TTL)
            return {"access_token": token, "token_type": "bearer", "expires_in": int(SESSION_TTL.total_seconds())}

    # ------------------------------------------------------------------
    # Données
    # ------------------------------------------------------------------

    def data(self, user_id: int) -> Dict[str, Any]:
        from .agent_mandate_service import agent_mandate_service

        with Session(engine) as db:
            user = db.get(UserModel, user_id)
            checkouts = db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.user_id == user_id) \
                .order_by(PayPalCheckoutModel.created_at.desc()).limit(500).all()
            watches = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id,
                                                       PriceWatchModel.status != "cancelled") \
                .order_by(PriceWatchModel.updated_at.desc()).limit(200).all()
            notes = db.query(UserNotificationModel).filter(UserNotificationModel.user_id == user_id) \
                .order_by(UserNotificationModel.created_at.desc()).limit(500).all()
            subs = db.query(PayPalSubscriptionModel).filter(PayPalSubscriptionModel.user_id == user_id) \
                .order_by(PayPalSubscriptionModel.created_at.desc()).limit(100).all()

            payments = []
            for c in checkouts:
                product = demo_catalog.get_product(c.sku) or {}
                paid = c.capture_status == "COMPLETED"
                payments.append({
                    "paymentId": c.checkout_id,
                    "date": _iso(c.created_at),
                    "product": c.item_name,
                    "category": (product.get("category") or "other").capitalize(),
                    "merchant": c.merchant_name,
                    "quantity": c.quantity,
                    "amount": _num(c.captured_amount if paid else c.total_amount),
                    "paidAmount": _num(c.captured_amount) if paid else 0.0,
                    "currency": c.captured_currency or c.currency,
                    "status": "Paid" if paid else STATUS_LABELS.get(c.status, c.status.replace("_", " ").capitalize()),
                    # Valeurs stockées : USER / AGENT et PAYPAL_APPROVAL / SAVED_PAYPAL
                    "confirmedBy": "SIKA, within your authorization" if (c.confirmed_by or "").upper() == "AGENT" else "You",
                    "paymentMethod": "Saved PayPal account" if (c.payment_method or "").upper() == "SAVED_PAYPAL" else "PayPal approval",
                    "budget": _num(c.budget_limit),
                    "isPaid": paid,
                })

            now = _now()
            followed = []
            for w in watches:
                if w.source == "auto" and w.expires_at and _aware(w.expires_at) < now:
                    continue
                followed.append({
                    "product": w.title,
                    "followedBy": "SIKA (automatic)" if w.source == "auto" else "Your price alert",
                    "status": {"active": "Following", "triggered": "Alert triggered"}.get(w.status, w.status),
                    "bestPrice": _num(w.last_price),
                    "bestMerchant": w.last_merchant,
                    "targetPrice": _num(w.target_price),
                    "currency": w.currency,
                    "followedSince": _iso(w.created_at),
                    "followedUntil": _iso(w.expires_at),
                })

            changes = []
            for n in notes:
                price, before = _num(n.price), _num(n.previous_price)
                changes.append({
                    "date": _iso(n.created_at),
                    "product": n.title,
                    "change": CHANGE_LABELS.get(n.kind, n.kind),
                    "merchant": n.merchant,
                    "price": price,
                    "previousPrice": before,
                    "changePercent": round((price - before) / before, 4) if price and before else None,
                    "currency": n.currency,
                })

            subscriptions = [{
                "plan": s.name,
                "price": _num(s.price),
                "currency": s.currency,
                "status": s.status.replace("_", " ").capitalize(),
                "nextBilling": s.next_billing_time,
                "startedOn": _iso(s.created_at),
            } for s in subs]

            first_name = ((user.full_name or "").split() or [""])[0] if user else ""

        mandate = agent_mandate_service.get(user_id)
        authorization = [{
            "active": bool(mandate.get("active")),
            "maxPerPurchase": _num(mandate.get("max_per_purchase")),
            "dailyLimit": _num(mandate.get("daily_limit")),
            "spentToday": _num(mandate.get("spent_today")) or 0.0,
            "remainingToday": _num(mandate.get("remaining_today")),
            "currency": mandate.get("currency") or "USD",
            "expiresAt": mandate.get("expires_at"),
        }]
        return {
            "user": {"first_name": first_name},
            "generated_at": _iso(now),
            "tables": {
                "payments": payments,
                "followed_products": followed,
                "price_changes": changes,
                "subscriptions": subscriptions,
                "authorization": authorization,
            },
        }


dashboard_service = DashboardService()
