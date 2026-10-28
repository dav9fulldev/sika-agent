"""
Compte PayPal enregistré (PayPal Vault) : l'utilisateur l'approuve une fois sur PayPal.

Il ne sert qu'aux achats que SIKA confirme sous une autorisation active : la commande est alors payée avec ce
compte, sans nouvelle redirection vers PayPal. Sans compte relié, chaque paiement reste approuvé sur PayPal.
SIKA ne conserve que l'identifiant du jeton PayPal (jamais d'identifiant de connexion ni de moyen de paiement).
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Index
from ..database import Base

# PENDING_APPROVAL : en attente de l'approbation PayPal ; ACTIVE : utilisable ; REVOKED : délié ; FAILED : échec
VAULT_STATUSES = ("PENDING_APPROVAL", "ACTIVE", "REVOKED", "FAILED")


class PayPalVaultModel(Base):
    __tablename__ = "paypal_vault_tokens"
    __table_args__ = (Index("ix_paypal_vault_user_status", "user_id", "status"),)

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(String(20), nullable=False, default="PENDING_APPROVAL")
    setup_token_id = Column(String(64), nullable=False, unique=True, index=True)
    payment_token_id = Column(String(64), nullable=True, unique=True)
    customer_id = Column(String(64), nullable=True)
    payer_email_masked = Column(String(127), nullable=True)
    request_id = Column(String(64), nullable=False)
    last_error_code = Column(String(80), nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
