"""
Modèle des objectifs d'épargne utilisateur.
"""

from datetime import datetime, timezone
# pyrefly: ignore [missing-import]
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, CheckConstraint
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import relationship, validates

from ..database import Base


class SavingsGoalModel(Base):
    """Objectifs d'épargne définis par un utilisateur SIKA."""

    __tablename__ = "savings_goals"
    __table_args__ = (
        CheckConstraint("target_amount >= 0", name="chk_savings_goal_target_non_negative"),
        CheckConstraint("current_amount >= 0", name="chk_savings_goal_current_non_negative"),
    )

    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True
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
        default=0.0,
        nullable=False
    )

    deadline = Column(
        DateTime,
        nullable=True
    )

    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    user = relationship(
        "UserModel",
        back_populates="goals"
    )

    @validates("target_amount", "current_amount")
    def validate_amount(self, key, value):
        if value is not None and value < 0:
            raise ValueError(f"Le montant de {key} ne peut pas être négatif ({value}).")
        return value
