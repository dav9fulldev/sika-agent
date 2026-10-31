"""
SIKA Pay — Pont entre les agents d'AG Studio et Gemini (Vertex AI).

Le tableau de bord web utilise le Studio Agent Framework d'AG Studio. Son adaptateur (dans le navigateur)
envoie chaque tour au format AgLlmRequest ; ce module le traduit pour Gemini, appelle le modèle côté serveur
(identifiants Google du service Cloud Run, jamais dans le navigateur) et renvoie un AgLlmResponse.

Les outils d'AG Studio (lire le schéma, interroger les données, placer et configurer des widgets) sont exécutés
dans le navigateur par Studio, sur les données de l'utilisateur déjà chargées : le modèle n'a aucun outil de paiement.
"""

import base64
import json
import logging
import time
import uuid
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("SikaDashboardLLM")

MAX_INPUT_ITEMS = 400
MAX_TOOLS = 80
MAX_OUTPUT_TOKENS = 8192
# Valeur documentée par Google pour un appel de fonction dont la signature de raisonnement n'a pas été conservée
SKIP_SIGNATURE = b"skip_thought_signature_validator"
SIGNATURE_PREFIX = "sig_"

GUARDRAILS = (
    "You are working inside SIKA Pay, a personal finance dashboard built on the PayPal sandbox. "
    "The data is the signed-in user's own: payments made through SIKA, products SIKA follows for them, "
    "price changes, subscriptions and the spending authorization they granted. "
    "Read-only rules: you can explore the data and arrange the dashboard, but you cannot pay, refund, "
    "change limits or contact merchants, and you must never claim to. "
    "Never invent amounts, merchants or statuses: answer from query results only. "
    "Amounts are in the currency of each row (usually USD). Reply in the language the user writes in.\n\n"
)


def _text_of(content: List[Dict[str, Any]]) -> str:
    return "\n".join(str(c.get("text") or "") for c in content or [] if c.get("type") == "text").strip()


def _signature_from_id(item_id: str) -> bytes:
    if item_id and item_id.startswith(SIGNATURE_PREFIX):
        try:
            return base64.urlsafe_b64decode(item_id[len(SIGNATURE_PREFIX):].encode())
        except (ValueError, TypeError):
            pass
    return SKIP_SIGNATURE


def _parse_output(raw: str) -> Dict[str, Any]:
    try:
        value = json.loads(raw)
    except (TypeError, ValueError):
        return {"output": raw}
    return value if isinstance(value, dict) else {"output": value}


def to_gemini_contents(items: List[Dict[str, Any]]) -> list:
    """Historique AG Studio → contenus Gemini (tours consécutifs du même rôle regroupés)."""
    from google.genai import types

    call_names: Dict[str, str] = {}
    contents: List[Any] = []

    def push(role: str, part) -> None:
        if contents and contents[-1].role == role:
            contents[-1].parts.append(part)
        else:
            contents.append(types.Content(role=role, parts=[part]))

    for item in items:
        kind = item.get("type")
        if kind == "message":
            text = _text_of(item.get("content") or [])
            if not text:
                continue
            push("model" if item.get("role") == "assistant" else "user", types.Part(text=text))
        elif kind == "function_call":
            name = str(item.get("name") or "")
            call_names[str(item.get("callId"))] = name
            try:
                args = json.loads(item.get("arguments") or "{}")
            except ValueError:
                args = {}
            push("model", types.Part(function_call=types.FunctionCall(name=name, args=args if isinstance(args, dict) else {}),
                                     thought_signature=_signature_from_id(str(item.get("id") or ""))))
        elif kind == "function_call_output":
            call_id = str(item.get("callId"))
            push("user", types.Part(function_response=types.FunctionResponse(
                name=call_names.get(call_id, "tool"), response=_parse_output(item.get("output")))))
        # Les éléments de raisonnement ne sont pas renvoyés au modèle
    return contents


