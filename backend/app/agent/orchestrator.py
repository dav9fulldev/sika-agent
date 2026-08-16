import logging
import os
from typing import Dict, Any, List
from .state_machine import AgentState
from .memory_bridge import memory_bridge
from .tool_registry import tool_registry
from .tools.tool_models import ToolResult
from . import tools
from ..services.sika_ai import SikaAI

logger = logging.getLogger("SikaAgentOrchestrator")

class SikaAgentOrchestrator:
    """Orchestrateur principal de l'agent SIKA avec raisonnement Google Gemini."""

    def __init__(self):
        self.state = AgentState.IDLE
        self.registry = tool_registry
        self.ai_service = SikaAI()

    def list_available_tools(self) -> List[Dict[str, Any]]:
        """Retourne la liste des tools disponibles dans le registre."""
        return self.registry.list_tools()

    def execute_tool(self, tool_name: str, arguments: Dict[str, Any] = None, user_confirmed: bool = False) -> ToolResult:
        """Exécute un tool par son nom via le ToolRegistry."""
        logger.info(f"[SIKA AGENT] Exécution du tool '{tool_name}' (Arguments: {arguments})")
        return self.registry.execute(tool_name, arguments, user_confirmed=user_confirmed)

    async def process_user_request(self, user_id: int, query: str, session_id: str = "default") -> Dict[str, Any]:
        """Exécute la boucle agentique Taskmaster basée sur Google Gemini."""
        logger.info(f"[SIKA AGENT] Requête reçue de user_id={user_id}: '{query}'")
        self.state = AgentState.UNDERSTANDING

        # 1. Récupération du contexte financier via MemoryBridge
        context = memory_bridge.get_financial_context(user_id)

        # 2. Analyse et raisonnement LLM via Google Gemini (SikaAI)
        self.state = AgentState.ANALYZING
        ai_response = await self.ai_service.chat(
            user_message=query,
            financial_context=context,
            user_firstname="David"
        )

        action = ai_response.get("action") or ai_response.get("intent")
        requires_confirmation = False
        tool_result = None

        # 3. Planning et exécution des tools financiers selon le niveau de risque
        if action and self.registry.exists(action):
            self.state = AgentState.PLANNING
            tool_meta = self.registry.get_definition(action)
            if tool_meta and tool_meta.risk_level.value in ["CONFIRMATION_REQUIRED", "EXECUTION"]:
                requires_confirmation = True
                self.state = AgentState.WAITING_CONFIRMATION
            else:
                self.state = AgentState.EXECUTING
                tool_exec = self.registry.execute(action, ai_response.get("action_data", {}))
                tool_result = tool_exec.to_dict()
                self.state = AgentState.VERIFYING
        else:
            self.state = AgentState.VERIFYING

        final_state = self.state.value
        self.state = AgentState.IDLE

        return {
            "query": query,
            "state": final_state,
            "status": "PROCESSED",
            "message": ai_response.get("response", ai_response.get("message")),
            "action": action,
            "tool_result": tool_result,
            "requires_confirmation": requires_confirmation,
            "provider": ai_response.get("provider", self.ai_service.provider.upper()),
            "model": ai_response.get("model", self.ai_service.model)
        }

    async def process_financial_event(self, user_id: int, event_data: dict) -> Dict[str, Any]:
        """Traitement d'un événement financier passif (ex: notification Mobile Money)."""
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
