"""
Autorisation donnée par l'utilisateur à l'agent SIKA (mode hybride).

Sans autorisation active, seul l'utilisateur confirme un achat dans l'app.
Avec une autorisation active, l'agent peut confirmer à sa place un achat préparé, dans les limites
choisies par l'utilisateur (montant par achat, total par jour, durée). Le serveur applique ces limites ;
l'approbation PayPal du payeur reste toujours nécessaire.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from ..database import Base


class AgentMandateModel(Base):
    __tablename__ = "agent_mandates"
    __table_args__ = (Index("ix_agent_mandates_user_created", "user_id", "created_at"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    max_per_purchase = Column(String(20), nullable=False)
    daily_limit = Column(String(20), nullable=False)
    currency = Column(String(3), nullable=False, default="USD")
    expires_at = Column(DateTime, nullable=False)
    revoked_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
