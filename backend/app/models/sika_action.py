"""
Modèle de données SQLAlchemy pour la persistance des actions financières SIKA.
Garantit l'idempotence, la traçabilité et l'isolation utilisateur des actions.
"""

from datetime import datetime, timezone
# pyrefly: ignore [missing-import]
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, CheckConstraint, Index
from ..database import Base


class SikaActionModel(Base):
    """Table de stockage persistant des actions financières de l'agent SIKA."""

    __tablename__ = "sika_actions"
    __table_args__ = (
        CheckConstraint(
            "status IN ('WAITING_CONFIRMATION', 'EXECUTING', 'EXECUTED', 'CANCELLED', 'EXPIRED', 'FAILED', 'UNKNOWN_RESULT')",
            name="chk_sika_action_status_valid"
        ),
        Index("ix_sika_actions_user_status", "user_id", "status"),
        Index("ix_sika_actions_user_created", "user_id", "created_at"),
    )

    action_id = Column(
        String(100),
        primary_key=True,
        index=True
    )

    idempotency_key = Column(
        String(100),
        nullable=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
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
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    expires_at = Column(
        DateTime,
        nullable=False
    )

    updated_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        nullable=False
    )
