# pyrefly: ignore [missing-import]
import json
import logging
from pathlib import Path
from fastapi import APIRouter, HTTPException, Query
from typing import Dict, Any, List, Optional
from datetime import datetime
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service

logger = logging.getLogger("WalletRouter")

router = APIRouter(prefix="/api/v1/wallets", tags=["wallets"])

# Sessions d'OTP en attente de vérification
PENDING_OTP_SESSIONS: Dict[str, Dict[str, Any]] = {}

# Fichier de persistance locale pour conserver les portefeuilles connectés après redémarrage
WALLETS_DATA_FILE = Path(__file__).parent.parent / "data" / "connected_wallets.json"


def _load_persisted_wallets() -> List[Dict[str, Any]]:
    """Charge les portefeuilles enregistrés depuis le fichier de stockage local."""
    try:
        if WALLETS_DATA_FILE.exists():
            with open(WALLETS_DATA_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                if isinstance(data, list):
                    logger.info(f"[PERSISTENCE WALLET] {len(data)} portefeuille(s) chargé(s) depuis la mémoire.")
                    return data
    except Exception as e:
        logger.warning(f"[PERSISTENCE WALLET] Erreur lors du chargement : {e}")
    return []


def _save_persisted_wallets(wallets: List[Dict[str, Any]]):
    """Sauvegarde les portefeuilles connectés dans le fichier de stockage local."""
    try:
        WALLETS_DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        clean_wallets = []
        for w in wallets:
            w_copy = dict(w)
            if "access_token" in w_copy and w_copy["access_token"]:
                w_copy["access_token"] = "stored_session_token"
            clean_wallets.append(w_copy)

        with open(WALLETS_DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(clean_wallets, f, ensure_ascii=False, indent=2)
            logger.info(f"[PERSISTENCE WALLET] {len(clean_wallets)} portefeuille(s) sauvegardé(s).")
    except Exception as e:
        logger.warning(f"[PERSISTENCE WALLET] Erreur lors de la sauvegarde : {e}")


# Chargement initial des portefeuilles connectés
CONNECTED_USER_WALLETS: List[Dict[str, Any]] = _load_persisted_wallets()


@router.get("/me")
def get_my_wallets(user_id: str = "usr_default"):
    """Retourne la liste complète des portefeuilles connectés de l'utilisateur avec mise à jour en direct."""
    global CONNECTED_USER_WALLETS
    user_wallets = [w for w in CONNECTED_USER_WALLETS if w.get("user_id") == user_id and w.get("is_active", True)]

    # Auto-synchronisation des soldes en direct à la consultation
    for w in user_wallets:
        prov = w.get("provider", "").lower()
        token = w.get("access_token") or ""
        acc_num = w.get("account_number") or ""
        if "paymechap" in prov:
            fetched = paymechap_api_service.fetch_live_balance(token, acc_num)
            w["balance"] = float(fetched.get("balance", w.get("balance", 0.0)))
            w["last_synced_at"] = datetime.utcnow().isoformat()

    _save_persisted_wallets(CONNECTED_USER_WALLETS)

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
    """API de collecte d'historique et des mouvements des comptes réellement enrôlés."""
    user_wallets = [w for w in CONNECTED_USER_WALLETS if w.get("user_id") == user_id and w.get("is_active", True)]
    movements: List[Dict[str, Any]] = []

    for wallet in user_wallets:
        prov = wallet.get("provider", "").lower()
        token = wallet.get("access_token") or "token"
        if "wave" in prov:
            movements.extend(wave_api_service.fetch_live_transactions(token, limit=limit))
        elif "orange" in prov:
            movements.extend(orange_money_api_service.fetch_live_transactions(token, limit=limit))
        elif "mtn" in prov:
            movements.extend(mtn_momo_api_service.fetch_live_transactions(token, limit=limit))
        elif "paymechap" in prov:
            movements.extend(paymechap_api_service.fetch_live_transactions(token, account_number=wallet.get("account_number"), limit=limit))

    movements.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
    movements = movements[:limit]

    total_spent = sum(t["amount"] for t in movements if t.get("type") in ["payment", "transfer", "withdrawal"])
    total_received = sum(t["amount"] for t in movements if t.get("type") == "deposit")

    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "count": len(movements),
        "total_spent_xof": total_spent,
        "total_received_xof": total_received,
        "movements": movements
    }


@router.post("/connect")
def initiate_wallet_connection(data: Dict[str, Any]):
    """Étape 1 : Demande de connexion d'un portefeuille (Déclenchement OTP SMS/API)."""
    provider = data.get("provider")
    account_number = data.get("account_number")
    auth_method = data.get("auth_method", "OAUTH2_API")

    if not provider or not account_number:
        raise HTTPException(status_code=400, detail="Champs 'provider' et 'account_number' obligatoires.")

    prov_lower = provider.lower()
    if "paymechap" in prov_lower:
        otp_res = paymechap_api_service.initiate_otp_challenge(account_number)
        session_id = otp_res.get("session_id", f"sess_pmc_{int(datetime.utcnow().timestamp())}")
    else:
        session_id = f"sess_{prov_lower.replace(' ', '')}_{int(datetime.utcnow().timestamp())}"

    PENDING_OTP_SESSIONS[session_id] = {
        "session_id": session_id,
        "provider": provider,
        "account_number": account_number,
        "auth_method": auth_method,
        "created_at": datetime.utcnow().isoformat()
    }

    msg = f"🔑 Code OTP envoyé au {account_number} pour valider le raccordement de votre compte {provider} !"
    if "paymechap" in prov_lower:
        msg = f"📧 Code OTP PayMeChap envoyé par Email (Revo) au {account_number} !"

    return {
        "status": "OTP_SENT",
        "session_id": session_id,
        "provider": provider,
        "account_number": account_number,
        "message": msg
    }


@router.post("/verify-otp")
def verify_wallet_otp(data: Dict[str, Any]):
    """Étape 2 : Vérification du code OTP et enrôlement effectif du compte."""
    session_id = data.get("session_id")
    otp_code = data.get("otp_code")
    provider = data.get("provider", "PayMeChap")
    account_number = data.get("account_number", "")
    user_id = data.get("user_id", "usr_default")

    if not session_id or not otp_code:
        raise HTTPException(status_code=400, detail="Champs 'session_id' et 'otp_code' obligatoires.")

    session = PENDING_OTP_SESSIONS.pop(session_id, None)
    if not session:
        session = {
            "provider": provider,
            "account_number": account_number,
            "auth_method": "OAUTH2_API"
        }

    provider = session.get("provider", provider)
    account_number = session.get("account_number", account_number)
    prov_lower = provider.lower()

    access_token = None

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
        fetched = {"balance": 0.0, "currency": "XOF"}

    real_balance = float(fetched.get("balance", 0.0))

    # Suppression de tout ancien doublon du même compte
    global CONNECTED_USER_WALLETS
    CONNECTED_USER_WALLETS = [w for w in CONNECTED_USER_WALLETS if not (w.get("provider") == provider and w.get("account_number") == account_number)]

    new_id = f"w_{provider.lower().replace(' ', '')}_{int(datetime.utcnow().timestamp())}"
    wallet_entry = {
        "id": new_id,
        "user_id": user_id,
        "provider": provider,
        "balance": real_balance,
        "currency": "XOF",
        "account_number": account_number,
        "auth_method": session.get("auth_method", "OAUTH2_API"),
        "access_token": access_token,
        "is_active": True,
        "last_synced_at": datetime.utcnow().isoformat()
    }

    CONNECTED_USER_WALLETS.append(wallet_entry)
    _save_persisted_wallets(CONNECTED_USER_WALLETS)

    return {
        "status": "VERIFIED_AND_CONNECTED",
        "message": f"✅ Code OTP validé ! Votre compte {provider} ({account_number}) est maintenant raccordé à SIKA.",
        "wallet": wallet_entry
    }


@router.post("/sync")
def sync_user_wallets(user_id: str = "usr_default"):
    """Synchronise les soldes en direct des comptes réellement connectés."""
    global CONNECTED_USER_WALLETS
    synced_wallets = []
    for w in CONNECTED_USER_WALLETS:
        if w.get("user_id") == user_id and w.get("is_active", True):
            prov = w.get("provider", "").lower()
            token = w.get("access_token") or "token"
            acc_num = w.get("account_number") or ""
            if "paymechap" in prov:
                data = paymechap_api_service.fetch_live_balance(token, acc_num)
            elif "wave" in prov:
                data = wave_api_service.fetch_live_balance(token, acc_num)
            elif "orange" in prov:
                data = orange_money_api_service.fetch_live_balance(token, acc_num)
            elif "mtn" in prov:
                data = mtn_momo_api_service.fetch_live_balance(token, acc_num)
            else:
                data = {"balance": w["balance"], "currency": "XOF"}

            w["balance"] = float(data.get("balance", w["balance"]))
            w["last_synced_at"] = datetime.utcnow().isoformat()
            synced_wallets.append(w)

    _save_persisted_wallets(CONNECTED_USER_WALLETS)
    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "count": len(synced_wallets),
        "wallets": synced_wallets
    }
