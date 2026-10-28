"""
Assistant vocal SIKA en langage naturel : pont entre l'app et Gemini Live (audio natif, speech-to-speech).

L'app envoie le micro en PCM 16 kHz et reçoit la voix de SIKA en PCM 24 kHz. Les tools passent par le même
ToolRegistry que le chat (`SikaAIService.run_agent_tool`) : user_id injecté côté serveur, tools d'autorisation
masqués sans mandat actif, aucun tool ne paie. Les cartes (achat, abonnement, offres) sont envoyées à l'app,
qui garde sa propre confirmation.

Protocole WebSocket (JSON en texte, audio en binaire) :
  app -> serveur : {"type": "start", "token", "lang", "firstname"} puis audio PCM16 16 kHz mono,
                   {"type": "text", "text"} (saisie), {"type": "stop"}
  serveur -> app : {"type": "ready"}, audio PCM16 24 kHz mono, {"type": "input_transcript", "text"},
                   {"type": "output_transcript", "text"}, {"type": "step", "id", "label", "status"},
                   {"type": "card", "card"}, {"type": "interrupted"}, {"type": "turn_complete"},
                   {"type": "error", "code", "message"}
"""
import asyncio
import json
import logging
import os
import time
from typing import Any, Callable, Dict, Optional

logger = logging.getLogger(__name__)

INPUT_MIME = "audio/pcm;rate=16000"
MAX_SESSION_SECONDS = 10 * 60
MAX_AUDIO_CHUNK = 64 * 1024
VOICE_EXCLUDED_TOOLS = {"get_user_habits"}

VOICE_RULES = """
VOICE MODE: you are talking out loud with the user in real time.
- Speak naturally, like a helpful person on the phone: one to three short sentences, then let the user answer.
- Never read out IDs, order numbers, SKUs, URLs or long codes. Say prices naturally ("forty-nine dollars").
- When a tool result is shown on screen (purchase, subscription, offers), say so briefly: the user reviews it on the card.
- If the user interrupts you, stop and listen.
- Greetings and small talk ("hello", "how are you"): answer warmly in one sentence, without calling any tool.
- Only act on a clear sentence addressed to you. Background voices (TV, video, other people), noise, a single unclear
  word or cut-off speech are NOT requests: ask the user to repeat, and never call a tool. Never guess what they want.
"""


def _live_settings() -> Dict[str, str]:
    api_key = os.getenv("GEMINI_API_KEY")
    return {
        "api_key": api_key or "",
        "project": os.getenv("GOOGLE_CLOUD_PROJECT", "sika-all-things-agentic"),
        # Gemini Live n'est pas servi en « global » : région dédiée
        "location": os.getenv("VOICE_LIVE_LOCATION", "us-central1"),
        "model": os.getenv("VOICE_LIVE_MODEL") or (
            "gemini-2.5-flash-native-audio-preview-09-2025" if api_key else "gemini-live-2.5-flash-native-audio"),
        "voice": os.getenv("VOICE_LIVE_VOICE", "Aoede"),
    }


def default_live_connect(config: Any):
    """Ouvre une session Gemini Live (context manager asynchrone)."""
    from google import genai
    s = _live_settings()
    client = (genai.Client(api_key=s["api_key"]) if s["api_key"]
              else genai.Client(vertexai=True, project=s["project"], location=s["location"]))
    return client.aio.live.connect(model=s["model"], config=config)


