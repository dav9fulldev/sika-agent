"""
Client du serveur MCP officiel de PayPal (Model Context Protocol, transport SSE).

SIKA appelle les outils PayPal (abonnements : produits, plans, souscription, détails, résiliation)
via le serveur MCP distant de PayPal, en mode sandbox, avec le jeton OAuth2 de l'application SIKA.
Ces appels sont faits par le backend, jamais par le modèle IA : le modèle n'a accès qu'aux tools SIKA,
qui appliquent les confirmations et les contrôles avant d'appeler ce client.

Une session SSE courte est ouverte par appel (initialize → tools/call → fermeture).
"""

import json
import logging
import queue
import threading
from typing import Any, Dict, Optional
from urllib.parse import urljoin

import requests

from ...config import settings
from .paypal_api_service import paypal_api_service, PayPalConfigurationError

logger = logging.getLogger("SikaPayPalMCP")

MCP_SANDBOX_BASE = "https://mcp.sandbox.paypal.com"
PROTOCOL_VERSION = "2024-11-05"


class PayPalMCPError(Exception):
    def __init__(self, message: str, tool: str = "", retryable: bool = False):
        self.tool = tool
        self.retryable = retryable
        super().__init__(message)


class PayPalMCPClient:
    def __init__(self, base_url: str = MCP_SANDBOX_BASE, timeout: float = 40.0):
        if "sandbox" not in base_url:
            raise ValueError("SIKA Pay only talks to the PayPal SANDBOX MCP server.")
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def call_tool(self, name: str, arguments: Optional[Dict[str, Any]] = None, attempts: int = 3) -> Any:
        """Appelle un outil MCP PayPal (avec nouvelles tentatives sur les erreurs passagères du serveur MCP)."""
        for attempt in range(1, attempts + 1):
            try:
                return self._call_once(name, arguments)
            except PayPalMCPError as e:
                if not e.retryable or attempt == attempts:
                    raise
                logger.info(f"[PayPal MCP] {name}: transient error, retry {attempt}/{attempts - 1}")

    def _call_once(self, name: str, arguments: Optional[Dict[str, Any]] = None) -> Any:
        if not settings.paypal_configured:
            raise PayPalConfigurationError("PayPal sandbox credentials are not configured.")
        token = paypal_api_service._get_access_token()
        headers = {"Authorization": f"Bearer {token}"}
        events: "queue.Queue[str]" = queue.Queue()
        try:
            stream = requests.get(f"{self.base_url}/sse", headers={**headers, "Accept": "text/event-stream"},
                                  stream=True, timeout=self.timeout)
        except requests.exceptions.RequestException as e:
            raise PayPalMCPError(f"PayPal MCP server unreachable ({type(e).__name__}).", name, retryable=True)
        if stream.status_code != 200:
            stream.close()
            raise PayPalMCPError(f"PayPal MCP server refused the session (HTTP {stream.status_code}).", name,
                                 retryable=stream.status_code >= 500)

        def reader():
            try:
                for line in stream.iter_lines(decode_unicode=True):
                    if line and line.startswith("data:"):
                        events.put(line[5:].strip())
            except Exception:  # fermeture du flux à la fin de l'appel
                pass

        threading.Thread(target=reader, daemon=True).start()
        try:
            endpoint = urljoin(self.base_url + "/", events.get(timeout=self.timeout))

            def send(body: Dict[str, Any]):
                resp = requests.post(endpoint, json=body, headers={**headers, "Content-Type": "application/json"},
                                     timeout=self.timeout)
                if resp.status_code >= 400:
                    raise PayPalMCPError(f"PayPal MCP request rejected (HTTP {resp.status_code}).", name,
                                         retryable=resp.status_code >= 500)

            def wait_for(msg_id: int) -> Dict[str, Any]:
                while True:
                    raw = events.get(timeout=self.timeout)
                    try:
                        msg = json.loads(raw)
                    except ValueError:
                        continue
                    if msg.get("id") == msg_id:
                        return msg

            send({"jsonrpc": "2.0", "id": 1, "method": "initialize",
                  "params": {"protocolVersion": PROTOCOL_VERSION, "capabilities": {},
                             "clientInfo": {"name": "sika-pay", "version": "1"}}})
            wait_for(1)
            send({"jsonrpc": "2.0", "method": "notifications/initialized"})
            send({"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": name, "arguments": arguments or {}}})
            msg = wait_for(2)
        except queue.Empty:
            raise PayPalMCPError("PayPal MCP server did not answer in time.", name, retryable=True)
        finally:
            stream.close()

        if msg.get("error"):
            raise PayPalMCPError(str(msg["error"].get("message") or "PayPal MCP error"), name)
        result = msg.get("result") or {}
        text = "\n".join(c.get("text", "") for c in result.get("content") or [] if c.get("type") == "text").strip()
        if result.get("isError"):
            logger.warning(f"[PayPal MCP] {name} returned an error")
            raise PayPalMCPError(text[:300] or "PayPal returned an error.", name)
        try:
            return json.loads(text) if text else {}
        except ValueError:
            return {"text": text}


paypal_mcp_client = PayPalMCPClient()
