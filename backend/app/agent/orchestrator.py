"""
SIKA Agent Orchestrator - Squelette de la Boucle Taskmaster

Pilote le cycle de vie de l'agent: Perception -> Understanding -> Analysis -> Planning -> Execution -> Verification.
"""

import logging
from typing import Dict, Any
from .state_machine import AgentState
from .memory_bridge import memory_bridge
from .tool_registry import tool_registry

logger = logging.getLogger("SikaAgentOrchestrator")

class SikaAgentOrchestrator:
    """Orchestrateur principal de l'agent SIKA."""

    def __init__(self):
        self.state = AgentState.IDLE

    async def process_user_request(self, user_id: int, query: str, session_id: str = "default") -> Dict[str, Any]:
        """Squelette du traitement d'une requête utilisateur active."""
        logger.info(f"[SIKA AGENT] Requête reçue de user_id={user_id}: '{query}'")
        self.state = AgentState.UNDERSTANDING

        # Squelette de réponse (L'intégration Gemini complète sera faite à la Phase 5 étape 2)
        self.state = AgentState.IDLE
        return {
            "query": query,
            "state": self.state.value,
            "status": "PROCESSED",
            "message": "Squelette de l'agent SIKA initialisé avec succès.",
            "requires_confirmation": False
        }

    async def process_financial_event(self, user_id: int, event_data: dict) -> Dict[str, Any]:
        """Squelette du traitement d'un événement financier passif (ex: notification)."""
        logger.info(f"[SIKA AGENT] Événement perçu pour user_id={user_id}: {event_data}")
        self.state = AgentState.PERCEIVING
        
        # Mettre à jour la mémoire du contexte
        memory_bridge.update_financial_context(user_id, {"last_event": event_data})
        
        self.state = AgentState.IDLE
        return {
            "status": "EVENT_RECEIVED",
            "state": self.state.value,
            "processed": True
        }

# Instance globale
sika_orchestrator = SikaAgentOrchestrator()