class VoiceLiveBridge:
    """Une conversation vocale : relaie l'audio et exécute les tools SIKA demandés par Gemini Live."""

    def __init__(self, user_id: str, firstname: str, lang: str,
                 live_connect: Optional[Callable[[Any], Any]] = None):
        self.user_id = str(user_id)
        self.firstname = firstname or "there"
        self.is_english = lang != "fr"
        self.live_connect = live_connect or default_live_connect
        self.user_utterance = ""
        self.model_utterance = ""
        self.step_count = 0

    def build_config(self):
        from google.genai import types
        from ..agent.tool_registry import tool_registry
        from ..agent.tools import AUTHORIZATION_ONLY_TOOLS
        from .agent_mandate_service import agent_mandate_service
        from .sika_ai import sika_ai_service

        mandate = None
        if self.user_id.isdigit():
            try:
                mandate = agent_mandate_service.get(int(self.user_id))
            except Exception as e:  # base indisponible : on reste en mode « l'utilisateur confirme »
                logger.warning(f"[SIKA VOICE] Authorization lookup failed: {type(e).__name__}")
        excluded = set() if (mandate and mandate.get("active")) else set(AUTHORIZATION_ONLY_TOOLS)
        # Le profil d'habitudes n'apporte rien à l'oral et retarde la réponse (appelé dès « bonjour »)
        excluded |= VOICE_EXCLUDED_TOOLS
        self.allowed_tool_names = set(tool_registry.agent_tool_names(excluded))

        app_lang = "English" if self.is_english else "French"
        lang_instruction = (f"Speak ONLY French or English, never any other language. Reply in French if the user speaks "
                            f"French, in English if they speak English. If the speech is unclear or sounds like another "
                            f"language, reply in {app_lang} (the language of the app) and ask the user to repeat.")
        instruction = sika_ai_service._sika_pay_instruction(self.firstname, lang_instruction, mandate) + VOICE_RULES
        s = _live_settings()
        return types.LiveConnectConfig(
            response_modalities=["AUDIO"],
            system_instruction=instruction,
            tools=tool_registry.get_gemini_tools(excluded),
            input_audio_transcription={},
            output_audio_transcription={},
            speech_config=types.SpeechConfig(voice_config=types.VoiceConfig(
                prebuilt_voice_config=types.PrebuiltVoiceConfig(voice_name=s["voice"]))),
            # Laisse l'utilisateur réfléchir : la fin de parole n'est détectée qu'après un vrai silence
            realtime_input_config=types.RealtimeInputConfig(automatic_activity_detection=types.AutomaticActivityDetection(
                # Seule une voix nette déclenche un tour : télévision, musique ou bruit de fond sont ignorés
                start_of_speech_sensitivity=types.StartSensitivity.START_SENSITIVITY_LOW,
                end_of_speech_sensitivity=types.EndSensitivity.END_SENSITIVITY_LOW,
                prefix_padding_ms=300,
                silence_duration_ms=900,
            )),
        )

    async def run(self, ws) -> None:
        """Relaie la conversation jusqu'à `stop`, la déconnexion de l'app ou la durée maximale."""
        try:
            config = self.build_config()
            async with self.live_connect(config) as session:
                await ws.send_json({"type": "ready"})
                upstream = asyncio.create_task(self._from_app(ws, session))
                downstream = asyncio.create_task(self._from_model(ws, session))
                done, pending = await asyncio.wait({upstream, downstream}, timeout=MAX_SESSION_SECONDS,
                                                   return_when=asyncio.FIRST_COMPLETED)
                for task in pending:
                    task.cancel()
                for task in done:
                    if task.exception():
                        raise task.exception()
        except Exception as e:
            logger.error(f"[SIKA VOICE] Live session failed: {type(e).__name__}: {e}")
            await self._safe_send(ws, {"type": "error", "code": "VOICE_UNAVAILABLE",
                                       "message": "Voice assistant unavailable. Try again or type your request."})

    async def _from_app(self, ws, session) -> None:
        from google.genai import types
        while True:
            msg = await ws.receive()
            if msg.get("type") == "websocket.disconnect":
                return
            if msg.get("bytes"):
                chunk = msg["bytes"][:MAX_AUDIO_CHUNK]
                await session.send_realtime_input(audio=types.Blob(data=chunk, mime_type=INPUT_MIME))
            elif msg.get("text"):
                try:
                    data = json.loads(msg["text"])
                except ValueError:
                    continue
                if data.get("type") == "stop":
                    return
                if data.get("type") == "text" and str(data.get("text", "")).strip():
                    text = str(data["text"]).strip()[:1000]
                    self.user_utterance = text
                    await session.send_client_content(
                        turns=types.Content(role="user", parts=[types.Part(text=text)]), turn_complete=True)

    async def _from_model(self, ws, session) -> None:
        # `receive()` s'arrête à chaque fin de tour : on le relance pour toute la conversation
        while True:
            async for msg in session.receive():
                await self._handle_model_message(ws, session, msg)

    async def _handle_model_message(self, ws, session, msg) -> None:
        if getattr(msg, "tool_call", None):
            await self._run_tools(ws, session, msg.tool_call.function_calls or [])
        sc = getattr(msg, "server_content", None)
        if not sc:
            return
        if sc.model_turn:
            for part in sc.model_turn.parts or []:
                if part.inline_data and part.inline_data.data:
                    await ws.send_bytes(part.inline_data.data)
        if sc.input_transcription and sc.input_transcription.text:
            self.user_utterance += sc.input_transcription.text
            await ws.send_json({"type": "input_transcript", "text": sc.input_transcription.text})
        if sc.output_transcription and sc.output_transcription.text:
            self.model_utterance += sc.output_transcription.text
            await ws.send_json({"type": "output_transcript", "text": sc.output_transcription.text})
        if sc.interrupted:
            await ws.send_json({"type": "interrupted"})
        if sc.turn_complete:
            self._save_history()
            await ws.send_json({"type": "turn_complete"})

    async def _run_tools(self, ws, session, calls) -> None:
        from google.genai import types
        from .sika_ai import SikaAIService

        responses = []
        for call in calls:
            self.step_count += 1
            step = {"type": "step", "id": f"step_{self.step_count}", "tool": call.name,
                    "label": SikaAIService.tool_label(call.name, self.is_english)}
            await ws.send_json({**step, "status": "active"})
            logger.info(f"[SIKA VOICE] Gemini Live is calling tool: {call.name}")
            # Les tools sont synchrones (base, PayPal, Channel3) : hors de la boucle asyncio
            res_dict, status = await asyncio.to_thread(
                SikaAIService.run_agent_tool, call.name, call.args, self.allowed_tool_names,
                self.user_id, self.user_utterance.strip())
            await ws.send_json({**step, "status": status})
            card = SikaAIService.card_for_tool(call.name, res_dict)
            if card:
                await ws.send_json({"type": "card", "card": card})
            responses.append(types.FunctionResponse(id=call.id, name=call.name, response=res_dict))
        await session.send_tool_response(function_responses=responses)

    def _save_history(self) -> None:
        """Le chat écrit garde le fil de la conversation vocale."""
        user_text, model_text = self.user_utterance.strip(), self.model_utterance.strip()
        self.user_utterance = self.model_utterance = ""
        if os.getenv("VOICE_DEBUG_TRANSCRIPTS") == "1":  # diagnostic local uniquement : jamais en production
            logger.info(f"[SIKA VOICE] heard={user_text!r} said={model_text!r}")
        if not user_text and not model_text:
            return
        try:
            from ..agent.session_manager import sika_session_manager
            session = sika_session_manager.get_user_session(self.user_id)
            history = session.get("history", [])
            if user_text:
                history.append({"role": "user", "content": user_text})
            if model_text:
                history.append({"role": "model", "content": model_text})
            session["history"] = history[-10:]
            sika_session_manager.save_user_session(self.user_id, session)
        except Exception as e:
            logger.warning(f"[SIKA VOICE] History not saved: {type(e).__name__}")

    @staticmethod
    async def _safe_send(ws, payload: Dict[str, Any]) -> None:
        try:
            await ws.send_json(payload)
        except Exception:
            pass


