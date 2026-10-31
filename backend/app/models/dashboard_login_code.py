"""
Code de connexion au tableau de bord web (usage unique, 10 minutes).

L'app (utilisateur déjà connecté) affiche un code ; le navigateur l'échange contre un jeton limité
au tableau de bord en lecture seule. Seule l'empreinte SHA-256 du code est stockée.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from ..database import Base


class DashboardLoginCodeModel(Base):
    __tablename__ = "dashboard_login_codes"

    code_hash = Column(String(64), primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False)
    used_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
