"""
Modèle de données SQLAlchemy pour la persistance des actions financières SIKA.
Garantit l'idempotence, la traçabilité et l'isolation utilisateur des actions.
"""

from datetime import datetime
from sqlalchemy import Column, Integer, String, DateTime, Text
from ..database import Base


class SikaActionModel(Base):
    """Table de stockage persistant des actions financières de l'agent SIKA."""

    __tablename__ = "sika_actions"

    action_id = Column(
        String(100),
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        nullable=False,
        index=True
    )

    action_type = Column(
        String(50),
        nullable=False,
        default="TRANSFER"
    )

    status = Column(
        String(50),
        nullable=False,
        default="WAITING_CONFIRMATION"  # WAITING_CONFIRMATION, EXECUTING, EXECUTED, CANCELLED, EXPIRED, FAILED, UNKNOWN_RESULT
    )

    payload_json = Column(
        Text,
        nullable=True
    )

    result_json = Column(
        Text,
        nullable=True
    )

    cancelled_reason = Column(
        String(255),
        nullable=True
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow,
        nullable=False
    )

    expires_at = Column(
        DateTime,
        nullable=False
    )

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )
