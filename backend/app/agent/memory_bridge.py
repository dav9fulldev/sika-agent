"""
Bridge Mémoire (Session Court Terme & Contexte Long Terme)

Gère le stockage des événements financiers perçus et du contexte d'état de l'agent.
"""

from typing import Dict, Any, Optional
import logging

logger = logging.getLogger("SikaMemoryBridge")

class MemoryBridge:
    """Interface d'accès à la mémoire court terme et au contexte observé."""

    def __init__(self):
        # En-mémoire pour le développement local / fallback
        self._sessions: Dict[str, dict] = {}
        self._financial_context: Dict[int, dict] = {}

    def get_session(self, session_id: str) -> dict:
        return self._sessions.get(session_id, {"state": "IDLE", "history": []})

    def save_session(self, session_id: str, data: dict):
        self._sessions[session_id] = data

    def update_financial_context(self, user_id: int, context_update: dict):
        if user_id not in self._financial_context:
            self._financial_context[user_id] = {"wallets": {}, "events": [], "goals": []}
        self._financial_context[user_id].update(context_update)
        logger.info(f"Contexte financier mis à jour pour user_id={user_id}")

    def get_financial_context(self, user_id: int) -> dict:
        return self._financial_context.get(user_id, {"wallets": {}, "events": [], "goals": []})

# Instance globale
memory_bridge = MemoryBridge()
