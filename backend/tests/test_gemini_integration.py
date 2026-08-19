import os
# pyrefly: ignore [missing-import]
import pytest
import asyncio
from unittest.mock import MagicMock, patch
from app.services.sika_ai import SikaAI
from app.agent.orchestrator import SikaAgentOrchestrator


@pytest.fixture
def mock_gemini_env():
    with patch.dict(os.environ, {
        "AI_PROVIDER": "gemini",
        "GOOGLE_CLOUD_PROJECT": "sika-all-things-agentic",
        "GOOGLE_CLOUD_LOCATION": "global",
        "GEMINI_MODEL": "gemini-3.5-flash"
    }):
        yield


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


def test_gemini_chat_invocation(mock_gemini_env):
    """Vérifie qu'un appel chat à SikaAI invoque réellement la méthode client.models.generate_content du SDK Google GenAI."""
    mock_genai_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "Salut ! Je suis Sika et je surveille tes finances via Google Gemini sur Vertex AI."
    mock_genai_client.models.generate_content.return_value = mock_response

    with patch("google.genai.Client", return_value=mock_genai_client):
        sika_ai = SikaAI()
        
        async def run():
            return await sika_ai.chat(
                user_message="Donne-moi un conseil financier rapide.",
                financial_context={"remaining_budget": 45000},
                user_firstname="David"
            )
        
        res = asyncio.run(run())

        assert mock_genai_client.models.generate_content.called is True
        assert res["model"] == "gemini-3.5-flash"
        assert "Gemini" in res["response"]


def test_orchestrator_react_loop_with_gemini(mock_gemini_env):
    """Vérifie que l'Orchestrateur Taskmaster exécute le cycle ReAct complet avec Google Gemini via Vertex AI."""
    mock_genai_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "Je prépare un transfert de 10 000 FCFA sur Wave vers Kouamé."
    mock_genai_client.models.generate_content.return_value = mock_response

    with patch("google.genai.Client", return_value=mock_genai_client):
        orchestrator = SikaAgentOrchestrator()
        
        async def run():
            return await orchestrator.process_user_request(
                user_id=1,
                query="Transfert 10 000 FCFA à Kouamé sur Wave"
            )

        result = asyncio.run(run())

        assert mock_genai_client.models.generate_content.called is True
        assert result["status"] == "PROCESSED"
        assert result["requires_confirmation"] is True
        assert result["model"] == "gemini-3.5-flash"


def test_gemini_fallback_on_error(mock_gemini_env):
    """Vérifie le fallback automatique vers _chat_basic en cas d'erreur de credentials ou réseau Vertex AI."""
    mock_genai_client = MagicMock()
    mock_genai_client.models.generate_content.side_effect = Exception("Vertex AI ADC / Network Timeout")

    with patch("google.genai.Client", return_value=mock_genai_client):
        sika_ai = SikaAI()
        
        async def run():
            return await sika_ai.chat(
                user_message="Quel est mon solde ?",
                financial_context={},
                user_firstname="David"
            )

        res = asyncio.run(run())

        # Doit effectuer un fallback propre sans crasher
        assert res["response"] is not None
        assert any(kw in res["response"] for kw in ["solde", "FCFA", "portefeuille"])
