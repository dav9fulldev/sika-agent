# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Header
from typing import Dict, Any, Optional
from ..services.sika_perception_service import sika_perception_service
from ..services.auth_service import oauth2_auth_service
from .wallet_router import CONNECTED_USER_WALLETS

router = APIRouter(prefix="/api/v1/perception", tags=["perception"])

PERCEPTIONS_LOG: list = []

@router.post("/sms")
def perceive_sms_notification(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Endpoint principal du Moteur de Perception (Méthode 3) protégé par JWT.

    Reçoit les SMS ou Notifications Push interceptés par l'application SIKA,
    extrait automatiquement le montant, le mouvement et met à jour le solde du portefeuille
    appartenant EXCLUSIVEMENT à l'utilisateur authentifié.
    """
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    raw_text = data.get("text", "")
    sender = data.get("sender", "WAVE")

    if not raw_text:
        raise HTTPException(status_code=400, detail="Texte de notification ou SMS requis.")

    parsed = sika_perception_service.parse_notification(raw_text, sender)
    provider = parsed.get("provider", "")
    new_balance = parsed.get("new_balance")
    parsed["user_id"] = user_id

    # Mise à jour automatique du solde du portefeuille correspondant STRICTEMENT à cet utilisateur
    target_wallet = next(
        (
            w for w in CONNECTED_USER_WALLETS
            if str(w.get("user_id")) == user_id
            and w.get("is_active", True)
            and w.get("provider", "").lower() in provider.lower()
        ),
        None
    )
    if target_wallet and new_balance is not None:
        target_wallet["balance"] = new_balance
        target_wallet["last_synced_at"] = parsed.get("timestamp")

    PERCEPTIONS_LOG.insert(0, parsed)

    return {
        "status": "PERCEIVED",
        "user_id": user_id,
        "message": f"⚡ SMS {provider} intercepté et analysé avec succès par SIKA !",
        "parsed_data": parsed,
        "updated_wallet": target_wallet
    }

@router.get("/logs")
def get_perceptions_log(limit: int = 20, authorization: Optional[str] = Header(None)):
    """Retourne la liste des SMS & Notifications interceptés par le Moteur de Perception pour l'utilisateur authentifié."""
    user_id = str(oauth2_auth_service.require_authenticated_user_id(authorization))
    user_logs = [p for p in PERCEPTIONS_LOG if str(p.get("user_id")) == user_id]
    return {
        "status": "SUCCESS",
        "user_id": user_id,
        "count": len(user_logs[:limit]),
        "perceptions": user_logs[:limit]
    }

@router.post("/simulate")
def simulate_sms_perception(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Endpoint de démonstration permettant d'injecter et tester la perception d'un SMS Telco."""
    sms_text = data.get(
        "sms_text",
        "Vous avez reçu 15 000 FCFA de Kouamé via Wave. Votre nouveau solde est de 45 000 FCFA. Ref: WAV99283."
    )
    sender = data.get("sender", "WAVE")

    return perceive_sms_notification({"text": sms_text, "sender": sender}, authorization=authorization)
