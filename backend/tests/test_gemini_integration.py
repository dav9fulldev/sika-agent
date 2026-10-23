import os
# pyrefly: ignore [missing-import]
import pytest
import asyncio
from unittest.mock import MagicMock, AsyncMock, patch
from app.services.sika_ai import SikaAI
from app.agent.orchestrator import SikaAgentOrchestrator


@pytest.fixture
def mock_gemini_env():
    env = {
        "AI_PROVIDER": "gemini",
        "GOOGLE_CLOUD_PROJECT": "sika-all-things-agentic",
        "GOOGLE_CLOUD_LOCATION": "global",
        "GEMINI_MODEL": "gemini-3.5-flash",
    }
    with patch.dict(os.environ, env):
        os.environ.pop("GEMINI_API_KEY", None)
        yield


def _text_response(text):
    resp = MagicMock()
    resp.text = text
    resp.function_calls = None
    resp.candidates = []
    return resp


def test_gemini_initialization(mock_gemini_env):
    """Vérifie que SikaAI s'initialise correctement avec le SDK Vertex AI."""
    with patch("google.genai.Client") as mock_client_class:
        sika_ai = SikaAI()
        assert sika_ai.project == "sika-all-things-agentic"
        assert sika_ai.location == "global"
        assert sika_ai.model == "gemini-3.5-flash"
        assert sika_ai.use_gemini is True
        mock_client_class.assert_called_once_with(
            vertexai=True,
            project="sika-all-things-agentic",
            location="global"
        )


def test_gemini_api_key_is_supported(mock_gemini_env):
    """Une clé Gemini Developer API remplace Vertex AI (reproductibilité pour les reviewers)."""
    with patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"}), patch("google.genai.Client") as mock_client_class:
        sika_ai = SikaAI()
        mock_client_class.assert_called_once_with(api_key="test-key")
        assert sika_ai.provider == "gemini_api"


def test_gemini_chat_invocation(mock_gemini_env):
    """Un appel chat invoque réellement client.aio.models.generate_content du SDK Google GenAI."""
    mock_genai_client = MagicMock()
    mock_genai_client.aio.models.generate_content = AsyncMock(
        return_value=_text_response("Tell me what you want to buy and your budget.")
    )

    with patch("google.genai.Client", return_value=mock_genai_client):
        sika_ai = SikaAI()
        res = asyncio.run(sika_ai.chat(user_message="Can you help me pay for something?", user_firstname="David"))

        assert mock_genai_client.aio.models.generate_content.called is True
        assert res["model"] == "gemini-3.5-flash"
        assert res["provider"] == "VERTEX_AI_AGENT"
        assert res["requires_confirmation"] is False


def test_orchestrator_text_answer_requires_no_confirmation(mock_gemini_env):
    """Sans tool prepare_paypal_checkout réussi, aucune confirmation n'est demandée (pas d'action inventée)."""
    mock_genai_client = MagicMock()
    mock_genai_client.aio.models.generate_content = AsyncMock(
        return_value=_text_response("Which product do you want?")
    )

    with patch("google.genai.Client", return_value=mock_genai_client):
        orchestrator = SikaAgentOrchestrator()
        result = asyncio.run(orchestrator.process_user_request(user_id=1, query="I want to buy something"))

        assert mock_genai_client.aio.models.generate_content.called is True
        assert result["status"] == "PROCESSED"
        assert result["requires_confirmation"] is False
        assert result["action_id"] is None


def test_gemini_fallback_on_error(mock_gemini_env):
    """En cas d'erreur Vertex AI, SIKA bascule sur le moteur déterministe sans crasher ni inventer de paiement."""
    mock_genai_client = MagicMock()
    mock_genai_client.aio.models.generate_content = AsyncMock(side_effect=Exception("Vertex AI ADC / Network Timeout"))

    with patch("google.genai.Client", return_value=mock_genai_client):
        sika_ai = SikaAI()
        res = asyncio.run(sika_ai.chat(user_message="What can you do for me?", user_firstname="David"))

        assert res["provider"] == "SIKA_LOCAL_FALLBACK"
        assert res["response"]
        assert res["requires_confirmation"] is False
