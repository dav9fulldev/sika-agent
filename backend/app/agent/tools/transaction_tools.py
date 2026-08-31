"""
Transaction Tools pour l'Agent SIKA

Consultation des transactions, préparation d'action (Human-in-the-loop) et simulation d'exécution.
"""

from typing import Dict, Any, Optional
import uuid
from .tool_models import RiskLevel, ToolResult
from ...repositories.financial_repository import financial_repository
from ...services.wallet_integrations.paymechap_api_service import paymechap_api_service
from ...services.wallet_integrations.wave_api_service import wave_api_service
from ...services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ...services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service

def get_recent_transactions(limit: int = 5, provider: Optional[str] = None) -> ToolResult:
    """Retourne les dernières opérations financières observées."""
    # Fetch real transactions from connected wallets
    txs = []
    try:
        wallets = financial_repository.get_wallets()
    except Exception:
        wallets = []
    for w in wallets:
        prov = (w.get("provider") or "").lower()
        if "paymechap" in prov:
            fetched = paymechap_api_service.fetch_live_transactions("", limit=100)
            txs.extend(fetched)
        elif "wave" in prov:
            fetched = wave_api_service.fetch_live_transactions("", limit=100)
            txs.extend(fetched)
        elif "orange" in prov:
            fetched = orange_money_api_service.fetch_live_transactions("", limit=100)
            txs.extend(fetched)
        elif "mtn" in prov:
            fetched = mtn_momo_api_service.fetch_live_transactions("", limit=100)
            txs.extend(fetched)
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

def prepare_transfer(provider: str, amount: float, recipient: str, currency: str) -> ToolResult:
    """
    Prépares une transaction SANS l'exécuter.
    Passe en état CONFIRMATION_REQUIRED pour validation humaine.
    """
    import math
    if not isinstance(amount, (int, float)) or math.isnan(amount) or math.isinf(amount) or amount <= 0:
        return ToolResult(
            success=False,
            tool_name="prepare_transfer",
            risk_level=RiskLevel.CONFIRMATION_REQUIRED,
            data={},
            error_message="Le montant du transfert doit être supérieur à 0."
        )

    if amount > 50_000_000:
        return ToolResult(
            success=False,
            tool_name="prepare_transfer",
            risk_level=RiskLevel.CONFIRMATION_REQUIRED,
            data={},
            error_message="Le montant du transfert dépasse le plafond maximal autorisé de 50 000 000 FCFA."
        )

    if not recipient or not str(recipient).strip():
        return ToolResult(
            success=False,
            tool_name="prepare_transfer",
            risk_level=RiskLevel.CONFIRMATION_REQUIRED,
            data={},
            error_message="Le destinataire du transfert est obligatoire."
        )

    # Provider MUST be explicit and come from the enrolled wallet. Do not
    # silently default to 'wave' here — require the caller to provide provider.
    if not provider or not str(provider).strip():
        return ToolResult(
            success=False,
            tool_name="prepare_transfer",
            risk_level=RiskLevel.CONFIRMATION_REQUIRED,
            data={},
            error_message="Le provider source du transfert est obligatoire et doit provenir d'un portefeuille enrôlé."
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
            "amount": float(amount),
            "currency": currency,
            "recipient": str(recipient).strip(),
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
