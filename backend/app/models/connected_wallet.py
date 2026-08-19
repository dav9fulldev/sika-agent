"""
Modèle représentant la connexion entre un utilisateur SIKA
et un portefeuille financier partenaire.
"""

from datetime import datetime

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from ..database import Base


class ConnectedWalletModel(Base):
    """Portefeuille partenaire connecté à un utilisateur SIKA."""

    __tablename__ = "connected_wallets"

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

    provider = Column(
        String(50),
        nullable=False
    )

    external_wallet_id = Column(
        String(100),
        nullable=True
    )

    connection_status = Column(
        String(20),
        default="connected"
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    user = relationship(
        "UserModel",
        back_populates="connected_wallets"
    )