def to_gemini_config(request: Dict[str, Any]):
    from google.genai import types

    declarations = []
    for tool in request.get("tools") or []:
        if tool.get("kind") == "provided":
            continue  # outils hébergés par un autre fournisseur : sans équivalent Gemini
        declarations.append(types.FunctionDeclaration(
            name=tool["name"], description=tool.get("description") or "",
            parameters_json_schema=tool.get("parameters") or {"type": "object", "properties": {}}))

    config: Dict[str, Any] = {
        "system_instruction": GUARDRAILS + str(request.get("instructions") or ""),
        "max_output_tokens": MAX_OUTPUT_TOKENS,
    }
    if declarations:
        config["tools"] = [types.Tool(function_declarations=declarations)]
        choice = request.get("toolChoice") or "auto"
        if isinstance(choice, dict):
            mode, allowed = "ANY", [choice.get("name")]
        else:
            mode, allowed = {"none": "NONE", "required": "ANY"}.get(choice, "AUTO"), None
        config["tool_config"] = types.ToolConfig(function_calling_config=types.FunctionCallingConfig(
            mode=mode, allowed_function_names=allowed))
        config["automatic_function_calling"] = types.AutomaticFunctionCallingConfig(disable=True)
    fmt = request.get("responseFormat") or {}
    if fmt.get("type") == "json" and fmt.get("schema"):
        config["response_mime_type"] = "application/json"
        config["response_json_schema"] = fmt["schema"]
    return types.GenerateContentConfig(**config)


def from_gemini_response(response, model: str) -> Dict[str, Any]:
    """Réponse Gemini → AgLlmResponse (messages et appels d'outils)."""
    output: List[Dict[str, Any]] = []
    text_parts: List[str] = []
    candidates = getattr(response, "candidates", None) or []
    parts = (candidates[0].content.parts if candidates and candidates[0].content else None) or []
    for part in parts:
        if getattr(part, "function_call", None):
            call = part.function_call
            signature = getattr(part, "thought_signature", None)
            item_id = (SIGNATURE_PREFIX + base64.urlsafe_b64encode(signature).decode()) if signature else f"fc_{uuid.uuid4().hex}"
            output.append({
                "id": item_id, "kind": "output", "type": "function_call",
                "callId": f"call_{uuid.uuid4().hex[:24]}", "name": call.name,
                "arguments": json.dumps(dict(call.args or {})), "status": "completed",
            })
        elif getattr(part, "text", None) and not getattr(part, "thought", False):
            text_parts.append(part.text)
    if text_parts:
        output.insert(0, {
            "id": f"msg_{uuid.uuid4().hex}", "kind": "output", "type": "message", "role": "assistant",
            "status": "completed", "content": [{"type": "text", "text": "".join(text_parts), "annotations": []}],
        })
    usage = getattr(response, "usage_metadata", None)
    finish = str(getattr(candidates[0], "finish_reason", "") or "") if candidates else ""
    result: Dict[str, Any] = {
        "id": f"resp_{uuid.uuid4().hex}",
        "createdAt": int(time.time() * 1000),
        "status": "incomplete" if "MAX_TOKENS" in finish else "completed",
        "output": output,
        "model": model,
    }
    if "MAX_TOKENS" in finish:
        result["incompleteDetails"] = {"reason": "max_output_tokens"}
    if usage:
        result["usage"] = {
            "inputTokens": int(getattr(usage, "prompt_token_count", 0) or 0),
            "outputTokens": int(getattr(usage, "candidates_token_count", 0) or 0),
            "totalTokens": int(getattr(usage, "total_token_count", 0) or 0),
        }
    return result


def failed(code: str, message: str) -> Dict[str, Any]:
    return {"id": f"resp_{uuid.uuid4().hex}", "createdAt": int(time.time() * 1000), "status": "failed",
            "output": [], "error": {"code": code, "message": message}}


def validate(request: Dict[str, Any]) -> Optional[Tuple[str, str]]:
    if not isinstance(request.get("input"), list) or len(request["input"]) > MAX_INPUT_ITEMS:
        return ("INVALID_REQUEST", "The conversation is too long. Start a new one.")
    if len(request.get("tools") or []) > MAX_TOOLS:
        return ("INVALID_REQUEST", "Too many tools in one turn.")
    return None


async def execute_turn(request: Dict[str, Any]) -> Dict[str, Any]:
    from .sika_ai import sika_ai_service

    problem = validate(request)
    if problem:
        return failed(*problem)
    if not getattr(sika_ai_service, "client", None):
        return failed("AI_UNAVAILABLE", "The AI assistant is not configured on the SIKA backend.")
    model = sika_ai_service.model
    try:
        response = await sika_ai_service._generate(
            model=model, contents=to_gemini_contents(request["input"]), config=to_gemini_config(request))
    except Exception as e:
        logger.warning(f"[DASHBOARD AI] Gemini turn failed: {type(e).__name__}")
        return failed("AI_ERROR", "The AI assistant could not answer. Try again.")
    return from_gemini_response(response, model)
