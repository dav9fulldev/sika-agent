# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any, List, Optional
from datetime import datetime
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service

router = APIRouter(prefix="/api/v1/wallets", tags=["wallets"])

# Portefeuilles utilisateurs connectés via Méthode 1 (APIs OAuth2) et Méthode 3 (Perception SMS/Push)
CONNECTED_USER_WALLETS: List[Dict[str, Any]] = [
    {
        "id": "w_wave_1",
        "user_id": "usr_default",
        "provider": "Wave",
        "balance": 15000.0,
        "currency": "XOF",
        "account_number": "+225 07 00 00 01",
        "auth_method": "OAUTH2_WAVE",
        "is_active": True,
        "last_synced_at": datetime.utcnow().isoformat()
    },
    {
        "id": "w_orange_2",
        "user_id": "usr_default",
        "provider": "Orange Money",
        "balance": 22000.0,
        "currency": "XOF",
        "account_number": "+225 07 00 00 02",
        "auth_method": "ORANGE_DEVELOPER_API",
        "is_active": True,
        "last_synced_at": datetime.utcnow().isoformat()
    },
    {
        "id": "w_mtn_3",
        "user_id": "usr_default",
        "provider": "MTN MoMo",
        "balance": 8000.0,
        "currency": "XOF",
        "account_number": "+225 05 00 00 03",
        "auth_method": "MTN_MOMO_API",
        "is_active": True,
        "last_synced_at": datetime.utcnow().isoformat()
    }
]

@router.get("/me")
def get_my_wallets(user_id: str = "usr_default"):
    """Retourne la liste complète des portefeuilles connectés de l'utilisateur."""
    user_wallets = [w for w in CONNECTED_USER_WALLETS if w["user_id"] == user_id and w["is_active"]]
    total_balance = sum(w["balance"] for w in user_wallets)
    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "count": len(user_wallets),
        "total_balance_xof": total_balance,
        "wallets": user_wallets
    }

@router.get("/transactions/history")
def get_all_wallets_transaction_history(
    user_id: str = "usr_default",
    limit: int = Query(default=30, ge=1, le=100)
):
    """API de collecte d'historique et des mouvements de comptes (Méthodes 1 & 3).

    Exécute une collecte centralisée de l'historique depuis les APIs de Wave, Orange et MTN.
    """
    wave_txs = wave_api_service.fetch_live_transactions("token", limit=limit)
    orange_txs = orange_money_api_service.fetch_live_transactions("token", limit=limit)
    mtn_txs = mtn_momo_api_service.fetch_live_transactions("token", limit=limit)

    movements = wave_txs + orange_txs + mtn_txs
    movements.sort(key=lambda x: x["timestamp"], reverse=True)
    movements = movements[:limit]

    total_spent = sum(t["amount"] for t in movements if t["type"] in ["payment", "transfer", "withdrawal"])
    total_received = sum(t["amount"] for t in movements if t["type"] == "deposit")

    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "movement_count": len(movements),
        "total_spent_xof": total_spent,
        "total_received_xof": total_received,
        "movements": movements
    }

@router.get("/{wallet_id}/transactions")
def get_specific_wallet_transactions(
    wallet_id: str,
    limit: int = Query(default=20, ge=1, le=50)
):
    """Collecte l'historique spécifique des mouvements d'un portefeuille connecté."""
    wallet = next((w for w in CONNECTED_USER_WALLETS if w["id"] == wallet_id), None)
    if not wallet:
        raise HTTPException(status_code=404, detail="Portefeuille non trouvé.")

    provider = wallet["provider"].lower()
    if "wave" in provider:
        txs = wave_api_service.fetch_live_transactions("token", limit=limit)
    elif "orange" in provider:
        txs = orange_money_api_service.fetch_live_transactions("token", limit=limit)
    elif "mtn" in provider:
        txs = mtn_momo_api_service.fetch_live_transactions("token", limit=limit)
    else:
        txs = wave_api_service.fetch_live_transactions("token", limit=limit)

    return {
        "status": "SUCCESS",
        "wallet_id": wallet_id,
        "provider": wallet["provider"],
        "count": len(txs),
        "transactions": txs
    }

@router.post("/connect")
def connect_new_wallet(data: Dict[str, Any]):
    """Connexion d'un nouveau portefeuille via l'API officielle (Méthode 1) ou la Perception (Méthode 3)."""
    provider = data.get("provider", "Wave")
    account_number = data.get("account_number", "+225 07 00 00 99")
    auth_method = data.get("auth_method", "OAUTH2_WAVE")
    user_id = data.get("user_id", "usr_default")
    initial_balance = float(data.get("initial_balance", 10000.0))

    new_id = f"w_{provider.lower().replace(' ', '')}_{int(datetime.utcnow().timestamp())}"
    wallet_entry = {
        "id": new_id,
        "user_id": user_id,
        "provider": provider,
        "balance": initial_balance,
        "currency": "XOF",
        "account_number": account_number,
        "auth_method": auth_method,
        "is_active": True,
        "last_synced_at": datetime.utcnow().isoformat()
    }

    CONNECTED_USER_WALLETS.append(wallet_entry)
    return {
        "status": "CONNECTED",
        "message": f"✅ Compte {provider} connecté avec succès via {auth_method} !",
        "wallet": wallet_entry
    }

@router.post("/sync")
def sync_user_wallets(user_id: str = "usr_default"):
    """Effectue une synchronisation d'API en direct avec Wave, Orange et MTN (Méthodes 1 & 3)."""
    wave_data = wave_api_service.fetch_live_balance("token")
    orange_data = orange_money_api_service.fetch_live_balance("token")
    mtn_data = mtn_momo_api_service.fetch_live_balance("token")

    synced_wallets = [
        {
            "id": "w_wave_1",
            "user_id": user_id,
            "provider": "Wave",
            "balance": wave_data["balance"],
            "currency": wave_data["currency"],
            "account_number": wave_data["account_number"],
            "auth_method": "OAUTH2_WAVE",
            "is_active": True,
            "last_synced_at": wave_data["last_synced_at"]
        },
        {
            "id": "w_orange_2",
            "user_id": user_id,
            "provider": "Orange Money",
            "balance": orange_data["balance"],
            "currency": orange_data["currency"],
            "account_number": orange_data["account_number"],
            "auth_method": "ORANGE_DEVELOPER_API",
            "is_active": True,
            "last_synced_at": orange_data["last_synced_at"]
        },
        {
            "id": "w_mtn_3",
            "user_id": user_id,
            "provider": "MTN MoMo",
            "balance": mtn_data["balance"],
            "currency": mtn_data["currency"],
            "account_number": mtn_data["account_number"],
            "auth_method": "MTN_MOMO_API",
            "is_active": True,
            "last_synced_at": mtn_data["last_synced_at"]
        }
    ]

    return {
        "status": "SYNCED",
        "message": "✅ Soldes et transactions synchronisés en temps réel via les APIs officielles !",
        "timestamp": datetime.utcnow().isoformat(),
        "wallets": synced_wallets
    }
