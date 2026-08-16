"""
Wallet Tools pour l'Agent SIKA

Consultation des portefeuilles (Wave, Orange Money, MTN), soldes et contacts.
"""

from typing import Dict, Any, List
from .tool_models import RiskLevel, ToolResult
from .mock_data import MOCK_WALLETS, MOCK_CONTACTS

def get_wallets(user_id: str = "default_user") -> ToolResult:
    """Retourne la liste des wallets connus de l'utilisateur."""
    return ToolResult(
        success=True,
        tool_name="get_wallets",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "wallets": MOCK_WALLETS
        }
    )

def get_wallet_balance(provider: str) -> ToolResult:
    """Retourne le solde d'un wallet spécifique (wave, orange_money, mtn_money)."""
    clean_provider = provider.lower().strip()
    wallet = next((w for w in MOCK_WALLETS if w["provider"] == clean_provider), None)
    
    if not wallet:
        return ToolResult(
            success=False,
            tool_name="get_wallet_balance",
            risk_level=RiskLevel.READ_ONLY,
            data={},
            error_message=f"Wallet '{provider}' non trouvé. Portefeuilles connus: wave, orange_money, mtn_money."
        )

    return ToolResult(
        success=True,
        tool_name="get_wallet_balance",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "provider": wallet["provider"],
            "name": wallet["name"],
            "balance": wallet["balance"],
            "currency": wallet["currency"]
        }
    )

def get_total_balance(user_id: str = "default_user") -> ToolResult:
    """Calcule le montant total disponible sur tous les wallets."""
    total = sum(w["balance"] for w in MOCK_WALLETS)
    return ToolResult(
        success=True,
        tool_name="get_total_balance",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "total_balance": total,
            "currency": "XOF",
            "wallet_count": len(MOCK_WALLETS)
        }
    )

def search_contact(query: str) -> ToolResult:
    """Recherche un destinataire parmi les contacts connus."""
    clean_query = query.lower().strip()
    results = [
        c for c in MOCK_CONTACTS 
        if clean_query in c["name"].lower() or clean_query in c["phone"]
    ]
    return ToolResult(
        success=True,
        tool_name="search_contact",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "query": query,
            "contacts": results,
            "count": len(results)
        }
    )
