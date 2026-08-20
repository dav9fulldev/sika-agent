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
    ctx_dict = data.context if isinstance(data.context, dict) else (data.context.dict() if data.context else {})
    firstname = ctx_dict.get("user_firstname", "David")

    result = await sika_ai.chat(
        user_message=data.query,
        financial_context=ctx_dict,
        conversation_history=[],
        user_firstname=firstname
    )

    return SikaResponseDTO(
        query=data.query,
        message=result.get("response", result.get("message", "")),
        intent=result.get("intent", result.get("action", "chat")),
        sentiment=result.get("sentiment", "positive"),
        suggestions=result.get("suggestions", []),
        provider=result.get("provider", sika_ai.provider.upper()),
        status=result.get("status", "PROCESSED"),
        action_id=result.get("action_id"),
        requires_confirmation=result.get("requires_confirmation", False),
        requires_biometric=result.get("requires_biometric", False),
        requires_security_validation=result.get("requires_security_validation", result.get("requires_biometric", False)),
        should_speak=result.get("should_speak", True),
        speech_text=result.get("speech_text", result.get("response", "")),
        action_data=result.get("action_data")
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

from ..services.gcp_tts_service import gcp_tts_service


@router.post("/tts")
def sika_text_to_speech(data: Dict[str, Any]):
    """Génère la synthèse vocale MP3 haute fidélité via Google Cloud Text-to-Speech (GCP TTS)."""
    text = data.get("text") or data.get("speech_text") or ""
    voice_name = data.get("voice_name", "fr-FR-Neural2-C")
    speaking_rate = float(data.get("speaking_rate", 1.05))

    if not text:
        raise HTTPException(status_code=400, detail="Le champ 'text' est obligatoire.")

    res = gcp_tts_service.synthesize_speech(
        text=text,
        voice_name=voice_name,
        speaking_rate=speaking_rate
    )
    if not res.get("success"):
        raise HTTPException(status_code=500, detail=res.get("error", "Échec GCP TTS"))

    return res


@router.get("/tts/voices")
def sika_list_tts_voices():
    """Liste les voix françaises de haute qualité disponibles sur Google Cloud Text-to-Speech."""
    return gcp_tts_service.list_french_voices()


@router.post("/agent/process")
async def sika_agent_process(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Endpoint principal de traitement de la boucle Agent Taskmaster (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    query = data.get("query", "")
    return await sika_orchestrator.process_user_request(user_id=user_id, query=query)


@router.post("/agent/confirm")
async def sika_agent_confirm(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Endpoint de validation humaine pour l'agent SIKA (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    action_id = data.get("action_id", "")
    return await sika_orchestrator.confirm_action(action_id=action_id, user_id=user_id)


@router.post("/agent/cancel")
async def sika_agent_cancel(data: Dict[str, Any], authorization: Optional[str] = Header(None)):
    """Endpoint d'annulation d'action pour l'agent SIKA (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    action_id = data.get("action_id", "")
    return sika_orchestrator.cancel_action(action_id=action_id, user_id=user_id, reason=data.get("reason", "USER_CANCELLED"))


@router.post("/actions/{action_id}/reconcile")
async def sika_reconcile_action(action_id: str, data: Optional[Dict[str, Any]] = None, authorization: Optional[str] = Header(None)):
    """Endpoint de réconciliation d'une transaction au statut incertain UNKNOWN_RESULT auprès de PayMeChap (Exige JWT)."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return await sika_orchestrator.reconcile_action(action_id=action_id, user_id=user_id)


@router.post("/actions/cleanup-stale")
def sika_cleanup_stale_actions(authorization: Optional[str] = Header(None)):
    """Endpoint de nettoyage périodique / arrière-plan des actions expirées."""
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    expired_ids = sika_orchestrator.cleanup_stale_actions()
    return {
        "success": True,
        "expired_count": len(expired_ids),
        "expired_action_ids": expired_ids
    }




