# pyrefly: ignore [missing-import]
import logging
import json
import redis
from ..config import settings
# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Query, Header
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta, timezone
from ..database import SessionLocal
from ..models import UserModel, ConnectedWalletModel
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service
from ..services.auth_service import oauth2_auth_service
from ..services.security_rate_limiter import security_rate_limiter

logger = logging.getLogger("WalletRouter")

_otp_memory_store: Dict[str, str] = {}

if settings.REDIS_URL:
    try:
        redis_client = redis.from_url(settings.REDIS_URL, db=0, decode_responses=True)
    except Exception:
        redis_client = None
else:
    try:
        redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
    except Exception:
        redis_client = None


def _set_otp_session(session_id: str, data: Dict[str, Any], ttl_seconds: int = 600) -> None:
    payload = json.dumps(data)
    if redis_client:
        try:
            redis_client.setex(f"otp_session:{session_id}", ttl_seconds, payload)
            return
        except Exception:
            pass
    _otp_memory_store[f"otp_session:{session_id}"] = payload


def _get_otp_session(session_id: str) -> Optional[str]:
    if redis_client:
        try:
            val = redis_client.get(f"otp_session:{session_id}")
            if val is not None:
                return val
        except Exception:
            pass
    return _otp_memory_store.get(f"otp_session:{session_id}")


def _del_otp_session(session_id: str) -> None:
    if redis_client:
        try:
            redis_client.delete(f"otp_session:{session_id}")
        except Exception:
            pass
    _otp_memory_store.pop(f"otp_session:{session_id}", None)


router = APIRouter(prefix="/api/v1/wallets", tags=["wallets"])

# Sessions d'OTP en attente de vérification stockées dans Redis / fallback mémoire

# Compatibilité mémoire
CONNECTED_USER_WALLETS: List[Dict[str, Any]] = []


