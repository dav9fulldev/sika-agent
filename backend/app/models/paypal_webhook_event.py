"""Événements webhook PayPal déjà traités (déduplication : PayPal peut renvoyer un même événement)."""

from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime
from ..database import Base


class PayPalWebhookEventModel(Base):
    __tablename__ = "paypal_webhook_events"

    event_id = Column(String(64), primary_key=True)
    event_type = Column(String(80), nullable=False)
    resource_id = Column(String(64), nullable=True)
    outcome = Column(String(80), nullable=True)
    received_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
