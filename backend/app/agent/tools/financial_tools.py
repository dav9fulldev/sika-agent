"""
Financial & Context Tools pour l'Agent SIKA

Analyse des dépenses, restitution du contexte financier et gestion de la mémoire comportementale.
"""

from typing import Dict, Any, Optional
from .tool_models import RiskLevel, ToolResult
from .mock_data import MOCK_WALLETS, MOCK_TRANSACTIONS
from ...services.user_learning_service import user_learning_service
from ...services.backup_service import backup_service

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
    user_profile = user_learning_service.get_user_profile(user_id)

    return ToolResult(
        success=True,
        tool_name="get_financial_context",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "user_profile": user_profile,
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
                    "target_amount": 80000.0,
                    "current_amount": 48000.0,
                    "currency": "XOF"
                }
            ]
        }
    )

def get_user_habits(user_id: str = "default_user") -> ToolResult:
    """Récupère les habitudes d'achat et le profil d'apprentissage de l'utilisateur."""
    profile = user_learning_service.get_user_profile(user_id)
    return ToolResult(
        success=True,
        tool_name="get_user_habits",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "user_id": user_id,
            "habits": profile.get("habits", {}),
            "insights": profile.get("interaction_insights", []),
            "savings_behavior": profile.get("savings_behavior", {})
        }
    )

def update_user_habit(category: str, amount: float, user_id: str = "default_user") -> ToolResult:
    """Met à jour les habitudes d'achat apprises d'une catégorie."""
    updated = user_learning_service.update_user_habit(user_id, category, amount)
    return ToolResult(
        success=True,
        tool_name="update_user_habit",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "message": f"Habitude mise à jour pour la catégorie {category}",
            "updated_habit": updated
        }
    )

def create_backup_snapshot(user_id: str = "default_user") -> ToolResult:
    """Génère un snapshot de sauvegarde de la mémoire long-terme pour le fine-tuning IA."""
    snapshot = backup_service.create_backup_snapshot(user_id)
    return ToolResult(
        success=True,
        tool_name="create_backup_snapshot",
        risk_level=RiskLevel.READ_ONLY,
        data=snapshot
    )
