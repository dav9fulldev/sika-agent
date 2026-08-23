"""
Modèle représentant la connexion entre un utilisateur SIKA
et un portefeuille financier partenaire.
"""

from datetime import datetime, timezone
# pyrefly: ignore [missing-import]
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, CheckConstraint
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import relationship

from ..database import Base


class ConnectedWalletModel(Base):
    """Portefeuille partenaire connecté à un utilisateur SIKA."""

    __tablename__ = "connected_wallets"
    __table_args__ = (
        CheckConstraint(
            "connection_status IN ('connected', 'disconnected', 'pending')",
            name="chk_connected_wallet_status_valid"
        ),
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
        default="connected",
        nullable=False
    )

    created_at = Column(
        DateTime,
        default=lambda: datetime.now(timezone.utc),
        nullable=False
    )

    user = relationship(
        "UserModel",
        back_populates="connected_wallets"
    )
