"""
Entrées du store de sécurité en base (alternative à Redis) : jetons révoqués, échecs de connexion,
compteurs de rate limit et OTP. Les clés sont des empreintes SHA-256 : aucun jeton ni e-mail en clair.
"""

from sqlalchemy import Column, DateTime, Integer, String

from ..database import Base


class SecurityEntryModel(Base):
    __tablename__ = "security_entries"

    key = Column(String(80), primary_key=True)  # « type:sha256 »
    value = Column(String(128), nullable=True)  # empreinte de l'OTP
    count = Column(Integer, nullable=False, default=0)
    expires_at = Column(DateTime, nullable=False, index=True)
