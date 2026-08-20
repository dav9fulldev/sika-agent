import pytest
from app.services.gcp_tts_service import gcp_tts_service
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_gcp_tts_service_synthesis():
    """Vérifie la génération de la synthèse vocale via GCP Text-to-Speech service."""
    res = gcp_tts_service.synthesize_speech("Bonjour David, ceci est un test de synthèse vocale GCP TTS.")
    assert res.get("success") is True
    assert "audio_base64" in res
    assert len(res["audio_base64"]) > 100
    assert res.get("content_type") == "audio/mp3"

def test_gcp_tts_endpoint():
    """Vérifie l'endpoint HTTP POST /api/v1/sika/tts."""
    response = client.post(
        "/api/v1/sika/tts",
        json={
            "text": "Sika prépare votre virement.",
            "voice_name": "fr-FR-Neural2-C"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data.get("success") is True
    assert "audio_base64" in data
    assert data.get("voice_name") == "fr-FR-Neural2-C"

def test_gcp_tts_voices_list():
    """Vérifie la liste des voix françaises GCP TTS."""
    response = client.get("/api/v1/sika/tts/voices")
    assert response.status_code == 200
    data = response.json()
    assert data.get("success") is True
    assert isinstance(data.get("voices"), list)

def test_chat_endpoint_does_not_embed_audio_base64():
    """Vérifie que /chat retourne speech_text et should_speak sans doubler la génération audio base64."""
    response = client.post(
        "/api/v1/sika/chat",
        json={"query": "Quel est mon solde ?"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "speech_text" in data
    assert "should_speak" in data
    assert data.get("audio_base64") is None  # Separation de responsabilité validée

def test_gcp_tts_empty_text_validation():
    """Vérifie que /tts retourne HTTP 400 si le texte est vide."""
    response = client.post(
        "/api/v1/sika/tts",
        json={"text": ""}
    )
    assert response.status_code == 400

