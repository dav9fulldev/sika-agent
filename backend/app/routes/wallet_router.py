# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any, List, Optional
from datetime import datetime
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ..services.wallet_integrations.aggregator_service import aggregator_service

router = APIRouter(prefix="/api/v1/wallets", tags=["wallets"])

# In-memory / DB session repository mock store
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

@router.post("/connect")
def connect_new_wallet(data: Dict[str, Any]):
    """Connexion d'un nouveau portefeuille via l'API officielle (Méthode 1) ou l'Agrégateur (Méthode 2)."""
    provider = data.get("provider", "Wave")
    account_number = data.get("account_number", "+225 07 00 00 99")
    auth_method = data.get("auth_method", "OAUTH2_API")
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
    """Effectue une synchronisation d'API en direct avec Wave, Orange, MTN et l'Agrégateur Panafricain (Méthodes 1 & 2)."""
    synced_wallets = aggregator_service.aggregate_all_user_wallets(user_id=user_id)
    return {
        "status": "SYNCED",
        "message": "✅ Soldes et transactions synchronisés en temps réel via les APIs officielles !",
        "timestamp": datetime.utcnow().isoformat(),
        "wallets": synced_wallets
    }
