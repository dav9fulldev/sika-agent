"""
Modèle de données SQLAlchemy pour la persistance de la session conversationnelle SIKA.
Permet de restaurer les états conversationnels (AMBIGUITY_ASKED, WAITING_VOICE_CONFIRMATION)
après un redémarrage du backend FastAPI.
"""

from datetime import datetime
from sqlalchemy import Column, String, DateTime, Text
from ..database import Base


class SikaSessionModel(Base):
    """Table de stockage persistant des sessions conversationnelles multi-tours."""

    __tablename__ = "sika_sessions"

    user_id = Column(
        String(50),
        primary_key=True,
        index=True
    )

    state = Column(
        String(50),
        nullable=False,
        default="IDLE"
    )

    active_action_id = Column(
        String(100),
        nullable=True
    )

    session_data_json = Column(
        Text,
        nullable=True
    )

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False
    )
