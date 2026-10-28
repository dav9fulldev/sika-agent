"""Assistant vocal Gemini Live : session simulée, aucun appel réseau."""
import asyncio
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services import sika_voice_live
from app.services.auth_service import oauth2_auth_service

client = TestClient(app)
URL = "/api/v1/sika/voice/live"


def _token(user_id: int) -> str:
    return oauth2_auth_service.create_access_token({"user_id": user_id, "email": f"voice{user_id}@sika.test"})


def tool_call(name, args, call_id="c1"):
    return SimpleNamespace(tool_call=SimpleNamespace(function_calls=[SimpleNamespace(id=call_id, name=name, args=args)]),
                           server_content=None)


def content(audio=None, said=None, heard=None, done=False, interrupted=False):
    turn = SimpleNamespace(parts=[SimpleNamespace(inline_data=SimpleNamespace(data=audio))]) if audio else None
    return SimpleNamespace(tool_call=None, server_content=SimpleNamespace(
        model_turn=turn,
        input_transcription=SimpleNamespace(text=heard) if heard else None,
        output_transcription=SimpleNamespace(text=said) if said else None,
        interrupted=interrupted, turn_complete=done))


class FakeLiveSession:
    """Session Gemini Live simulée : rejoue des tours scriptés et enregistre ce que SIKA lui envoie."""

    def __init__(self, turns):
        self.turns = list(turns)
        self.audio_in = []
        self.tool_responses = []
        self.config = None

    def connect(self, config):
        self.config = config
        return self

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def send_realtime_input(self, audio):
        self.audio_in.append(audio.data)

    async def send_client_content(self, turns, turn_complete):
        pass

    async def send_tool_response(self, function_responses):
        self.tool_responses.extend(function_responses)

    async def receive(self):
        if not self.turns:
            await asyncio.sleep(3600)
        for msg in self.turns.pop(0):
            yield msg


def _collect(ws, until="turn_complete", limit=40):
    events, audio = [], b""
    for _ in range(limit):
        msg = ws.receive()
        if msg.get("bytes"):
            audio += msg["bytes"]
            continue
        import json
        event = json.loads(msg["text"])
        events.append(event)
        if event["type"] == until:
            break
    return events, audio


def test_voice_requires_a_valid_token_in_first_message():
    with client.websocket_connect(URL) as ws:
        ws.send_json({"type": "start", "token": "not-a-token"})
        assert ws.receive_json()["code"] == "AUTH_REQUIRED"


def test_voice_turn_runs_tool_streams_audio_and_transcripts(monkeypatch):
    fake = FakeLiveSession([
        [content(heard="Find me an Excel course"), tool_call("search_demo_catalog", {"query": "excel course"})],
        [content(audio=b"\x01\x02" * 50, said="I found Excel for Small Business."), content(done=True)],
    ])
    monkeypatch.setattr(sika_voice_live, "default_live_connect", fake.connect)
    with client.websocket_connect(URL) as ws:
        ws.send_json({"type": "start", "token": _token(501), "lang": "en", "firstname": "Ada"})
        assert ws.receive_json()["type"] == "ready"
        ws.send_bytes(b"\x00\x00" * 160)
        events, audio = _collect(ws)
        ws.send_json({"type": "stop"})

    kinds = [e["type"] for e in events]
    assert kinds[0] == "input_transcript"
    steps = [e for e in events if e["type"] == "step"]
    assert [s["status"] for s in steps] == ["active", "completed"]
    assert any(e["type"] == "output_transcript" for e in events) and kinds[-1] == "turn_complete"
    assert audio == b"\x01\x02" * 50
    # Le résultat du tool revient au modèle, et la voix est bien relayée vers Gemini
    assert fake.tool_responses[0].name == "search_demo_catalog" and fake.tool_responses[0].response["success"]
    assert fake.audio_in == [b"\x00\x00" * 160]
    # Même consignes que le chat, plus les règles de la voix
    assert "SIKA Pay" in fake.config.system_instruction and "VOICE MODE" in fake.config.system_instruction


def test_voice_cannot_use_authorization_tool_without_mandate(monkeypatch):
    fake = FakeLiveSession([
        [tool_call("confirm_checkout_with_authorization", {"checkout_id": "chk_x"})],
        [content(said="You need to confirm in the app.", done=True)],
    ])
    monkeypatch.setattr(sika_voice_live, "default_live_connect", fake.connect)
    with client.websocket_connect(URL) as ws:
        ws.send_json({"type": "start", "token": _token(502), "lang": "fr"})
        ws.receive_json()
        events, _ = _collect(ws)
        ws.send_json({"type": "stop"})

    declared = {f.name for t in fake.config.tools for f in t.function_declarations}
    assert "confirm_checkout_with_authorization" not in declared
    assert [e["status"] for e in events if e["type"] == "step"][-1] == "failed"
    assert not any(e["type"] == "card" for e in events)
    assert fake.tool_responses[0].response["success"] is False


def test_voice_tools_always_use_the_authenticated_user(monkeypatch):
    seen = {}

    def spy(name, args, allowed, user_id, user_message):
        seen.update(name=name, user_id=user_id, user_message=user_message)
        return {"success": True, "data": {}}, "completed"

    fake = FakeLiveSession([
        [content(heard="What did I buy?"), tool_call("list_recent_paypal_checkouts", {"user_id": "999"})],
        [content(done=True)],
    ])
    monkeypatch.setattr(sika_voice_live, "default_live_connect", fake.connect)
    from app.services.sika_ai import SikaAIService
    real = SikaAIService.run_agent_tool

    def checked(name, args, allowed, user_id, user_message):
        spy(name, args, allowed, user_id, user_message)
        return real(name, args, allowed, user_id, user_message)

    monkeypatch.setattr(SikaAIService, "run_agent_tool", staticmethod(checked))
    with client.websocket_connect(URL) as ws:
        ws.send_json({"type": "start", "token": _token(503), "lang": "en"})
        ws.receive_json()
        _collect(ws)
        ws.send_json({"type": "stop"})
    assert seen == {"name": "list_recent_paypal_checkouts", "user_id": "503", "user_message": "What did I buy?"}


def test_live_session_failure_reports_unavailable(monkeypatch):
    def broken(config):
        raise RuntimeError("upstream down")

    monkeypatch.setattr(sika_voice_live, "default_live_connect", broken)
    with client.websocket_connect(URL) as ws:
        ws.send_json({"type": "start", "token": _token(504), "lang": "en"})
        assert ws.receive_json()["code"] == "VOICE_UNAVAILABLE"


@pytest.mark.parametrize("name,data,kind", [
    ("prepare_paypal_checkout", {"action_id": "chk_1", "checkout": {"checkout_id": "chk_1"}}, "paypal_checkout"),
    ("prepare_subscription", {"action_id": "sub_1", "subscription": {}}, "paypal_subscription"),
    ("search_web_products", {"products": [{"id": "p"}]}, "web_offers"),
])
def test_cards_match_the_chat(name, data, kind):
    from app.services.sika_ai import SikaAIService
    assert SikaAIService.card_for_tool(name, {"success": True, "data": data})["type"] == kind
    assert SikaAIService.card_for_tool(name, {"success": False}) is None
