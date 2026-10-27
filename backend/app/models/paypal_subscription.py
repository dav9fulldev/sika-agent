"""
Abonnements PayPal souscrits via SIKA (plans du SIKA Demo Store, sandbox).

Cycle : AWAITING_USER_CONFIRMATION -> CREATING -> AWAITING_PAYPAL_APPROVAL -> APPROVED -> ACTIVE
        avec les sorties CANCELLED, SUSPENDED, EXPIRED, FAILED.
Un abonnement est toujours confirmé par l'utilisateur (paiement récurrent) puis approuvé sur PayPal.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from ..database import Base


class PayPalSubscriptionModel(Base):
    __tablename__ = "paypal_subscriptions"
    __table_args__ = (Index("ix_paypal_subscriptions_user_status", "user_id", "status"),)

    subscription_ref = Column(String(40), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    plan_key = Column(String(64), nullable=False)
    plan_id = Column(String(64), nullable=False)
    name = Column(String(127), nullable=False)
    price = Column(String(20), nullable=False)
    currency = Column(String(3), nullable=False, default="USD")
    status = Column(String(32), nullable=False, default="AWAITING_USER_CONFIRMATION")
    paypal_subscription_id = Column(String(64), nullable=True, unique=True, index=True)
    paypal_status = Column(String(32), nullable=False, default="")
    approve_url = Column(String(512), nullable=True)
    request_id = Column(String(64), nullable=False)
    next_billing_time = Column(String(40), nullable=True)
    last_error_code = Column(String(80), nullable=True)
    last_error_message = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
