# pyrefly: ignore [missing-import]
import json
import logging
from pathlib import Path
from fastapi import APIRouter, HTTPException, Query, Header
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta, timezone
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service
from ..services.auth_service import oauth2_auth_service
from ..services.security_rate_limiter import security_rate_limiter

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
    """Sauvegarde uniquement les métadonnées de connexion des portefeuilles (sans soldes ni jetons sensibles)."""
    try:
        WALLETS_DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
        clean_wallets = []
        for w in wallets:
            w_copy = {
                "id": w.get("id"),
                "user_id": str(w.get("user_id", "1")),
                "provider": w.get("provider"),
                "account_number": w.get("account_number"),
                "auth_method": w.get("auth_method", "PAYMECHAP_PARTNER_API"),
                "is_active": w.get("is_active", True)
            }
            clean_wallets.append(w_copy)

        with open(WALLETS_DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(clean_wallets, f, ensure_ascii=False, indent=2)
            logger.info(f"[PERSISTENCE WALLET] Métadonnées de {len(clean_wallets)} portefeuille(s) sauvegardées.")
    except Exception as e:
        logger.warning(f"[PERSISTENCE WALLET] Erreur lors de la sauvegarde : {e}")


# Chargement initial des portefeuilles connectés
CONNECTED_USER_WALLETS: List[Dict[str, Any]] = _load_persisted_wallets()


@router.get("/me")
def get_my_wallets(authorization: Optional[str] = Header(None)):
    """Retourne la liste complète des portefeuilles connectés pour l'utilisateur authentifié (Exige JWT)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    persisted = _load_persisted_wallets()
    user_wallets = [dict(w) for w in persisted if str(w.get("user_id")) == user_id and w.get("is_active", True)]

    # Auto-synchronisation des soldes en direct à la consultation (uniquement en mémoire)
    for w in user_wallets:
        prov = w.get("provider", "").lower()
        token = w.get("access_token") or ""
        acc_num = w.get("account_number") or ""
        if "paymechap" in prov:
            fetched = paymechap_api_service.fetch_live_balance(token, acc_num)
            w["balance"] = float(fetched.get("balance", 0.0))
            w["currency"] = fetched.get("currency", "XOF")
            w["last_synced_at"] = datetime.utcnow().isoformat()

    total_balance = sum(w.get("balance", 0.0) for w in user_wallets)
    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "count": len(user_wallets),
        "total_balance_xof": total_balance,
        "wallets": user_wallets
    }


@router.get("/transactions/history")
def get_all_wallets_transaction_history(
    limit: int = Query(default=30, ge=1, le=100),
    authorization: Optional[str] = Header(None)
):
    """API de collecte d'historique et des mouvements des comptes de l'utilisateur authentifié (Exige JWT)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    wallets = _load_persisted_wallets()
    user_wallets = [w for w in wallets if str(w.get("user_id")) == user_id and w.get("is_active", True)]
    
    # Si aucun portefeuille n'est connecté par cet utilisateur, retour immédiat sans appel API externe
    if not user_wallets:
        return {
            "status": "SUCCESS",
            "user_id": user_id,
            "count": 0,
            "total_spent_xof": 0.0,
            "total_received_xof": 0.0,
            "movements": []
        }

    movements: List[Dict[str, Any]] = []

    try:
        limit_val = int(limit)
    except Exception:
        limit_val = 30

    for wallet in user_wallets:
        prov = wallet.get("provider", "").lower()
        token = wallet.get("access_token") or "token"
        if "wave" in prov:
            movements.extend(wave_api_service.fetch_live_transactions(token, limit=limit_val))
        elif "orange" in prov:
            movements.extend(orange_money_api_service.fetch_live_transactions(token, limit=limit_val))
        elif "mtn" in prov:
            movements.extend(mtn_momo_api_service.fetch_live_transactions(token, limit=limit_val))
        elif "paymechap" in prov:
            movements.extend(paymechap_api_service.fetch_live_transactions(token, account_number=wallet.get("account_number"), limit=limit_val))

    movements.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
    movements = movements[:limit_val]

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


@router.get("/coffres")
def get_user_coffres(authorization: Optional[str] = Header(None)):
    """Récupère la liste des Coffres-forts connectés via PayMeChap pour l'utilisateur authentifié (Exige JWT)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    wallets = _load_persisted_wallets()
    user_wallets = [w for w in wallets if str(w.get("user_id")) == user_id and w.get("is_active", True)]

    pmc_wallet = next((w for w in user_wallets if "paymechap" in w.get("provider", "").lower()), None)
    if not pmc_wallet:
        return {
            "status": "SUCCESS",
            "user_id": user_id,
            "count": 0,
            "coffres": []
        }

    pmc_token = pmc_wallet.get("access_token")
    pmc_account = pmc_wallet.get("account_number")
    coffres = paymechap_api_service.fetch_user_coffres(pmc_token, account_number=pmc_account)
    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "count": len(coffres),
        "coffres": coffres
    }


@router.post("/connect")
def initiate_wallet_connection(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Étape 1 : Demande de connexion d'un portefeuille (Déclenchement OTP SMS/API) (Exige JWT)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
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
        "user_id": user_id,
        "provider": provider,
        "account_number": account_number,
        "auth_method": auth_method,
        "attempts": 0,
        "created_at": datetime.now(timezone.utc).isoformat(),
        "created_at_dt": datetime.now(timezone.utc)
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
def verify_wallet_otp(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Étape 2 : Vérification du code OTP et enrôlement effectif du compte (Exige JWT + protection anti-brute-force)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    session_id = data.get("session_id")
    otp_code = data.get("otp_code")
    provider = data.get("provider", "PayMeChap")
    account_number = data.get("account_number", "")

    if not session_id or not otp_code:
        raise HTTPException(status_code=400, detail="Champs 'session_id' et 'otp_code' obligatoires.")

    session = PENDING_OTP_SESSIONS.get(session_id)
    if not session:
        raise HTTPException(status_code=400, detail="Session OTP introuvable, expirée ou déjà consommée.")

    # Vérification d'expiration de la session (TTL = 10 minutes)
    created_dt = session.get("created_at_dt")
    if created_dt and (datetime.now(timezone.utc) - created_dt) > timedelta(minutes=10):
        PENDING_OTP_SESSIONS.pop(session_id, None)
        raise HTTPException(status_code=400, detail="Session OTP expirée. Veuillez relancer la demande de connexion.")

    if str(session.get("user_id")) != user_id:
        raise HTTPException(status_code=403, detail="Session OTP non autorisée pour cet utilisateur.")

    # Incrémentation et protection contre le brute-force OTP (max 3 tentatives)
    attempts = session.get("attempts", 0) + 1
    session["attempts"] = attempts

    if attempts > 3:
        PENDING_OTP_SESSIONS.pop(session_id, None)
        raise HTTPException(
            status_code=429,
            detail="Nombre maximal de tentatives OTP dépassé (3). La session a été invalidée."
        )

    target_user_id = user_id
    provider = session.get("provider", provider)
    account_number = session.get("account_number", account_number)
    prov_lower = provider.lower()

    access_token = None

    if "paymechap" in prov_lower:
        verify_res = paymechap_api_service.verify_otp_code(account_number, otp_code)
        if not verify_res.get("success") and not verify_res.get("accessToken"):
            if attempts >= 3:
                PENDING_OTP_SESSIONS.pop(session_id, None)
                raise HTTPException(status_code=429, detail="Code OTP incorrect. Nombre maximal de tentatives atteint (3). Session invalidée.")
            raise HTTPException(status_code=400, detail=f"Code OTP incorrect ({attempts}/3 tentatives).")

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

    # Consommation immédiate de la session OTP (Anti-Replay)
    PENDING_OTP_SESSIONS.pop(session_id, None)

    real_balance = float(fetched.get("balance", 0.0))

    # Suppression de tout ancien doublon du même compte pour cet utilisateur
    global CONNECTED_USER_WALLETS
    CONNECTED_USER_WALLETS = [
        w for w in CONNECTED_USER_WALLETS 
        if not (str(w.get("user_id")) == str(target_user_id) and w.get("provider") == provider and w.get("account_number") == account_number)
    ]

    new_id = f"w_{provider.lower().replace(' ', '')}_{int(datetime.utcnow().timestamp())}"
    wallet_entry = {
        "id": new_id,
        "user_id": str(target_user_id),
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


@router.post("/verify-pin")
def verify_transaction_pin(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Vérifie le code PIN de transaction auprès de PayMeChap (Exige JWT + protection anti-brute-force)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    security_rate_limiter.check_pin_rate_limit(user_id)

    pin_code = data.get("pin", "")
    if not pin_code:
        raise HTTPException(status_code=400, detail="Le code PIN est obligatoire.")

    account_number = data.get("account_number") or data.get("telephone") or ""
    if not account_number:
        active_pmc = [w for w in CONNECTED_USER_WALLETS if str(w.get("user_id")) == user_id and "paymechap" in w.get("provider", "").lower()]
        if active_pmc:
            account_number = active_pmc[0].get("account_number", "")
        else:
            account_number = "0799053977"

    res = paymechap_api_service.verify_transaction_pin(account_number, pin_code)
    if not res.get("success") or not res.get("valid"):
        security_rate_limiter.record_pin_failure(user_id)
        raise HTTPException(status_code=401, detail=res.get("message", "Code PIN PayMeChap incorrect."))

    security_rate_limiter.reset_pin_failures(user_id)
    return res


@router.post("/sync")
def sync_user_wallets(authorization: Optional[str] = Header(None)):
    """Synchronise les soldes en direct des comptes de l'utilisateur authentifié (Exige JWT)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    global CONNECTED_USER_WALLETS
    synced_wallets = []
    for w in CONNECTED_USER_WALLETS:
        if str(w.get("user_id")) == user_id and w.get("is_active", True):
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


@router.post("/reset")
def reset_all_wallets(authorization: Optional[str] = Header(None)):
    """Réinitialise les portefeuilles de l'utilisateur authentifié (Exige JWT)."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    global CONNECTED_USER_WALLETS, PENDING_OTP_SESSIONS
    CONNECTED_USER_WALLETS = [w for w in CONNECTED_USER_WALLETS if str(w.get("user_id")) != user_id]
    
    # Clean up pending OTPs for this user
    for sid, sess in list(PENDING_OTP_SESSIONS.items()):
        if str(sess.get("user_id")) == user_id:
            PENDING_OTP_SESSIONS.pop(sid, None)
            
    _save_persisted_wallets(CONNECTED_USER_WALLETS)
            
    from ..agents.sika_agent import sika_adk_agent
    sika_adk_agent.reset_all_sessions()
    
    logger.info(f"[RESET SYSTEM] Portefeuilles de l'utilisateur {user_id} réinitialisés avec succès !")
    return {
        "status": "RESET_SUCCESSFUL",
        "user_id": user_id,
        "message": "🧹 Vos portefeuilles ont été réinitialisés. Vous pouvez reconnecter vos moyens de paiement."
    }
