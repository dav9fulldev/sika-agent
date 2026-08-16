"""
Registre de Tools pour l'Agent SIKA

Permet d'enregistrer et d'exposer les fonctions Python sous forme de Tools pour Gemini Function Calling.
"""

from typing import Dict, Callable, Any, List
import logging

logger = logging.getLogger("SikaToolRegistry")

class SikaToolRegistry:
    """Registre central des tools de l'agent."""

    def __init__(self):
        self._tools: Dict[str, Callable] = {}
        self._metadata: Dict[str, dict] = {}

    def register_tool(self, name: str, description: str, requires_confirmation: bool = False):
        """Décorateur pour enregistrer un tool."""
        def decorator(func: Callable):
            self._tools[name] = func
            self._metadata[name] = {
                "name": name,
                "description": description,
                "requires_confirmation": requires_confirmation,
                "function": func
            }
            logger.info(f"Tool enregistré: {name} (Confirmation: {requires_confirmation})")
            return func
        return decorator

    def get_tool(self, name: str) -> Callable:
        return self._tools.get(name)

    def list_tools(self) -> List[dict]:
        return list(self._metadata.values())

# Instance globale
tool_registry = SikaToolRegistry()
