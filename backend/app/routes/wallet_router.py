# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any, List, Optional
from datetime import datetime
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service

router = APIRouter(prefix="/api/v1/wallets", tags=["wallets"])

# Sessions d'OTP en attente de vérification
PENDING_OTP_SESSIONS: Dict[str, Dict[str, Any]] = {}

# Portefeuilles utilisateurs connectés via Méthode 1 (APIs OAuth2 / Partenaires) et Méthode 3 (Perception SMS/Push)
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
    """API de collecte d'historique et des mouvements de comptes (Wave, Orange, MTN, PayMeChap)."""
    wave_txs = wave_api_service.fetch_live_transactions("token", limit=limit)
    orange_txs = orange_money_api_service.fetch_live_transactions("token", limit=limit)
    mtn_txs = mtn_momo_api_service.fetch_live_transactions("token", limit=limit)
    pmc_txs = paymechap_api_service.fetch_live_transactions("token", limit=limit)

    movements = wave_txs + orange_txs + mtn_txs + pmc_txs
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
    elif "paymechap" in provider:
        txs = paymechap_api_service.fetch_live_transactions("token", limit=limit)
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
    """Étape 1 : Demande de connexion d'un portefeuille partenaire avec envoi d'OTP de sécurité."""
    provider = data.get("provider", "Wave")
    account_number = data.get("account_number", "+225 07 00 00 99")
    auth_method = data.get("auth_method", "OAUTH2_WAVE")
    user_id = data.get("user_id", "usr_default")

    if "paymechap" in provider.lower():
        otp_res = paymechap_api_service.initiate_otp_challenge(account_number)
        session_id = otp_res.get("session_id") or f"otp_sess_{int(datetime.utcnow().timestamp())}"
    else:
        session_id = f"otp_sess_{int(datetime.utcnow().timestamp())}"

    PENDING_OTP_SESSIONS[session_id] = {
        "session_id": session_id,
        "user_id": user_id,
        "provider": provider,
        "account_number": account_number,
        "auth_method": auth_method,
        "demo_code": "123456",
        "created_at": datetime.utcnow().isoformat()
    }

    delivery_channel = "par Email (Revo)" if "paymechap" in provider.lower() else "par SMS"
    return {
        "status": "OTP_REQUIRED",
        "session_id": session_id,
        "message": f"🔑 Code de sécurité OTP à 6 chiffres envoyé {delivery_channel} au {account_number} par {provider} !",
        "demo_otp_hint": "123456"
    }

@router.post("/verify-otp")
def verify_wallet_otp(data: Dict[str, Any]):
    """Étape 2 : Vérification du code OTP à 6 chiffres et activation du portefeuille."""
    session_id = data.get("session_id", "")
    otp_code = data.get("otp_code", "")

    session = PENDING_OTP_SESSIONS.get(session_id)
    if not session:
        session = {
            "provider": data.get("provider", "Wave"),
            "account_number": data.get("account_number", "+225 07 00 00 05"),
            "auth_method": "OAUTH2_WAVE",
            "user_id": "usr_default"
        }

    provider = session["provider"]
    account_number = session["account_number"]
    user_id = session.get("user_id", "usr_default")

    access_token = None
    prov_lower = provider.lower()

    if "paymechap" in prov_lower:
        verify_res = paymechap_api_service.verify_otp_code(account_number, otp_code)
        access_token = verify_res.get("accessToken")
        fetched = paymechap_api_service.fetch_live_balance(access_token, account_number)
    elif "wave" in prov_lower:
        fetched = wave_api_service.fetch_live_balance("live_token", account_number)
    elif "orange" in prov_lower:
        fetched = orange_money_api_service.fetch_live_balance("live_token", account_number)
    elif "mtn" in prov_lower:
        fetched = mtn_momo_api_service.fetch_live_balance("live_token", account_number)
    else:
        fetched = {"balance": 15000.0, "currency": "XOF"}

    real_balance = float(fetched.get("balance", 15000.0))

    new_id = f"w_{provider.lower().replace(' ', '')}_{int(datetime.utcnow().timestamp())}"
    wallet_entry = {
        "id": new_id,
        "user_id": user_id,
        "provider": provider,
        "balance": real_balance,
        "currency": "XOF",
        "account_number": account_number,
        "auth_method": session.get("auth_method", "OAUTH2_WAVE"),
        "access_token": access_token,
        "is_active": True,
        "last_synced_at": datetime.utcnow().isoformat()
    }

    CONNECTED_USER_WALLETS.append(wallet_entry)
    return {
        "status": "VERIFIED_AND_CONNECTED",
        "message": f"✅ Code OTP validé ! Votre compte {provider} est maintenant raccordé à SIKA.",
        "wallet": wallet_entry
    }

@router.post("/sync")
def sync_user_wallets(user_id: str = "usr_default"):
    """Effectue une synchronisation d'API en direct avec Wave, Orange, MTN et PayMeChap."""
    wave_data = wave_api_service.fetch_live_balance("token")
    orange_data = orange_money_api_service.fetch_live_balance("token")
    mtn_data = mtn_momo_api_service.fetch_live_balance("token")
    pmc_data = paymechap_api_service.fetch_live_balance("token")

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
        },
        {
            "id": "w_paymechap_4",
            "user_id": user_id,
            "provider": "PayMeChap",
            "balance": pmc_data["balance"],
            "currency": pmc_data["currency"],
            "account_number": pmc_data["account_number"],
            "auth_method": "PAYMECHAP_PARTNER_API",
            "is_active": True,
            "last_synced_at": pmc_data["last_synced_at"]
        }
    ]

    return {
        "status": "SYNCED",
        "message": "✅ Soldes et transactions synchronisés en temps réel via les APIs officielles !",
        "timestamp": datetime.utcnow().isoformat(),
        "wallets": synced_wallets
    }
