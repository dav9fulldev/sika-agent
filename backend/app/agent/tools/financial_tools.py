"""
Financial & Context Tools pour l'Agent SIKA

Analyse des dépenses, restitution du contexte financier et gestion de la mémoire comportementale.
"""

from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import logging
from .tool_models import RiskLevel, ToolResult
# Removed mock import; no mock transactions at runtime
from ...repositories.financial_repository import financial_repository
from ...services.wallet_integrations.paymechap_api_service import paymechap_api_service
from ...services.wallet_integrations.wave_api_service import wave_api_service
from ...services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ...services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ...config import settings
from .transaction_tools import get_recent_transactions as get_recent_tx_tool
from ...services.user_learning_service import user_learning_service

def get_spending_summary(days: int = 30) -> ToolResult:
    """Analyse et synthétise les dépenses observées."""
    # Fetch real transactions from connected wallets and filter by recent days
    expenses = []
    try:
        wallets = financial_repository.get_wallets()
    except Exception:
        wallets = []
    for w in wallets:
        prov = (w.get("provider") or "").lower()
        if "paymechap" in prov:
            fetched = paymechap_api_service.fetch_live_transactions("", limit=200)
        elif "wave" in prov:
            fetched = wave_api_service.fetch_live_transactions("", limit=200)
        elif "orange" in prov:
            fetched = orange_money_api_service.fetch_live_transactions("", limit=200)
        elif "mtn" in prov:
            fetched = mtn_momo_api_service.fetch_live_transactions("", limit=200)
        else:
            fetched = []
        # Filter transactions within the period
        cutoff = datetime.utcnow() - timedelta(days=days)
        for tx in fetched:
            tx_date_str = tx.get("timestamp") or tx.get("date") or tx.get("dateTransaction")
            try:
                tx_dt = datetime.fromisoformat(tx_date_str.rstrip('Z'))
            except Exception:
                continue
            if tx_dt >= cutoff:
                expenses.append(tx)

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
    """Retourne le contexte financier global neutre pour le raisonnement de l'agent SIKA.
    Cette fonction ne renvoie que les transactions réelles provenant de providers vérifiés.
    Les informations de statut/provider sont séparées dans le champ `provider_status`.
    """
    # ------------------------------------------------------------------
    # 1️⃣  Récupération des wallets depuis le repo
    # ------------------------------------------------------------------
    try:
        repo_wallets = financial_repository.get_wallets(user_id)
    except Exception as exc:
        logging.warning(f"[FinancialTools] Erreur lors du fetch des wallets : {exc}")
        repo_wallets = []

    recent_txs: List[Dict[str, Any]] = []
    provider_status: List[Dict[str, Any]] = []
    wallets_summary: List[Dict[str, Any]] = []
    total_balance = 0.0

    # ------------------------------------------------------------------
    # 2️⃣  Parcourir chaque wallet connecté
    # ------------------------------------------------------------------
    for w in repo_wallets:
        prov = (w.get("provider") or "").lower()
        conn_status = (w.get("status") or w.get("connection_status") or "").lower()
        # Seules les connexions actives sont prises en compte
        if conn_status != "connected":
            continue

        internal_id = w.get("id")
        external_id = w.get("external_wallet_id")

        if prov == "paymechap":
            # ----------------------------------------------------------
            # PayMeChap – provider VERIFIED
            # ----------------------------------------------------------
            token = paymechap_api_service.get_partner_access_token()
            if not token:
                provider_status.append({"provider": w.get("provider"), "status": "AUTH_ERROR", "reason": "token_unavailable"})
                continue
            try:
                fetched = paymechap_api_service.fetch_live_transactions(token, account_number=external_id, limit=200)
                provider_status.append({"provider": w.get("provider"), "status": "VERIFIED"})
            except Exception as exc:
                logging.warning(f"[FinancialTools] PayMeChap API error : {exc}")
                provider_status.append({"provider": w.get("provider"), "status": "API_ERROR", "reason": str(exc)})
                fetched = []

            # ---- Balance ----
            try:
                bal_resp = paymechap_api_service.fetch_live_balance(token, account_number=external_id)
                bal = float(bal_resp.get("balance", 0.0))
            except Exception:
                bal = 0.0
            wallets_summary.append({"provider": w.get("provider"), "balance": bal, "currency": "XOF"})
            total_balance += bal

            # ---- Transactions ----
            cutoff = datetime.utcnow() - timedelta(days=30)
            for tx in fetched:
                # enrich transaction avec identité du wallet
                tx["provider"] = w.get("provider")
                tx["internal_wallet_id"] = internal_id
                tx["external_wallet_id"] = external_id
                # wallet_id : alias de commodité (external prioritaire, fallback internal)
                tx["wallet_id"] = external_id if external_id else internal_id
                tx_date_str = tx.get("timestamp") or tx.get("date") or tx.get("dateTransaction")
                if not tx_date_str:
                    continue
                try:
                    tx_dt = datetime.fromisoformat(tx_date_str.rstrip('Z'))
                except Exception:
                    continue
                if tx_dt >= cutoff:
                    recent_txs.append(tx)
        else:
            # ----------------------------------------------------------
            # Providers non vérifiés – on ne les appelle pas
            # ----------------------------------------------------------
            provider_status.append({"provider": w.get("provider"), "status": "NOT_VERIFIED", "reason": "credential_source_unavailable"})
            # Balance n'est pas récupéré (placeholder = 0)
            wallets_summary.append({"provider": w.get("provider"), "balance": 0.0, "currency": "XOF"})

    # ------------------------------------------------------------------
    # 3️⃣  Cas où aucun wallet n'est présent – déjà géré via listes vides
    # ------------------------------------------------------------------
    if not repo_wallets:
        # aucune donnée supplémentaire à ajouter
        pass

    # ------------------------------------------------------------------
    # 4️⃣  Ajout du profil utilisateur et du résultat final
    # ------------------------------------------------------------------
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
            "wallets": wallets_summary,
            "recent_transactions_count": len(recent_txs),
            "recent_transactions": recent_txs,
            "active_goals": [
                {
                    "id": "goal_1",
                    "title": "Épargne de précaution",
                    "target_amount": 80000.0,
                    "current_amount": 48000.0,
                    "currency": "XOF",
                }
            ],
            "provider_status": provider_status,
        },
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
    from ...services.backup_service import backup_service
    snapshot = backup_service.create_backup_snapshot(user_id)
    return ToolResult(
        success=True,
        tool_name="create_backup_snapshot",
        risk_level=RiskLevel.READ_ONLY,
        data=snapshot
    )
