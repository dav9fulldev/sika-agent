"""
Modèle des préférences utilisateur pour SIKA.
"""

from datetime import datetime, timezone
# pyrefly: ignore [missing-import]
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import relationship

from ..database import Base


class UserPreferenceModel(Base):
    """Préférences et règles budgétaires de l'utilisateur."""

    __tablename__ = "user_preferences"

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
        unique=True,
        index=True
    )

    preferred_currency = Column(
        String(10),
        default="XOF"
    )

    preferred_language = Column(
        String(10),
        default="fr"
    )

    monthly_budget = Column(
        Float,
        nullable=True,
        default=150000.0
    )

    savings_preference = Column(
        String(50),
        default="moderate"
    )

    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    user = relationship(
        "UserModel",
        back_populates="preferences"
    )
