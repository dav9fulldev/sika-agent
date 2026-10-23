"""
Package des Tools Financiers SIKA
"""

from .tool_models import RiskLevel, ToolResult, ToolDefinition
from .financial_tools import get_user_habits, update_user_habit, create_backup_snapshot
from .commerce_tools import (
    search_demo_catalog, prepare_paypal_checkout, get_paypal_checkout_status, list_recent_paypal_checkouts,
    SEARCH_SCHEMA, PREPARE_SCHEMA, STATUS_SCHEMA, LIST_SCHEMA,
)

# Outils de maintenance : appelables par le backend, jamais par le modèle IA.
INTERNAL_ONLY_TOOLS = {"update_user_habit", "create_backup_snapshot"}

def register_all_sika_tools(registry):
    """Enregistre l'ensemble des tools financiers SIKA dans le registre donné."""
    _register = registry.register

    def register(func, name, description, risk_level=RiskLevel.READ_ONLY, **kwargs):
        _register(
            func=func, name=name, description=description, risk_level=risk_level,
            agent_exposed=name not in INTERNAL_ONLY_TOOLS,
            **kwargs,
        )

    # 0. SIKA Pay — Commerce agentique PayPal (sandbox)
    register(
        func=search_demo_catalog,
        name="search_demo_catalog",
        description="Search the SIKA Demo Store catalog (fictional demo products priced in USD). Use it before preparing any purchase. Returns SKUs and server-side prices.",
        risk_level=RiskLevel.READ_ONLY,
        input_schema=SEARCH_SCHEMA,
    )

    register(
        func=prepare_paypal_checkout,
        name="prepare_paypal_checkout",
        description="Prepare a PayPal sandbox checkout for one catalog SKU WITHOUT creating the PayPal order or charging anything. The backend computes the price and checks the user's budget. The user must then confirm in the app.",
        risk_level=RiskLevel.CONFIRMATION_REQUIRED,
        input_schema=PREPARE_SCHEMA,
    )

    register(
        func=get_paypal_checkout_status,
        name="get_paypal_checkout_status",
        description="Re-check with PayPal (read-only) the real status of a checkout: prepared, order created, approved, captured, declined, cancelled.",
        risk_level=RiskLevel.READ_ONLY,
        input_schema=STATUS_SCHEMA,
    )

    register(
        func=list_recent_paypal_checkouts,
        name="list_recent_paypal_checkouts",
        description="List the user's recent SIKA Pay PayPal checkouts with their recorded status.",
        risk_level=RiskLevel.READ_ONLY,
        input_schema=LIST_SCHEMA,
    )

    # 1. Mémoire comportementale (READ_ONLY)
    register(
        func=get_user_habits,
        name="get_user_habits",
        description="Récupérer les habitudes d'achat et le profil d'apprentissage du client.",
        risk_level=RiskLevel.READ_ONLY
    )

    register(
        func=update_user_habit,
        name="update_user_habit",
        description="Enregistrer une nouvelle habitude ou ajuster les moyennes de dépenses client.",
        risk_level=RiskLevel.READ_ONLY
    )

    register(
        func=create_backup_snapshot,
        name="create_backup_snapshot",
        description="Créer un snapshot de sauvegarde complète de la mémoire IA pour ré-entraînement.",
        risk_level=RiskLevel.READ_ONLY
    )


__all__ = [
    "RiskLevel",
    "ToolResult",
    "ToolDefinition",
    "register_all_sika_tools",
    "get_user_habits",
    "update_user_habit",
    "create_backup_snapshot",
    "search_demo_catalog",
    "prepare_paypal_checkout",
    "get_paypal_checkout_status",
    "list_recent_paypal_checkouts",
]
