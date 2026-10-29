"""Cohérence linguistique du moteur de secours SIKA Pay (sans LLM)."""

import asyncio
import pytest
from app.services.sika_ai import SikaAIService


@pytest.fixture
def sika_service():
    svc = SikaAIService.__new__(SikaAIService)
    svc.provider, svc.model, svc.client = "vertex_ai", "none", None
    return svc


def test_detect_language_english_and_french(sika_service):
    assert sika_service.detect_language("Help me buy a course under $50") == "en"
    assert sika_service.detect_language("Aide-moi à acheter un cours à moins de 50 dollars") == "fr"
    assert sika_service.detect_language("") == "fr"


def test_pure_greeting_hello_returns_english_greeting(sika_service):
    res = asyncio.run(sika_service.chat("hello", user_id="1"))
    assert res["language"] == "en"
    assert "SIKA Pay" in res["response"]
    assert res["action_id"] is None and res["requires_confirmation"] is False


def test_pure_greeting_bonjour_returns_french_greeting(sika_service):
    res = asyncio.run(sika_service.chat("bonjour", user_id="1"))
    assert res["language"] == "fr"
    assert "Bonjour" in res["response"]
    assert res["action_id"] is None


def test_unrelated_request_in_fallback_is_honest(sika_service):
    res = asyncio.run(sika_service.chat("What is the weather today?", user_id="1"))
    assert res["language"] == "en"
    assert "unavailable" in res["response"]
    assert res["provider"] == "SIKA_LOCAL_FALLBACK"


def test_assistant_uses_the_account_name_not_the_client_value(monkeypatch):
    """Le prénom vient du compte authentifié ; un client ne peut pas imposer un autre nom."""
    from sqlalchemy.orm import Session
    from fastapi.testclient import TestClient
    from app.main import app
    from app.database import engine
    from app.models.user import UserModel
    from app.services.auth_service import oauth2_auth_service
    from app.services import sika_ai as sika_ai_module

    with Session(engine) as db:
        user = db.query(UserModel).filter(UserModel.email == "name-check@sika.test").first()
        if not user:
            user = UserModel(email="name-check@sika.test", full_name="Amina Kone")
            db.add(user)
            db.commit()
            db.refresh(user)
        uid = user.id
    seen = {}

    async def fake_chat(**kwargs):
        seen["name"] = kwargs.get("user_firstname")
        return {"response": "ok", "action": "chat"}

    monkeypatch.setattr(sika_ai_module.sika_ai_service, "chat", fake_chat)
    from app.routes import sika_router
    monkeypatch.setattr(sika_router.sika_ai, "chat", fake_chat)
    token = oauth2_auth_service.create_access_token({"user_id": uid, "email": "name-check@sika.test"})
    TestClient(app).post("/api/v1/sika/chat", json={"query": "hi there", "context": {"user_firstname": "David"}},
                         headers={"Authorization": f"Bearer {token}"})
    assert seen["name"] == "Amina"


def test_no_invented_name_when_the_account_has_none():
    from app.services.sika_ai import SikaAIService
    text = SikaAIService.__new__(SikaAIService)._sika_pay_instruction("", "Answer in English.")
    assert "never invent one" in text and "help the user" in text
