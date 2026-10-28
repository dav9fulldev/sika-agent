"""
Accès au PayPal Agent Toolkit officiel (paypal/agent-toolkit, Apache-2.0), en lecture seule.

SIKA n'expose pas les outils du toolkit tels quels au modèle : ils agissent au nom du marchand (toutes les
transactions de tous les clients). On n'utilise ici que `list_transactions`, appelé par le serveur, et les
résultats sont filtrés sur les seuls paiements de l'utilisateur avant d'atteindre l'IA.
Le cœur du toolkit (`shared.api.PayPalAPI`) n'a besoin que de pydantic, requests et httpx : il est installé
sans ses intégrations CrewAI / LangChain / OpenAI.
"""

import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from ...config import settings

logger = logging.getLogger("SikaPayPalToolkit")


class ToolkitUnavailable(Exception):
    pass


class PayPalAgentToolkit:
    def __init__(self):
        self._api = None

    def _client(self):
        if self._api is None:
            if not (settings.PAYPAL_CLIENT_ID and settings.PAYPAL_CLIENT_SECRET):
                raise ToolkitUnavailable("PayPal credentials are not configured.")
            try:
                from paypal_agent_toolkit.shared.api import PayPalAPI
                from paypal_agent_toolkit.shared.configuration import Context
            except ImportError as e:
                raise ToolkitUnavailable("paypal-agent-toolkit is not installed.") from e
            # Sandbox uniquement, comme tout SIKA Pay
            self._api = PayPalAPI(client_id=settings.PAYPAL_CLIENT_ID, secret=settings.PAYPAL_CLIENT_SECRET,
                                  context=Context(sandbox=True))
        return self._api

    def list_transaction_ids(self, start: datetime, end: datetime) -> List[str]:
        """Identifiants des transactions du marchand sur la période (PayPal Transaction Search, via le toolkit)."""
        params = {"start_date": _iso(start), "end_date": _iso(end), "page_size": 500}
        try:
            raw = self._client().run("list_transactions", params)
        except ToolkitUnavailable:
            raise
        except Exception as e:
            logger.warning(f"[PAYPAL TOOLKIT] list_transactions failed: {type(e).__name__}")
            raise ToolkitUnavailable("PayPal transaction reports could not be read.") from e
        data: Dict[str, Any] = json.loads(raw) if isinstance(raw, str) else (raw or {})
        ids = []
        for item in data.get("transaction_details") or []:
            tid = ((item or {}).get("transaction_info") or {}).get("transaction_id")
            if tid:
                ids.append(str(tid))
        return ids


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


paypal_agent_toolkit: Optional[PayPalAgentToolkit] = PayPalAgentToolkit()
