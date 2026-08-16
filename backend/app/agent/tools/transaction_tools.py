"""
Transaction Tools pour l'Agent SIKA

Consultation des transactions, préparation d'action (Human-in-the-loop) et simulation d'exécution.
"""

from typing import Dict, Any, Optional
import uuid
from .tool_models import RiskLevel, ToolResult
from .mock_data import MOCK_TRANSACTIONS

def get_recent_transactions(limit: int = 5, provider: Optional[str] = None) -> ToolResult:
    """Retourne les dernières opérations financières observées."""
    txs = MOCK_TRANSACTIONS
    if provider:
        clean_p = provider.lower().strip()
        txs = [t for t in txs if t["provider"] == clean_p]

    limited_txs = txs[:limit]
    return ToolResult(
        success=True,
        tool_name="get_recent_transactions",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "count": len(limited_txs),
            "transactions": limited_txs
        }
    )

def prepare_transfer(provider: str, amount: float, recipient: str, currency: str = "XOF") -> ToolResult:
    """
    Prépares une transaction SANS l'exécuter.
    Passe en état CONFIRMATION_REQUIRED pour validation humaine.
    """
    if amount <= 0:
        return ToolResult(
            success=False,
            tool_name="prepare_transfer",
            risk_level=RiskLevel.CONFIRMATION_REQUIRED,
            data={},
            error_message="Le montant du transfert doit être supérieur à 0."
        )

    action_id = f"act_{uuid.uuid4().hex[:8]}"
    return ToolResult(
        success=True,
        tool_name="prepare_transfer",
        risk_level=RiskLevel.CONFIRMATION_REQUIRED,
        requires_confirmation=True,
        data={
            "action_id": action_id,
            "status": "confirmation_required",
            "provider": provider.lower(),
            "amount": amount,
            "currency": currency,
            "recipient": recipient,
            "summary": f"Préparation transfert de {amount} {currency} vers {recipient} via {provider.capitalize()}"
        }
    )

def confirm_transfer(action_id: str, confirmation_token: str, user_confirmed: bool = True) -> ToolResult:
    """
    Représente l'étape d'exécution après confirmation explicite de l'utilisateur.
    Pour cette version, il s'agit d'une SIMULATION SÉCURISÉE (MOCK).
    """
    if not user_confirmed:
        return ToolResult(
            success=False,
            tool_name="confirm_transfer",
            risk_level=RiskLevel.EXECUTION,
            data={"action_id": action_id, "status": "cancelled"},
            error_message="L'utilisateur n'a pas confirmé l'action."
        )

    return ToolResult(
        success=True,
        tool_name="confirm_transfer",
        risk_level=RiskLevel.EXECUTION,
        data={
            "action_id": action_id,
            "status": "simulated_success",
            "message": "Transfert simulé avec succès !",
            "simulation": True,
            "timestamp": "2026-08-16T16:38:00Z"
        }
    )
