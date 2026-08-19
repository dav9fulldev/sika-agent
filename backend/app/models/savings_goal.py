"""
Modèle des objectifs d'épargne utilisateur.
"""

from datetime import datetime

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from ..database import Base


class SavingsGoalModel(Base):
    """Objectifs d'épargne définis par un utilisateur SIKA."""

    __tablename__ = "savings_goals"

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

    title = Column(
        String(100),
        nullable=False
    )

    target_amount = Column(
        Float,
        nullable=False
    )

    current_amount = Column(
        Float,
        default=0.0
    )

    deadline = Column(
        DateTime,
        nullable=True
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    user = relationship(
        "UserModel",
        back_populates="goals"
    )
