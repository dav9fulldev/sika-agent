"""
Modèle de mémoire persistante de l'agent SIKA.
Permet de conserver les habitudes, préférences et insights
propres à chaque utilisateur.
"""

from datetime import datetime

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship

from ..database import Base


class AgentMemoryModel(Base):
    """Mémoire progressive et intelligence contextuelle de SIKA."""

    __tablename__ = "agent_memories"

    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False
    )

    memory_type = Column(
        String(50),
        nullable=False,
        default="long_term"
    )

    key = Column(
        String(100),
        nullable=False
    )

    value = Column(
        Text,
        nullable=False
    )

    confidence_score = Column(
        Float,
        default=1.0
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    user = relationship(
        "UserModel",
        back_populates="memories"
    )
