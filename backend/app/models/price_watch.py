"""
Surveillance de prix d'un produit trouvé sur le web (Channel3).

Deux sources : l'utilisateur (ou l'agent, à sa demande) choisit un prix cible, ou SIKA suit
automatiquement pendant 30 jours les produits qu'il lui a montrés. Channel3 notifie les changements
d'offre par webhook ; SIKA prévient l'utilisateur des changements utiles. Aucun achat n'est fait automatiquement.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index, Text
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
    source = Column(String(8), nullable=False, default="user", server_default="user")  # user | auto
    expires_at = Column(DateTime, nullable=True)  # suivi automatique : fin du suivi
    last_notified_at = Column(DateTime, nullable=True)  # anti-spam : une notification par produit et par jour
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


class UserNotificationModel(Base):
    """Changement signalé à l'utilisateur (affiché dans l'app, et envoyé en push si un appareil est enregistré)."""

    __tablename__ = "user_notifications"
    __table_args__ = (Index("ix_user_notifications_user_created", "user_id", "created_at"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    # target_reached | price_drop | price_rise | back_in_stock | out_of_stock | new_offer | offer_removed
    kind = Column(String(24), nullable=False)
    product_id = Column(String(64), nullable=True)
    title = Column(String(200), nullable=False)
    merchant = Column(String(120), nullable=True)
    price = Column(String(20), nullable=True)
    previous_price = Column(String(20), nullable=True)
    currency = Column(String(3), nullable=True)
    image_url = Column(String(512), nullable=True)
    read_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)


class PushDeviceModel(Base):
    """Jeton Firebase Cloud Messaging d'un téléphone connecté (supprimé à la déconnexion ou s'il expire)."""

    __tablename__ = "push_devices"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token = Column(Text, nullable=False)
    token_hash = Column(String(64), nullable=False, unique=True)
    platform = Column(String(12), nullable=False, default="android")
    language = Column(String(2), nullable=False, default="en")  # langue du texte de la notification
    tz_offset_minutes = Column(Integer, nullable=False, default=0)  # heures calmes (pas de push la nuit)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
