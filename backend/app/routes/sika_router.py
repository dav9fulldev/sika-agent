from fastapi import APIRouter, HTTPException
from typing import Dict, Any
from ..schemas.sika_dto import SikaQueryDTO, SikaConfirmTransactionDTO, SikaResponseDTO
from ..services.sika_ai import SikaAI
from ..services.sika_nlp import SikaNLP

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

@router.post("/chat", response_model=SikaResponseDTO)
async def sika_chat(data: SikaQueryDTO):
    """
    Endpoint principal SIKA AI.
    Reçoit la requête et le contexte financier DTO (sans couplage direct avec DB).
    """
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
    """
    Valide et enregistre une dépense confirmée par Sika.
    Formate le message de confirmation avec SikaNLP.
    """
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

# ============================================================================
# ENDPOINTS TASKMASTER AGENT (PHASE 5 SQUELETTE)
# ============================================================================

@router.post("/agent/process")
async def sika_agent_process(data: Dict[str, Any]):
    """Endpoint principal de traitement de la boucle Agent Taskmaster."""
    user_id = data.get("user_id", 1)
    query = data.get("query", "")
    return {
        "status": "PROCESSED",
        "agent_state": "IDLE",
        "message": "Squelette de l'agent Taskmaster prêt.",
        "requires_confirmation": False
    }

@router.post("/agent/confirm")
async def sika_agent_confirm(data: Dict[str, Any]):
    """Endpoint de validation humaine (Human-in-the-loop) pour l'agent SIKA."""
    action_id = data.get("action_id", "")
    confirmed = data.get("confirmed", False)
    return {
        "status": "CONFIRMED" if confirmed else "CANCELLED",
        "action_id": action_id,
        "applied": confirmed
    }

@router.post("/events")
async def sika_ingest_event(data: Dict[str, Any]):
    """Endpoint d'ingestion asynchrone des événements financiers (Passif Mobile Money)."""
    return {
        "status": "EVENT_INGESTED",
        "received": True
    }
