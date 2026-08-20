import base64
import logging
from typing import Dict, Any, Optional
from google.cloud import texttospeech

logger = logging.getLogger(__name__)

class GCPTTSService:
    """Service d'intégration officiel Google Cloud Text-to-Speech (GCP TTS).
    Génère une synthèse vocale haute-fidélité en Français (ex: fr-FR-Neural2-C) via ADC.
    """

    DEFAULT_VOICE = "fr-FR-Neural2-C"
    DEFAULT_LANG = "fr-FR"

    def __init__(self):
        self._client = None

    def _get_client(self) -> Optional[texttospeech.TextToSpeechClient]:
        if self._client is None:
            try:
                self._client = texttospeech.TextToSpeechClient()
                logger.info("✅ Client Google Cloud Text-to-Speech (GCP TTS) initialisé avec succès via ADC.")
            except Exception as e:
                logger.warning(f"⚠️ Initialisation GCP TTS impossible: {e}")
        return self._client

    def synthesize_speech(
        self,
        text: str,
        voice_name: str = DEFAULT_VOICE,
        language_code: str = DEFAULT_LANG,
        speaking_rate: float = 1.05,
        pitch: float = 0.0
    ) -> Dict[str, Any]:
        """Synthétise un texte en audio MP3 encodé en base64 via l'API Google Cloud TTS."""
        if not text or not text.strip():
            return {"success": False, "error": "Le texte à synthétiser est vide."}

        client = self._get_client()
        if not client:
            return {"success": False, "error": "Service GCP Text-to-Speech non disponible."}

        try:
            synthesis_input = texttospeech.SynthesisInput(text=text.strip())

            # Sélection de la voix haute qualité (Neural2 / Wavenet / Standard)
            voice = texttospeech.VoiceSelectionParams(
                language_code=language_code,
                name=voice_name,
                ssml_gender=texttospeech.SsmlVoiceGender.FEMALE
            )

            # Configuration Audio MP3
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.MP3,
                speaking_rate=speaking_rate,
                pitch=pitch
            )

            logger.info(f"[GCP TTS] Synthèse vocale en cours pour '{text[:40]}...' (Voix: {voice_name})")
            response = client.synthesize_speech(
                input=synthesis_input,
                voice=voice,
                audio_config=audio_config
            )

            audio_base64 = base64.b64encode(response.audio_content).decode("utf-8")
            return {
                "success": True,
                "audio_base64": audio_base64,
                "content_type": "audio/mp3",
                "voice_name": voice_name,
                "language_code": language_code,
                "audio_bytes_length": len(response.audio_content),
                "text": text
            }
        except Exception as e:
            logger.error(f"[GCP TTS] Échec de la synthèse vocale: {e}")
            return {
                "success": False,
                "error": str(e),
                "message": "Erreur lors de la génération de l'audio GCP TTS."
            }

    def list_french_voices(self) -> Dict[str, Any]:
        """Retourne la liste des voix françaises de haute qualité disponibles sur GCP TTS."""
        client = self._get_client()
        if not client:
            return {"success": False, "voices": []}

        try:
            voices_response = client.list_voices(language_code="fr-FR")
            voices = []
            for v in voices_response.voices:
                voices.append({
                    "name": v.name,
                    "language_codes": list(v.language_codes),
                    "ssml_gender": v.ssml_gender.name
                })
            return {"success": True, "voices": voices}
        except Exception as e:
            logger.warning(f"[GCP TTS] Impossible de lister les voix: {e}")
            return {"success": False, "error": str(e), "voices": []}


gcp_tts_service = GCPTTSService()
