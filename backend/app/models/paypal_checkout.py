"""
Modèle SQLAlchemy des checkouts PayPal préparés par l'agent SIKA.

Cycle de vie (états distincts, jamais fusionnés) :
  AWAITING_USER_CONFIRMATION -> CREATING_ORDER -> AWAITING_PAYPAL_APPROVAL -> APPROVED
  -> CAPTURING -> COMPLETED | PENDING | DECLINED | FAILED
  avec les sorties CANCELLED, EXPIRED, FAILED et UNKNOWN_RESULT (vérification requise).

Une commande créée, une commande approuvée et une commande capturée sont trois états différents.
"""

from datetime import datetime, timezone
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey, CheckConstraint, Index
from ..database import Base

CHECKOUT_STATUSES = (
    "AWAITING_USER_CONFIRMATION",
    "CREATING_ORDER",
    "AWAITING_PAYPAL_APPROVAL",
    "APPROVED",
    "CAPTURING",
    "COMPLETED",
    "PENDING",
    "DECLINED",
    "CANCELLED",
    "EXPIRED",
    "FAILED",
    "UNKNOWN_RESULT",
)

TERMINAL_STATUSES = ("COMPLETED", "DECLINED", "CANCELLED", "EXPIRED", "FAILED")


class PayPalCheckoutModel(Base):
    """Table persistante des checkouts PayPal sandbox (une ligne = une intention d'achat)."""

    __tablename__ = "paypal_checkouts"
    __table_args__ = (
        CheckConstraint(
            "status IN (" + ", ".join(f"'{s}'" for s in CHECKOUT_STATUSES) + ")",
            name="chk_paypal_checkout_status_valid",
        ),
        Index("ix_paypal_checkouts_user_status", "user_id", "status"),
        Index("ix_paypal_checkouts_user_created", "user_id", "created_at"),
    )

    checkout_id = Column(String(64), primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(String(40), nullable=False, default="AWAITING_USER_CONFIRMATION")

    # Détails vérifiés côté serveur (le prix provient du catalogue, jamais du modèle IA)
    sku = Column(String(64), nullable=False)
    item_name = Column(String(127), nullable=False)
    item_description = Column(String(255), nullable=True)
    quantity = Column(Integer, nullable=False, default=1)
    unit_amount = Column(String(20), nullable=False)
    total_amount = Column(String(20), nullable=False)
    currency = Column(String(3), nullable=False)
    merchant_name = Column(String(127), nullable=False)

    # Contraintes fournies par l'utilisateur
    budget_limit = Column(String(20), nullable=True)
    budget_currency = Column(String(3), nullable=True)
    user_request = Column(Text, nullable=True)

    # Empreinte des détails confirmés : toute modification invalide la confirmation
    details_hash = Column(String(64), nullable=False)

    # Identifiants d'idempotence envoyés dans l'en-tête PayPal-Request-Id
    create_request_id = Column(String(64), nullable=False)
    capture_request_id = Column(String(64), nullable=False)

    # Qui a confirmé l'achat : USER (dans l'app) ou AGENT (autorisation accordée par l'utilisateur)
    confirmed_by = Column(String(10), nullable=True)

    # Données renvoyées par PayPal
    paypal_order_id = Column(String(64), nullable=True, unique=True, index=True)
    paypal_order_status = Column(String(40), nullable=True)
    approve_url = Column(String(512), nullable=True)
    capture_id = Column(String(64), nullable=True)
    capture_status = Column(String(40), nullable=True)
    captured_amount = Column(String(20), nullable=True)
    captured_currency = Column(String(3), nullable=True)
    paypal_debug_id = Column(String(64), nullable=True)

    last_error_code = Column(String(80), nullable=True)
    last_error_message = Column(String(255), nullable=True)

    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc), nullable=False)
    updated_at = Column(DateTime, default=lambda: datetime.now(timezone.utc),
                        onupdate=lambda: datetime.now(timezone.utc), nullable=False)
    result_json = Column(Text, nullable=True)
