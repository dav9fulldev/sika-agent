"""
Modèle utilisateur principal de SIKA.
Gère l'identité, l'authentification et les relations
avec les données propres à chaque utilisateur.
"""

from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime
from sqlalchemy.orm import relationship

from ..database import Base


class UserModel(Base):
    """Table centrale des utilisateurs SIKA."""

    __tablename__ = "users"

    id = Column(
        Integer,
        primary_key=True,
        autoincrement=True,
        index=True
    )

    email = Column(
        String(100),
        unique=True,
        index=True,
        nullable=False
    )

    password_hash = Column(
        String(255),
        nullable=True
    )

    full_name = Column(
        String(100),
        nullable=False,
        default="David YAO"
    )

    google_id = Column(
        String(100),
        nullable=True
    )

    auth_provider = Column(
        String(20),
        nullable=False,
        default="email"
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )

    # Relations

    connected_wallets = relationship(
        "ConnectedWalletModel",
        back_populates="user",
        cascade="all, delete-orphan"
    )

    preferences = relationship(
        "UserPreferenceModel",
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan"
    )

    goals = relationship(
        "SavingsGoalModel",
        back_populates="user",
        cascade="all, delete-orphan"
    )

    memories = relationship(
        "AgentMemoryModel",
        back_populates="user",
        cascade="all, delete-orphan"
    )
