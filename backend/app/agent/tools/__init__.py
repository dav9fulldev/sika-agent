"""
Package des Tools Financiers SIKA
"""

from .tool_models import RiskLevel, ToolResult, ToolDefinition
from .wallet_tools import get_wallets, get_wallet_balance, get_total_balance, search_contact
from .transaction_tools import get_recent_transactions, prepare_transfer, confirm_transfer
from .financial_tools import get_spending_summary, get_financial_context, get_user_habits, update_user_habit, create_backup_snapshot

def register_all_sika_tools(registry):
    """Enregistre l'ensemble des tools financiers SIKA dans le registre donné."""
    # 1. Observation & Wallets (READ_ONLY)
    registry.register(
        func=get_wallets,
        name="get_wallets",
        description="Obtenir la liste des comptes et portefeuilles connus (Wave, Orange Money, MTN).",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=get_wallet_balance,
        name="get_wallet_balance",
        description="Obtenir le solde d'un portefeuille spécifique (wave, orange_money, mtn_money).",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=get_total_balance,
        name="get_total_balance",
        description="Calculer le montant total disponible sur l'ensemble des portefeuilles.",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=search_contact,
        name="search_contact",
        description="Rechercher un destinataire ou contact par nom ou numéro de téléphone.",
        risk_level=RiskLevel.READ_ONLY
    )

    # 2. Transactions & Analyse & Mémoire (READ_ONLY)
    registry.register(
        func=get_recent_transactions,
        name="get_recent_transactions",
        description="Retourner la liste des dernières opérations financières observées.",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=get_spending_summary,
        name="get_spending_summary",
        description="Analyser les dépenses observées et la répartition par catégorie.",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=get_financial_context,
        name="get_financial_context",
        description="Retourner la synthèse du contexte financier global neutre de l'utilisateur.",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=get_user_habits,
        name="get_user_habits",
        description="Récupérer les habitudes d'achat et le profil d'apprentissage du client.",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=update_user_habit,
        name="update_user_habit",
        description="Enregistrer une nouvelle habitude ou ajuster les moyennes de dépenses client.",
        risk_level=RiskLevel.READ_ONLY
    )

    registry.register(
        func=create_backup_snapshot,
        name="create_backup_snapshot",
        description="Créer un snapshot de sauvegarde complète de la mémoire IA pour ré-entraînement.",
        risk_level=RiskLevel.READ_ONLY
    )

    # 3. Actions Sensibles & Exécution (CONFIRMATION_REQUIRED / EXECUTION)
    registry.register(
        func=prepare_transfer,
        name="prepare_transfer",
        description="Préparer un transfert d'argent sans l'exécuter (Nécessite confirmation humaine).",
        risk_level=RiskLevel.CONFIRMATION_REQUIRED
    )

    registry.register(
        func=confirm_transfer,
        name="confirm_transfer",
        description="Simuler l'exécution d'un transfert après validation humaine explicite.",
        risk_level=RiskLevel.EXECUTION
    )

__all__ = [
    "RiskLevel",
    "ToolResult",
    "ToolDefinition",
    "register_all_sika_tools",
    "get_wallets",
    "get_wallet_balance",
    "get_total_balance",
    "search_contact",
    "get_recent_transactions",
    "get_spending_summary",
    "get_financial_context",
    "get_user_habits",
    "update_user_habit",
    "create_backup_snapshot",
    "prepare_transfer",
    "confirm_transfer",
]
