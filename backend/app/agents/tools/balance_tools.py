"""
Google ADK Balance Tool pour SIKA.
Exécute la récupération en direct des vrais portefeuilles connectés.
"""

from typing import Dict, Any, List

def get_total_balance(account_number: str = "") -> Dict[str, Any]:
    """Récupère le solde total et le détail de chaque portefeuille connecté de l'utilisateur.

    Args:
        account_number: Numéro de compte facultatif pour filtrer les portefeuilles.

    Returns:
        Dictionnaire contenant le solde total, la devise et la liste des portefeuilles réels.
    """
    from ...routes.wallet_router import CONNECTED_USER_WALLETS

    active_wallets = [w for w in CONNECTED_USER_WALLETS if w.get("is_active", True)]
    total_balance = sum(w.get("balance", 0.0) for w in active_wallets)

    wallet_list: List[Dict[str, Any]] = []
    for w in active_wallets:
        wallet_list.append({
            "provider": w.get("provider", "Wallet"),
            "account_number": w.get("account_number", ""),
            "balance": float(w.get("balance", 0.0)),
            "currency": w.get("currency", "XOF")
        })

    return {
        "success": True,
        "total_balance": float(total_balance),
        "currency": "XOF",
        "wallets_count": len(wallet_list),
        "wallets": wallet_list
    }
