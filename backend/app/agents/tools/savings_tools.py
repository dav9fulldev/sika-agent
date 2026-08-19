"""
Google ADK Savings Tool pour SIKA.
Récupère les informations réelles du coffre d'épargne via PayMeChap API.
"""

from typing import Dict, Any

def get_savings_status(account_number: str = "") -> Dict[str, Any]:
    """Récupère l'état réel et l'avancement des coffres d'épargne réels.

    Args:
        account_number: Numéro de compte facultatif.

    Returns:
        Dictionnaire avec les données réelles du coffre (solde, objectif, pourcentage d'avancement).
    """
    from ...services.wallet_integrations.paymechap_api_service import paymechap_api_service
    from ...routes.wallet_router import CONNECTED_USER_WALLETS

    if not account_number:
        active_paymechap = [w for w in CONNECTED_USER_WALLETS if "paymechap" in w.get("provider", "").lower()]
        if active_paymechap:
            account_number = active_paymechap[0].get("account_number", "")

    coffres = paymechap_api_service.fetch_user_coffres("", account_number=account_number)

    if not coffres:
        return {
            "success": True,
            "coffre_name": "Épargne",
            "current_amount": 0.0,
            "target_amount": 0.0,
            "progress_percentage": 0.0,
            "currency": "XOF",
            "message": "Aucun coffre actif trouvé."
        }

    c_item = coffres[0]
    c_nom = c_item.get("nom") or "Épargne"
    c_solde = float(c_item.get("solde") or 0.0)
    c_obj = float(c_item.get("objectif") or 0.0)
    pct = (c_solde / c_obj * 100) if c_obj > 0 else 0.0

    return {
        "success": True,
        "coffre_name": c_nom,
        "current_amount": c_solde,
        "target_amount": c_obj,
        "progress_percentage": round(pct, 1),
        "currency": "XOF",
        "coffres_count": len(coffres)
    }
