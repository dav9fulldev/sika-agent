"""Tableau de bord web : connexion par code à usage unique, jeton limité, données et pont AG Studio ↔ Gemini."""

import json
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.dashboard_login_code import DashboardLoginCodeModel
from app.models.price_watch import PriceWatchModel, UserNotificationModel
from app.models.user import UserModel
from app.services import dashboard_llm
from app.services.auth_service import oauth2_auth_service
from app.services.dashboard_service import dashboard_service

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup():
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        for model in (DashboardLoginCodeModel, UserNotificationModel, PriceWatchModel):
            db.query(model).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"dash{uid}@sika.test", full_name=f"Jane Doe{uid}"))
        db.commit()
    dashboard_service._failures.clear()


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"dash{uid}@sika.test"})}


def _session(uid=1):
    code = client.post("/api/v1/dashboard/code", headers=_auth(uid)).json()["code"]
    r = client.post("/api/v1/dashboard/session", json={"code": code})
    assert r.status_code == 200, r.text
    return {"Authorization": "Bearer " + r.json()["access_token"]}, code


def test_code_is_single_use_and_needs_a_signed_in_user():
    assert client.post("/api/v1/dashboard/code").status_code == 401
    r = client.post("/api/v1/dashboard/code", headers=_auth())
    body = r.json()
    assert r.status_code == 200 and len(body["code"]) == 9 and body["code"][4] == "-" and body["expires_in"] == 600
    assert body["url"].endswith("/dashboard/")
    # Saisie tolérante : minuscules, sans tiret
    ok = client.post("/api/v1/dashboard/session", json={"code": body["code"].replace("-", " ").lower()})
    assert ok.status_code == 200 and ok.json()["expires_in"] == 7200
    again = client.post("/api/v1/dashboard/session", json={"code": body["code"]})
    assert again.status_code == 400 and again.json()["detail"]["error_code"] == "INVALID_CODE"


def test_expired_code_and_a_new_code_replaces_the_old_one():
    first = client.post("/api/v1/dashboard/code", headers=_auth()).json()["code"]
    second = client.post("/api/v1/dashboard/code", headers=_auth()).json()["code"]
    assert client.post("/api/v1/dashboard/session", json={"code": first}).status_code == 400
    with Session(engine) as db:
        db.query(DashboardLoginCodeModel).update({"expires_at": datetime.now(timezone.utc) - timedelta(minutes=1)})
        db.commit()
    assert client.post("/api/v1/dashboard/session", json={"code": second}).status_code == 400


def test_guessing_codes_is_limited():
    for _ in range(10):
        client.post("/api/v1/dashboard/session", json={"code": "AAAA-AAAA"})
    r = client.post("/api/v1/dashboard/session", json={"code": "AAAA-AAAA"})
    assert r.status_code == 429 and r.json()["detail"]["error_code"] == "TOO_MANY_ATTEMPTS"


def test_dashboard_token_is_read_only():
    headers, _ = _session()
    assert client.get("/api/v1/dashboard/data", headers=headers).status_code == 200
    assert client.get("/api/v1/dashboard/config", headers=headers).status_code == 200
    # Refusé partout ailleurs : notifications, autorisation de payer, code du tableau de bord
    assert client.get("/api/v1/notifications", headers=headers).status_code == 401
    assert client.post("/api/v1/dashboard/code", headers=headers).status_code == 401
    assert client.get("/api/v1/paypal/agent-authorization", headers=headers).status_code == 401


def test_data_contains_only_the_users_own_rows():
    now = datetime.now(timezone.utc)
    with Session(engine) as db:
        db.add(PriceWatchModel(user_id=1, product_id="p1", title="Keyboard K2", currency="USD", source="auto",
                               status="active", last_price="59.00", last_merchant="store-b.com",
                               expires_at=now + timedelta(days=30), created_at=now, updated_at=now))
        db.add(PriceWatchModel(user_id=2, product_id="p2", title="Other user", currency="USD", status="active",
                               created_at=now, updated_at=now))
        db.add(UserNotificationModel(user_id=1, kind="price_drop", product_id="p1", title="Keyboard K2",
                                     merchant="store-b.com", price="50.00", previous_price="59.00", currency="USD",
                                     created_at=now))
        db.commit()
    headers, _ = _session(1)
    data = client.get("/api/v1/dashboard/data", headers=headers).json()
    tables = data["tables"]
    assert data["user"]["first_name"] == "Jane"
    assert [p["product"] for p in tables["followed_products"]] == ["Keyboard K2"]
    assert tables["followed_products"][0]["followedBy"] == "SIKA (automatic)"
    change = tables["price_changes"][0]
    assert change["change"] == "Price drop" and change["price"] == 50.0 and change["changePercent"] == -0.1525
    assert tables["authorization"][0]["active"] is False
    assert set(tables) == {"payments", "followed_products", "price_changes", "subscriptions", "authorization"}


