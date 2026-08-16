"""
Financial & Context Tools pour l'Agent SIKA

Analyse des dépenses et restitution du contexte financier global neutre.
"""

from typing import Dict, Any, Optional
from .tool_models import RiskLevel, ToolResult
from .mock_data import MOCK_WALLETS, MOCK_TRANSACTIONS

def get_spending_summary(days: int = 30) -> ToolResult:
    """Analyse et synthétise les dépenses observées."""
    expenses = [t for t in MOCK_TRANSACTIONS if t["type"] in ["transfer", "payment", "withdrawal"]]
    total_spent = sum(t["amount"] for t in expenses)
    
    # Répartition par catégorie
    categories: Dict[str, float] = {}
    for t in expenses:
        cat = t.get("category", "Autre")
        categories[cat] = categories.get(cat, 0.0) + t["amount"]

    return ToolResult(
        success=True,
        tool_name="get_spending_summary",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "days_analyzed": days,
            "total_spent": total_spent,
            "currency": "XOF",
            "transaction_count": len(expenses),
            "category_breakdown": categories
        }
    )

def get_financial_context(user_id: str = "default_user") -> ToolResult:
    """Retourne le contexte financier global neutre pour le raisonnement de l'agent SIKA."""
    total_balance = sum(w["balance"] for w in MOCK_WALLETS)
    recent_txs = MOCK_TRANSACTIONS[:5]
    
    return ToolResult(
        success=True,
        tool_name="get_financial_context",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "total_balance": total_balance,
            "currency": "XOF",
            "wallets": [
                {"provider": w["provider"], "balance": w["balance"], "currency": w["currency"]}
                for w in MOCK_WALLETS
            ],
            "recent_transactions_count": len(recent_txs),
            "recent_transactions": recent_txs,
            "active_goals": [
                {
                    "id": "goal_1",
                    "title": "Épargne de précaution",
                    "target_amount": 50000.0,
                    "current_amount": 15000.0,
                    "currency": "XOF"
                }
            ]
        }
    )