@router.get("/me")
def get_my_wallets(authorization: Optional[str] = Header(None)):
    """Retourne la liste complète des portefeuilles connectés pour l'utilisateur authentifié depuis PostgreSQL (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    db = SessionLocal()
    try:
        db_wallets = db.query(ConnectedWalletModel).filter(
            ConnectedWalletModel.user_id == user_id,
            ConnectedWalletModel.connection_status == "connected"
        ).all()

        user_wallets = []
        for w in db_wallets:
            w_dict = {
                "id": f"w_{w.id}",
                "user_id": str(w.user_id),
                "provider": w.provider,
                "account_number": w.external_wallet_id,
                "auth_method": "PAYMECHAP_PARTNER_API" if "paymechap" in w.provider.lower() else "OAUTH2_API",
                "is_active": True,
                "balance": 0.0,
                "currency": "XOF",
                "last_synced_at": datetime.utcnow().isoformat()
            }
            prov = w.provider.lower()
            if "paymechap" in prov:
                fetched = paymechap_api_service.fetch_live_balance("", w.external_wallet_id)
                w_dict["balance"] = float(fetched.get("balance", 0.0))
                w_dict["currency"] = fetched.get("currency", "XOF")
            elif "wave" in prov:
                fetched = wave_api_service.fetch_live_balance("token", w.external_wallet_id)
                w_dict["balance"] = float(fetched.get("balance", 0.0))
            elif "orange" in prov:
                fetched = orange_money_api_service.fetch_live_balance("token", w.external_wallet_id)
                w_dict["balance"] = float(fetched.get("balance", 0.0))
            elif "mtn" in prov:
                fetched = mtn_momo_api_service.fetch_live_balance("token", w.external_wallet_id)
                w_dict["balance"] = float(fetched.get("balance", 0.0))

            user_wallets.append(w_dict)

        total_balance = sum(w.get("balance", 0.0) for w in user_wallets)
        return {
            "status": "SUCCESS",
            "user_id": str(user_id),
            "count": len(user_wallets),
            "total_balance_xof": total_balance,
            "wallets": user_wallets
        }
    finally:
        db.close()


@router.get("/transactions/history")
def get_all_wallets_transaction_history(
    limit: int = Query(default=30, ge=1, le=100),
    authorization: Optional[str] = Header(None)
):
    """API de collecte d'historique et des mouvements des comptes de l'utilisateur authentifié depuis PostgreSQL (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    db = SessionLocal()
    try:
        db_wallets = db.query(ConnectedWalletModel).filter(
            ConnectedWalletModel.user_id == user_id,
            ConnectedWalletModel.connection_status == "connected"
        ).all()

        if not db_wallets:
            return {
                "status": "SUCCESS",
                "user_id": str(user_id),
                "count": 0,
                "total_spent_xof": 0.0,
                "total_received_xof": 0.0,
                "movements": []
            }

        movements: List[Dict[str, Any]] = []
        limit_val = int(limit) if str(limit).isdigit() else 30

        for wallet in db_wallets:
            prov = wallet.provider.lower()
            acc = wallet.external_wallet_id
            if "wave" in prov:
                movements.extend(wave_api_service.fetch_live_transactions("token", limit=limit_val))
            elif "orange" in prov:
                movements.extend(orange_money_api_service.fetch_live_transactions("token", limit=limit_val))
            elif "mtn" in prov:
                movements.extend(mtn_momo_api_service.fetch_live_transactions("token", limit=limit_val))
            elif "paymechap" in prov:
                movements.extend(paymechap_api_service.fetch_live_transactions("", account_number=acc, limit=limit_val))

        movements.sort(key=lambda x: x.get("timestamp", ""), reverse=True)
        movements = movements[:limit_val]

        total_spent = sum(t["amount"] for t in movements if t.get("type") in ["payment", "transfer", "withdrawal"])
        total_received = sum(t["amount"] for t in movements if t.get("type") == "deposit")

        return {
            "status": "SUCCESS",
            "user_id": str(user_id),
            "count": len(movements),
            "total_spent_xof": total_spent,
            "total_received_xof": total_received,
            "movements": movements
        }
    finally:
        db.close()


@router.get("/coffres")
def get_user_coffres(authorization: Optional[str] = Header(None)):
    """Récupère la liste des Coffres-forts connectés via PayMeChap depuis PostgreSQL (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    db = SessionLocal()
    try:
        db_wallets = db.query(ConnectedWalletModel).filter(
            ConnectedWalletModel.user_id == user_id,
            ConnectedWalletModel.connection_status == "connected"
        ).all()
        pmc = next((w for w in db_wallets if "paymechap" in w.provider.lower()), None)
        if not pmc:
            return {
                "status": "SUCCESS",
                "user_id": str(user_id),
                "count": 0,
                "coffres": []
            }
        coffres = paymechap_api_service.fetch_user_coffres("", account_number=pmc.external_wallet_id)
        return {
            "status": "SUCCESS",
            "user_id": str(user_id),
            "count": len(coffres),
            "coffres": coffres
        }
    finally:
        db.close()


@router.post("/connect")
def initiate_wallet_connection(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Étape 1 : Demande de connexion d'un portefeuille (Déclenchement OTP SMS/API) (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    provider = data.get("provider") or "PayMeChap"
    account_number = data.get("account_number")
    auth_method = data.get("auth_method", "PAYMECHAP_PARTNER_API")

    if not account_number:
        raise HTTPException(status_code=400, detail="Le numéro de téléphone 'account_number' est obligatoire.")

    prov_lower = provider.lower()
    if "paymechap" in prov_lower:
        otp_res = paymechap_api_service.initiate_otp_challenge(account_number)
        if otp_res.get("success") is False:
            err_msg = otp_res.get("message") or f"Ce numéro ({account_number}) n'est pas enregistré sur PayMeChap."
            status_c = otp_res.get("status_code", 400)
            if status_c == 404:
                status_c = 400
            raise HTTPException(status_code=status_c, detail=err_msg)
        session_id = otp_res.get("session_id", f"sess_pmc_{int(datetime.utcnow().timestamp())}")
    else:
        session_id = f"sess_{prov_lower.replace(' ', '')}_{int(datetime.utcnow().timestamp())}"

    session_data = {
        "session_id": session_id,
        "user_id": user_id,
        "provider": provider,
        "account_number": account_number,
        "auth_method": auth_method,
        "attempts": 0,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    _set_otp_session(session_id, session_data, 600)

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
    """Étape 2 : Vérification du code OTP et enrôlement effectif du compte dans PostgreSQL (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    session_id = data.get("session_id")
    otp_code = data.get("otp_code")
    provider = data.get("provider", "PayMeChap")
    account_number = data.get("account_number", "")

    if not session_id or not otp_code:
        raise HTTPException(status_code=400, detail="Champs 'session_id' et 'otp_code' obligatoires.")

    session_raw = _get_otp_session(session_id)
    if not session_raw:
        raise HTTPException(status_code=400, detail="Session OTP introuvable, expirée ou déjà consommée.")
    
    session = json.loads(session_raw)

    if session.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Session OTP non autorisée pour cet utilisateur.")

    # Incrémentation et protection contre le brute-force OTP (max 3 tentatives)
    attempts = session.get("attempts", 0) + 1
    session["attempts"] = attempts

    if attempts > 3:
        _del_otp_session(session_id)
        raise HTTPException(
            status_code=429,
            detail="Nombre maximal de tentatives OTP dépassé (3). La session a été invalidée."
        )

    _set_otp_session(session_id, session, 600)

    provider = session.get("provider", provider)
    account_number = session.get("account_number", account_number)
    prov_lower = provider.lower()

    if "paymechap" in prov_lower:
        verify_res = paymechap_api_service.verify_otp_code(account_number, otp_code)
        if not verify_res.get("success"):
            if attempts >= 3:
                _del_otp_session(session_id)
                raise HTTPException(status_code=429, detail="Code OTP incorrect. Nombre maximal de tentatives atteint (3). Session invalidée.")
            err_msg = verify_res.get("message") or f"Code OTP incorrect ({attempts}/3 tentatives)."
            raise HTTPException(status_code=400, detail=err_msg)

        fetched = paymechap_api_service.fetch_live_balance("", account_number)
    elif "wave" in prov_lower:
        fetched = wave_api_service.fetch_live_balance("live_token", account_number)
    elif "orange" in prov_lower:
        fetched = orange_money_api_service.fetch_live_balance("live_token", account_number)
    elif "mtn" in prov_lower:
        fetched = mtn_momo_api_service.fetch_live_balance("live_token", account_number)
    else:
        fetched = {"balance": 0.0, "currency": "XOF"}

    # Consommation immédiate de la session OTP (Anti-Replay)
    _del_otp_session(session_id)

    real_balance = float(fetched.get("balance", 0.0))

    # Enregistrement effectif dans PostgreSQL
    db = SessionLocal()
    try:
        existing_w = db.query(ConnectedWalletModel).filter(
            ConnectedWalletModel.user_id == user_id,
            ConnectedWalletModel.provider == provider,
            ConnectedWalletModel.external_wallet_id == account_number
        ).first()

        if not existing_w:
            new_w = ConnectedWalletModel(
                user_id=user_id,
                provider=provider,
                external_wallet_id=account_number,
                connection_status="connected"
            )
            db.add(new_w)
            db.commit()
            db.refresh(new_w)
            w_id = new_w.id
        else:
            existing_w.connection_status = "connected"
            db.commit()
            w_id = existing_w.id

        wallet_entry = {
            "id": f"w_{w_id}",
            "user_id": str(user_id),
            "provider": provider,
            "balance": real_balance,
            "currency": "XOF",
            "account_number": account_number,
            "auth_method": session.get("auth_method", "OAUTH2_API"),
            "is_active": True,
            "last_synced_at": datetime.utcnow().isoformat()
        }

        return {
            "status": "VERIFIED_AND_CONNECTED",
            "message": f"✅ Code OTP validé ! Votre compte {provider} ({account_number}) est maintenant raccordé à SIKA.",
            "wallet": wallet_entry
        }
    finally:
        db.close()


@router.post("/verify-pin")
def verify_transaction_pin(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Vérifie le code PIN de transaction auprès de PayMeChap (Exige JWT + protection anti-brute-force)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    security_rate_limiter.check_pin_rate_limit(str(user_id))

    pin_code = data.get("pin", "")
    if not pin_code:
        raise HTTPException(status_code=400, detail="Le code PIN est obligatoire.")

    account_number = data.get("account_number") or data.get("telephone") or ""
    if not account_number:
        db = SessionLocal()
        try:
            # 1. Recherche du wallet PayMeChap connecté
            active_pmc = db.query(ConnectedWalletModel).filter(
                ConnectedWalletModel.user_id == user_id,
                ConnectedWalletModel.provider.ilike("%paymechap%"),
                ConnectedWalletModel.connection_status == "connected"
            ).first()
            if active_pmc and active_pmc.external_wallet_id:
                account_number = active_pmc.external_wallet_id
            else:
                # 2. Fallback: n'importe quel portefeuille actif enrôlé
                any_wallet = db.query(ConnectedWalletModel).filter(
                    ConnectedWalletModel.user_id == user_id,
                    ConnectedWalletModel.connection_status == "connected"
                ).first()
                if any_wallet and any_wallet.external_wallet_id:
                    account_number = any_wallet.external_wallet_id
                else:
                    # 3. Fallback: numéro de téléphone du profil utilisateur
                    from ..models.user import UserModel
                    user_record = db.query(UserModel).filter(UserModel.id == user_id).first()
                    if user_record and user_record.phone:
                        account_number = user_record.phone
                    else:
                        raise HTTPException(status_code=400, detail="Aucun compte PayMeChap ou numéro de téléphone raccordé à ce profil.")
        finally:
            db.close()

    res = paymechap_api_service.verify_transaction_pin(account_number, pin_code)
    if not res.get("success") or not res.get("valid"):
        security_rate_limiter.record_pin_failure(str(user_id))
        raise HTTPException(status_code=401, detail=res.get("message", "Code PIN PayMeChap incorrect."))

    security_rate_limiter.reset_pin_failures(str(user_id))
    return res


@router.post("/sync")
def sync_user_wallets(authorization: Optional[str] = Header(None)):
    """Synchronise les soldes en direct des comptes de l'utilisateur authentifié depuis PostgreSQL (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    db = SessionLocal()
    try:
        db_wallets = db.query(ConnectedWalletModel).filter(
            ConnectedWalletModel.user_id == user_id,
            ConnectedWalletModel.connection_status == "connected"
        ).all()

        synced_wallets = []
        for w in db_wallets:
            prov = w.provider.lower()
            acc_num = w.external_wallet_id or ""
            if "paymechap" in prov:
                data = paymechap_api_service.fetch_live_balance("", acc_num)
            elif "wave" in prov:
                data = wave_api_service.fetch_live_balance("token", acc_num)
            elif "orange" in prov:
                data = orange_money_api_service.fetch_live_balance("token", acc_num)
            elif "mtn" in prov:
                data = mtn_momo_api_service.fetch_live_balance("token", acc_num)
            else:
                data = {"balance": 0.0, "currency": "XOF"}

            synced_wallets.append({
                "id": f"w_{w.id}",
                "user_id": str(user_id),
                "provider": w.provider,
                "account_number": w.external_wallet_id,
                "balance": float(data.get("balance", 0.0)),
                "currency": data.get("currency", "XOF"),
                "is_active": True,
                "last_synced_at": datetime.utcnow().isoformat()
            })

        return {
            "status": "SUCCESS",
            "user_id": str(user_id),
            "count": len(synced_wallets),
            "wallets": synced_wallets
        }
    finally:
        db.close()


@router.post("/reset")
def reset_all_wallets(authorization: Optional[str] = Header(None)):
    """Réinitialise les portefeuilles de l'utilisateur authentifié dans PostgreSQL (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    db = SessionLocal()
    try:
        db.query(ConnectedWalletModel).filter(ConnectedWalletModel.user_id == user_id).delete()
        db.commit()
        return {"status": "SUCCESS", "message": "Tous les portefeuilles ont été déconnectés."}
    finally:
        db.close()
