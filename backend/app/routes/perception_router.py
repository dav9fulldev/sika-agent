# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Header
from typing import Dict, Any, Optional
from ..database import SessionLocal
from ..models import ConnectedWalletModel
from ..services.sika_perception_service import sika_perception_service
from ..services.auth_service import oauth2_auth_service

router = APIRouter(prefix="/api/v1/perception", tags=["perception"])

PERCEPTIONS_LOG: list = []

@router.post("/sms")
def perceive_sms_notification(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Endpoint principal du Moteur de Perception (Méthode 3) protégé par JWT.

    Reçoit les SMS ou Notifications Push interceptés par l'application SIKA,
    extrait automatiquement le montant, le mouvement et met à jour le solde du portefeuille
    appartenant EXCLUSIVEMENT à l'utilisateur authentifié.
    """
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    raw_text = data.get("text", "")
    sender = data.get("sender", "WAVE")

    if not raw_text:
        raise HTTPException(status_code=400, detail="Texte de notification ou SMS requis.")

    parsed = sika_perception_service.parse_notification(raw_text, sender)
    provider = parsed.get("provider", "")
    new_balance = parsed.get("new_balance")
    parsed["user_id"] = str(user_id)

    # Idempotence : Si ce SMS a déjà été perçu récemment pour cet utilisateur, on ne duplique pas le log
    duplicate = next(
        (p for p in PERCEPTIONS_LOG[:10] if p.get("user_id") == str(user_id) and p.get("raw_text", p.get("text")) == raw_text),
        None
    )
    if duplicate:
        return {
            "status": "ALREADY_PERCEIVED",
            "user_id": str(user_id),
            "message": f"⚡ SMS {provider} déjà traité (idempotent).",
            "parsed_data": duplicate,
            "updated_wallet": None
        }

    target_wallet_dict = None
    db = SessionLocal()
    try:
        target_wallet = db.query(ConnectedWalletModel).filter(
            ConnectedWalletModel.user_id == user_id,
            ConnectedWalletModel.provider.ilike(f"%{provider}%"),
            ConnectedWalletModel.connection_status == "connected"
        ).first()

        if target_wallet:
            target_wallet_dict = {
                "id": f"w_{target_wallet.id}",
                "user_id": str(user_id),
                "provider": target_wallet.provider,
                "account_number": target_wallet.external_wallet_id,
                "balance": float(new_balance) if new_balance is not None else 0.0,
                "last_synced_at": parsed.get("timestamp")
            }
    finally:
        db.close()

    parsed["text"] = raw_text
    PERCEPTIONS_LOG.insert(0, parsed)

    return {
        "status": "PERCEIVED",
        "user_id": str(user_id),
        "message": f"⚡ SMS {provider} intercepté et analysé avec succès par SIKA !",
        "parsed_data": parsed,
        "updated_wallet": target_wallet_dict
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
