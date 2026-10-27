"""
SIKA Pay — Autorisation de l'agent (mode hybride).

L'utilisateur choisit s'il confirme lui-même chaque achat (par défaut) ou s'il autorise l'agent à
confirmer pour lui, avec trois limites qu'il fixe : montant maximal par achat, total par jour et durée.
Ces limites sont vérifiées ici, côté serveur, à chaque confirmation par l'agent ; le modèle ne peut
ni les lire pour les contourner ni les modifier. L'autorisation est révocable à tout moment.
"""

from datetime import datetime, timezone, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Dict, Optional

from sqlalchemy.orm import Session

from ..config import settings
from ..database import engine
from ..models.agent_mandate import AgentMandateModel
from ..models.paypal_checkout import PayPalCheckoutModel

CENT = Decimal("0.01")
MAX_DURATION_HOURS = 24 * 30
# Achats confirmés par l'agent qui comptent dans le total du jour (les annulés et expirés n'ont rien coûté)
_COUNTED_STATUSES = ("CREATING_ORDER", "AWAITING_PAYPAL_APPROVAL", "APPROVED", "CAPTURING", "COMPLETED", "PENDING", "UNKNOWN_RESULT")


class MandateError(Exception):
    def __init__(self, code: str, message: str, http_status: int = 400):
        self.code = code
        self.message = message
        self.http_status = http_status
        super().__init__(f"{code}: {message}")

    def to_dict(self) -> Dict[str, Any]:
        return {"success": False, "error_code": self.code, "message": self.message}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _utc(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is not None and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


def _amount(value: Any, field: str) -> Decimal:
    try:
        dec = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        raise MandateError("INVALID_LIMIT", f"{field} must be a number.")
    if isinstance(value, bool) or not dec.is_finite() or dec <= 0:
        raise MandateError("INVALID_LIMIT", f"{field} must be a positive amount.")
    return dec.quantize(CENT, rounding=ROUND_HALF_UP)


class AgentMandateService:

    def _active_row(self, db: Session, user_id: int) -> Optional[AgentMandateModel]:
        row = db.query(AgentMandateModel).filter(
            AgentMandateModel.user_id == user_id,
            AgentMandateModel.revoked_at.is_(None),
        ).order_by(AgentMandateModel.id.desc()).first()
        if row and _utc(row.expires_at) > _now():
            return row
        return None

    def _spent_today(self, db: Session, user_id: int) -> Decimal:
        start = _now().replace(hour=0, minute=0, second=0, microsecond=0)
        rows = db.query(PayPalCheckoutModel).filter(
            PayPalCheckoutModel.user_id == user_id,
            PayPalCheckoutModel.confirmed_by == "AGENT",
            PayPalCheckoutModel.status.in_(_COUNTED_STATUSES),
            PayPalCheckoutModel.created_at >= start.replace(tzinfo=None),
        ).all()
        return sum((Decimal(r.total_amount) for r in rows), Decimal("0.00"))

    def _public(self, db: Session, row: Optional[AgentMandateModel], user_id: int) -> Dict[str, Any]:
        if not row:
            return {"active": False}
        spent = self._spent_today(db, user_id)
        return {
            "active": True,
            "max_per_purchase": row.max_per_purchase,
            "daily_limit": row.daily_limit,
            "currency": row.currency,
            "spent_today": str(spent.quantize(CENT)),
            "remaining_today": str(max(Decimal(row.daily_limit) - spent, Decimal("0")).quantize(CENT)),
            "expires_at": _utc(row.expires_at).isoformat(),
            "created_at": _utc(row.created_at).isoformat() if row.created_at else None,
        }

    def get(self, user_id: int) -> Dict[str, Any]:
        with Session(engine) as db:
            return self._public(db, self._active_row(db, user_id), user_id)

    def grant(self, user_id: int, max_per_purchase: Any, daily_limit: Any, duration_hours: Any) -> Dict[str, Any]:
        per = _amount(max_per_purchase, "max_per_purchase")
        daily = _amount(daily_limit, "daily_limit")
        ceiling = Decimal(str(settings.PAYPAL_MAX_ORDER_AMOUNT)).quantize(CENT)
        if per > ceiling:
            raise MandateError("INVALID_LIMIT", f"max_per_purchase cannot exceed the SIKA Pay limit of {ceiling} USD.")
        if daily < per:
            raise MandateError("INVALID_LIMIT", "daily_limit must be at least max_per_purchase.")
        try:
            hours = int(duration_hours)
        except (TypeError, ValueError):
            raise MandateError("INVALID_DURATION", "duration_hours must be a whole number.")
        if isinstance(duration_hours, bool) or not 1 <= hours <= MAX_DURATION_HOURS:
            raise MandateError("INVALID_DURATION", f"duration_hours must be between 1 and {MAX_DURATION_HOURS}.")

        now = _now()
        with Session(engine) as db:
            # Une seule autorisation active : la nouvelle remplace la précédente
            for old in db.query(AgentMandateModel).filter(AgentMandateModel.user_id == user_id,
                                                          AgentMandateModel.revoked_at.is_(None)).all():
                old.revoked_at = now
            row = AgentMandateModel(user_id=user_id, max_per_purchase=str(per), daily_limit=str(daily), currency="USD",
                                    expires_at=now + timedelta(hours=hours), created_at=now)
            db.add(row)
            db.commit()
            db.refresh(row)
            return self._public(db, row, user_id)

    def revoke(self, user_id: int) -> Dict[str, Any]:
        with Session(engine) as db:
            for row in db.query(AgentMandateModel).filter(AgentMandateModel.user_id == user_id,
                                                          AgentMandateModel.revoked_at.is_(None)).all():
                row.revoked_at = _now()
            db.commit()
            return {"active": False}

    def is_active(self, user_id: int) -> bool:
        with Session(engine) as db:
            return self._active_row(db, user_id) is not None

    def check_purchase(self, db: Session, user_id: int, total: str, currency: str) -> AgentMandateModel:
        """Vérifie qu'un achat respecte l'autorisation active. Lève MandateError sinon."""
        row = self._active_row(db, user_id)
        if not row:
            raise MandateError("NO_ACTIVE_AUTHORIZATION",
                               "You have not authorized SIKA to confirm purchases. Confirm this one in the app.", 403)
        if currency != row.currency:
            raise MandateError("AUTHORIZATION_CURRENCY", f"Your authorization covers {row.currency} purchases only.", 403)
        amount = Decimal(total)
        if amount > Decimal(row.max_per_purchase):
            raise MandateError("ABOVE_AUTHORIZED_AMOUNT",
                               f"{total} {currency} is above the {row.max_per_purchase} {currency} per purchase you authorized. "
                               "Confirm it yourself in the app.", 403)
        if self._spent_today(db, user_id) + amount > Decimal(row.daily_limit):
            raise MandateError("DAILY_LIMIT_REACHED",
                               f"This purchase would exceed your daily limit of {row.daily_limit} {currency}. "
                               "Confirm it yourself in the app.", 403)
        return row


agent_mandate_service = AgentMandateService()
