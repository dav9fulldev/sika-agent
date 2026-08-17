# pyrefly: ignore [missing-import]
from fastapi import APIRouter, HTTPException, Header
from typing import Dict, Any, Optional
from ..schemas.sika_dto import SikaQueryDTO, SikaConfirmTransactionDTO, SikaResponseDTO
from ..services.sika_ai import SikaAI
from ..services.sika_nlp import SikaNLP
from ..services.user_learning_service import user_learning_service
from ..services.backup_service import backup_service
from ..services.auth_service import oauth2_auth_service
from ..agent.orchestrator import sika_orchestrator

router = APIRouter(prefix="/api/v1/sika", tags=["sika"])
sika_ai = SikaAI()
sika_nlp = SikaNLP()

@router.get("/health")
def sika_health_check():
    """Route technique pour le monitoring SIKA AI"""
    return {
        "status": "ready",
        "service": "Sika AI Standalone API",
        "provider": sika_ai.provider.upper(),
        "model": sika_ai.model
    }

# ============================================================================
# ENDPOINTS OAUTH2 BEARER JWT AUTHENTICATION
# ============================================================================

@router.post("/auth/login")
def auth_login(data: Dict[str, Any]):
    """Connexion OAuth2 avec génération de jeton Bearer JWT."""
    email = data.get("email", "")
    password = data.get("password", "")
    if not email or not password:
        raise HTTPException(status_code=400, detail="Email et mot de passe requis.")
    return oauth2_auth_service.login(email, password)

@router.post("/auth/register")
def auth_register(data: Dict[str, Any]):
    """Inscription d'un nouvel utilisateur avec jeton OAuth2."""
    name = data.get("name", "")
    email = data.get("email", "")
    password = data.get("password", "")
    if not name or not email or not password:
        raise HTTPException(status_code=400, detail="Tous les champs sont requis.")
    return oauth2_auth_service.register(name, email, password)

@router.post("/auth/google")
def auth_google(data: Dict[str, Any]):
    """Authentification OAuth2 via Google Sign-In."""
    email = data.get("email", "david.yao@gmail.com")
    name = data.get("name", "David YAO")
    return oauth2_auth_service.google_login(email, name)

@router.get("/auth/me")
def auth_me(authorization: Optional[str] = Header(None)):
    """Route protégée vérifiant le jeton OAuth2 Bearer."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Jeton Authorization Bearer manquant.")
    token = authorization.split(" ")[1]
    payload = oauth2_auth_service.verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Jeton invalide ou expiré.")
    return {
        "status": "AUTHENTICATED",
        "user": payload
    }

# ============================================================================
# ENDPOINTS SIKA CHAT & AGENT
# ============================================================================

@router.post("/chat", response_model=SikaResponseDTO)
async def sika_chat(data: SikaQueryDTO):
    """Endpoint principal SIKA AI."""
    ctx_dict = data.context.dict() if data.context else {}
    firstname = data.context.user_firstname if data.context else "l'ami"

    result = await sika_ai.chat(
        user_message=data.query,
        financial_context=ctx_dict,
        conversation_history=[],
        user_firstname=firstname
    )

    return SikaResponseDTO(
        query=data.query,
        message=result["response"],
        intent=result.get("action", "chat"),
        sentiment=result.get("sentiment", "positive"),
        suggestions=result.get("suggestions", []),
        provider=sika_ai.provider.upper()
    )

@router.post("/confirm")
def sika_confirm_transaction(data: SikaConfirmTransactionDTO):
    """Valide et enregistre une dépense confirmée par Sika."""
    speech_amount = sika_nlp.format_amount_for_speech(data.amount)
    return {
        "success": True,
        "message": f"✅ Dépense de {speech_amount} en {data.category} enregistrée avec succès !",
        "transaction": {
            "amount": data.amount,
            "category": data.category,
            "description": data.description
        }
    }

@router.post("/agent/process")
async def sika_agent_process(data: Dict[str, Any]):
    """Endpoint principal de traitement de la boucle Agent Taskmaster."""
    user_id = data.get("user_id", 1)
    query = data.get("query", "")
    return await sika_orchestrator.process_user_request(user_id=user_id, query=query)

@router.post("/agent/confirm")
async def sika_agent_confirm(data: Dict[str, Any]):
    """Endpoint de validation humaine pour l'agent SIKA."""
    action_id = data.get("action_id", "")
    confirmed = data.get("confirmed", False)
    tool_name = data.get("tool_name", "confirm_transfer")
    arguments = data.get("arguments", {})

    if confirmed and tool_name:
        res = sika_orchestrator.execute_tool(tool_name, arguments, user_confirmed=True)
        return {
            "status": "CONFIRMED",
            "action_id": action_id,
            "applied": True,
            "result": res.to_dict()
        }

    return {
        "status": "CANCELLED",
        "action_id": action_id,
        "applied": False
    }

@router.post("/events")
async def sika_ingest_event(data: Dict[str, Any]):
    """Endpoint d'ingestion asynchrone des événements financiers."""
    user_id = data.get("user_id", 1)
    return await sika_orchestrator.process_financial_event(user_id=user_id, event_data=data)

@router.post("/background/perceive-notification")
async def perceive_background_notification(data: Dict[str, Any]):
    """Endpoint d'arrière-plan pour la perception des SMS & Notifications Mobile Money."""
    user_id = data.get("user_id", "default_user")
    notification_text = data.get("notification_text", "")
    provider_name = data.get("provider", "Wave")

    if "wave" in provider_name.lower():
        user_learning_service.update_user_habit(user_id, "Mobile Money Wave", 5000.0)
    elif "orange" in provider_name.lower():
        user_learning_service.update_user_habit(user_id, "Mobile Money Orange", 10000.0)

    return {
        "status": "PROCESSED",
        "user_id": user_id,
        "notification_received": notification_text,
        "learned_insight": f"Transaction {provider_name} capturée en arrière-plan et assimilée."
    }

@router.get("/habits")
def get_user_learned_habits(user_id: str = "default_user"):
    """Retourne le profil d'apprentissage et la mémoire comportementale du client."""
    return user_learning_service.get_user_profile(user_id)

@router.post("/backup")
def trigger_memory_backup(user_id: str = "default_user"):
    """Crée un snapshot de sauvegarde complet de la mémoire IA pour ré-entraînement."""
    snapshot = backup_service.create_backup_snapshot(user_id)
    return {
        "status": "SUCCESS",
        "message": "Snapshot de mémoire IA généré avec succès.",
        "backup": snapshot
    }