async def handle_voice_socket(ws, live_connect: Optional[Callable[[Any], Any]] = None) -> None:
    """Authentifie la connexion (premier message `start`, jamais de jeton dans l'URL) puis lance le pont."""
    from fastapi import HTTPException
    from .auth_service import oauth2_auth_service
    from .security_rate_limiter import security_rate_limiter

    await ws.accept()
    try:
        start = await asyncio.wait_for(ws.receive_json(), timeout=10)
    except Exception:
        await ws.close(code=4400)
        return
    payload = oauth2_auth_service.verify_token(str(start.get("token") or "")) if start.get("type") == "start" else None
    if not payload or "user_id" not in payload:
        await VoiceLiveBridge._safe_send(ws, {"type": "error", "code": "AUTH_REQUIRED", "message": "Sign in again."})
        await ws.close(code=4401)
        return
    user_id = str(payload["user_id"])
    try:
        security_rate_limiter.check_ai_rate_limit(f"voice_{user_id}", max_requests=10)
    except HTTPException:
        await VoiceLiveBridge._safe_send(ws, {"type": "error", "code": "RATE_LIMITED",
                                              "message": "Too many voice sessions. Wait a moment."})
        await ws.close(code=4429)
        return

    started = time.time()
    firstname = str(start.get("firstname") or "")[:40]
    lang = "fr" if start.get("lang") == "fr" else "en"
    await VoiceLiveBridge(user_id, firstname, lang, live_connect).run(ws)
    logger.info(f"[SIKA VOICE] Session ended after {round(time.time() - started)} s")
    try:
        await ws.close()
    except Exception:
        pass