def test_studio_history_is_translated_for_gemini():
    items = [
        {"id": "u1", "kind": "input", "type": "message", "role": "user", "status": "completed",
         "content": [{"type": "text", "text": "Chart my spending by merchant"}]},
        {"id": "fc_1", "kind": "output", "type": "function_call", "callId": "call_a", "name": "view_schema",
         "arguments": "{}"},
        {"id": "fc_2", "kind": "output", "type": "function_call", "callId": "call_b", "name": "execute_query",
         "arguments": json.dumps({"fields": ["merchant"]})},
        {"type": "function_call_output", "callId": "call_a", "output": json.dumps({"tables": ["payments"]}), "status": "completed"},
        {"type": "function_call_output", "callId": "call_b", "output": "plain text", "status": "completed"},
        {"id": "r1", "kind": "output", "type": "reasoning", "summary": []},
    ]
    contents = dashboard_llm.to_gemini_contents(items)
    assert [c.role for c in contents] == ["user", "model", "user"]
    calls = contents[1].parts
    assert [p.function_call.name for p in calls] == ["view_schema", "execute_query"]
    assert calls[1].function_call.args == {"fields": ["merchant"]}
    assert calls[0].thought_signature == dashboard_llm.SKIP_SIGNATURE
    responses = contents[2].parts
    assert responses[0].function_response.name == "view_schema"
    assert responses[1].function_response.response == {"output": "plain text"}


def test_tool_choice_and_json_format():
    request = {"input": [], "instructions": "Build dashboards.", "toolChoice": {"name": "add_widget"},
               "tools": [{"name": "add_widget", "description": "Add", "parameters": {"type": "object", "properties": {}}},
                         {"name": "web", "description": "", "parameters": {}, "kind": "provided"}],
               "responseFormat": {"type": "json", "name": "plan", "schema": {"type": "object"}}}
    config = dashboard_llm.to_gemini_config(request)
    assert "read-only" in config.system_instruction.lower() and config.system_instruction.endswith("Build dashboards.")
    assert [d.name for d in config.tools[0].function_declarations] == ["add_widget"]
    assert config.tool_config.function_calling_config.allowed_function_names == ["add_widget"]
    assert config.response_mime_type == "application/json"


def _fake_response(parts, finish="STOP"):
    return SimpleNamespace(
        candidates=[SimpleNamespace(content=SimpleNamespace(parts=parts), finish_reason=finish)],
        usage_metadata=SimpleNamespace(prompt_token_count=120, candidates_token_count=30, total_token_count=150))


def test_gemini_answer_becomes_studio_output_and_keeps_the_signature():
    parts = [SimpleNamespace(text="Adding a chart.", thought=False, function_call=None),
             SimpleNamespace(text=None, function_call=SimpleNamespace(name="add_widget", args={"type": "grid"}),
                             thought_signature=b"\x01sig")]
    out = dashboard_llm.from_gemini_response(_fake_response(parts), "gemini-test")
    message, call = out["output"]
    assert out["status"] == "completed" and out["usage"]["totalTokens"] == 150
    assert message["content"][0]["text"] == "Adding a chart."
    assert call["name"] == "add_widget" and json.loads(call["arguments"]) == {"type": "grid"}
    # La signature revient intacte au tour suivant
    item = {**call, "type": "function_call"}
    part = dashboard_llm.to_gemini_contents([item])[0].parts[0]
    assert part.thought_signature == b"\x01sig"


def test_llm_route_needs_a_session_and_reports_failures(monkeypatch):
    from app.services import sika_ai

    body = {"input": [{"id": "u", "kind": "input", "type": "message", "role": "user", "status": "completed",
                       "content": [{"type": "text", "text": "hi"}]}], "responseFormat": {"type": "text"}}
    assert client.post("/api/v1/dashboard/llm", json=body).status_code == 401
    headers, _ = _session()

    async def boom(**kwargs):
        raise RuntimeError("quota")

    monkeypatch.setattr(sika_ai.sika_ai_service, "client", object())
    monkeypatch.setattr(sika_ai.sika_ai_service, "_generate", boom)
    r = client.post("/api/v1/dashboard/llm", json=body, headers=headers)
    assert r.status_code == 200 and r.json()["status"] == "failed" and r.json()["error"]["code"] == "AI_ERROR"

    async def answer(**kwargs):
        assert kwargs["config"].system_instruction.startswith("You are working inside SIKA Pay")
        return _fake_response([SimpleNamespace(text="Hello", thought=False, function_call=None)])

    monkeypatch.setattr(sika_ai.sika_ai_service, "_generate", answer)
    r = client.post("/api/v1/dashboard/llm", json=body, headers=headers)
    assert r.json()["status"] == "completed" and r.json()["output"][0]["content"][0]["text"] == "Hello"
