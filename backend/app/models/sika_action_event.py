"""
Modèle de données SQLAlchemy pour la traçabilité et l'historique d'audit des actions financières SIKA.
Permet d'enregistrer de manière immuable (append-only) chaque changement d'état d'une action.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, Text, Integer
from ..database import Base


class SikaActionEventModel(Base):
    """Table de stockage immuable de l'historique d'audit des événements d'actions financières."""

    __tablename__ = "sika_action_events"

    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True
    )

    action_id = Column(
        String(100),
        index=True,
        nullable=False
    )

    user_id = Column(
        Integer,
        index=True,
        nullable=False
    )

    previous_status = Column(
        String(50),
        nullable=True
    )

    new_status = Column(
        String(50),
        nullable=False
    )

    event_type = Column(
        String(50),
        nullable=False,
        default="STATE_CHANGE"
    )

    reason = Column(
        Text,
        nullable=True
    )

    metadata_json = Column(
        Text,
        nullable=True
    )

    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )
