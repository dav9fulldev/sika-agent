"""
Orchestrateur de l'agent SIKA Pay.

Rôle : point d'entrée de la boucle agentique (/api/v1/sika/agent/process) et accès au ToolRegistry.
Les opérations financières ne passent JAMAIS par l'orchestrateur : la création et la capture de
commandes PayPal sont exécutées uniquement par PayPalCheckoutService, à la demande explicite
de l'utilisateur (endpoints /api/v1/paypal/checkouts/{id}/confirm|capture).
"""

import logging
from typing import Dict, Any, List, Optional

from .state_machine import AgentState
from .memory_bridge import memory_bridge
from .tool_registry import tool_registry
from .tools.tool_models import ToolResult
from ..services.sika_ai import SikaAI

logger = logging.getLogger("SikaAgentOrchestrator")


class SikaAgentOrchestrator:
    """Orchestrateur principal de l'agent SIKA (raisonnement Gemini + tools contrôlés)."""

    def __init__(self):
        self.state = AgentState.IDLE
        self.registry = tool_registry
        self.ai_service = SikaAI()

    def list_available_tools(self) -> List[Dict[str, Any]]:
        """Retourne la liste des tools disponibles dans le registre."""
        return self.registry.list_tools()

    def execute_tool(self, tool_name: str, arguments: Optional[Dict[str, Any]] = None, user_confirmed: bool = False) -> ToolResult:
        """Exécute un tool par son nom via le ToolRegistry."""
        logger.info(f"[SIKA AGENT] Exécution du tool '{tool_name}'")
        return self.registry.execute(tool_name, arguments, user_confirmed=user_confirmed)

    async def process_user_request(self, user_id: int = 1, query: str = "") -> Dict[str, Any]:
        """Traite une requête utilisateur via l'agent SIKA Pay."""
        self.state = AgentState.ANALYZING
        result = await self.ai_service.chat(user_message=query, user_id=str(user_id))
        prepared = bool(result.get("requires_confirmation"))
        self.state = AgentState.IDLE
        return {
            "query": query,
            "state": (AgentState.WAITING_CONFIRMATION if prepared else AgentState.INFORMING).value,
            "status": result.get("status", "PROCESSED"),
            "message": result.get("response"),
            "action": result.get("action"),
            "action_id": result.get("action_id"),
            "action_data": result.get("action_data"),
            "requires_confirmation": prepared,
            "provider": result.get("provider"),
            "model": result.get("model"),
            "agent_steps": result.get("agent_steps", []),
        }

    async def process_financial_event(self, user_id: int, event_data: dict) -> Dict[str, Any]:
        """Traitement d'un événement passif (notification perçue)."""
        self.state = AgentState.PERCEIVING
        memory_bridge.update_financial_context(user_id, {"last_event": event_data})
        self.state = AgentState.IDLE
        return {"status": "EVENT_RECEIVED", "state": self.state.value, "processed": True}


# Instance globale
sika_orchestrator = SikaAgentOrchestrator()
