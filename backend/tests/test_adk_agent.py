import os
import pytest
from unittest.mock import MagicMock, patch
from app.agents import sika_adk_agent, SikaADKAgent
from app.agents.tools import get_total_balance, get_savings_status


def test_google_adk_import():
    """Vérifie que le package Google ADK est installé et importable."""
    import google.adk
    assert google.adk is not None


def test_adk_balance_tool():
    """Vérifie le fonctionnement de l'outil get_total_balance."""
    res = get_total_balance()
    assert res["success"] is True
    assert "total_balance" in res
    assert res["currency"] == "XOF"
    assert "wallets" in res


def test_adk_savings_tool():
    """Vérifie le fonctionnement de l'outil get_savings_status."""
    res = get_savings_status()
    assert res["success"] is True
    assert "coffre_name" in res
    assert "current_amount" in res
    assert "target_amount" in res


def test_sika_adk_agent_query():
    """Vérifie le traitement d'une requête par l'Agent SIKA ADK."""
    mock_client = MagicMock()
    mock_response = MagicMock()
    mock_response.text = "Voici votre solde total via Google ADK et Vertex AI."
    mock_client.models.generate_content.return_value = mock_response

    with patch("google.genai.Client", return_value=mock_client):
        agent = SikaADKAgent()
        res = agent.process_query("Quel est mon solde ?", user_firstname="David")

        assert res["success"] is True
        assert res["tool_used"] == "get_total_balance"
        assert res["provider"] == "GOOGLE_ADK_VERTEX_AI"
        assert "solde" in res["response"].lower() or "adk" in res["response"].lower()
