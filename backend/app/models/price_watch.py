"""
Surveillance de prix d'un produit trouvé sur le web (Channel3).

L'utilisateur (ou l'agent, à sa demande) choisit un prix cible ; Channel3 notifie les changements
d'offre par webhook et SIKA déclenche l'alerte quand une offre neuve passe sous ce prix
(ou revient en stock si aucun prix cible n'est fixé). Aucun achat n'est fait automatiquement.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from ..database import Base


class PriceWatchModel(Base):
    __tablename__ = "price_watches"
    __table_args__ = (Index("ix_price_watches_user_status", "user_id", "status"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(String(64), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    image_url = Column(String(512), nullable=True)
    target_price = Column(String(20), nullable=True)  # None = alerte de retour en stock
    currency = Column(String(3), nullable=False, default="USD")
    subscription_id = Column(String(64), nullable=True, index=True)
    status = Column(String(12), nullable=False, default="active")  # active | triggered | cancelled
    last_price = Column(String(20), nullable=True)
    last_merchant = Column(String(120), nullable=True)
    last_event = Column(String(40), nullable=True)
    triggered_at = Column(DateTime, nullable=True)
    seen_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class ShoppingWebhookEventModel(Base):
    """Événements Channel3 déjà traités (livraison au moins une fois : dédoublonnage sur l'id)."""

    __tablename__ = "shopping_webhook_events"

    event_id = Column(String(80), primary_key=True)
    event_type = Column(String(40), nullable=False)
    outcome = Column(String(80), nullable=True)
    received_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
