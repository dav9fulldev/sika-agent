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
