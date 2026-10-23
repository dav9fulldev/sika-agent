"""
Context Tools pour l'Agent SIKA

Mémoire comportementale de l'utilisateur (habitudes) et snapshot de sauvegarde.
"""

import logging
from .tool_models import RiskLevel, ToolResult
from ...services.user_learning_service import user_learning_service

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
    from ...services.backup_service import backup_service
    snapshot = backup_service.create_backup_snapshot(user_id)
    return ToolResult(
        success=True,
        tool_name="create_backup_snapshot",
        risk_level=RiskLevel.READ_ONLY,
        data=snapshot
    )
