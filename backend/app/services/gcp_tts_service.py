import re
import base64
import logging
from typing import Dict, Any, Optional
from google.cloud import texttospeech

logger = logging.getLogger(__name__)

_URL = re.compile(r"https?://\S+")
# Identifiants techniques (commande PayPal, capture, checkout) : illisibles à voix haute
_TECH_ID = re.compile(r"\b(?=[A-Z0-9_-]*\d)(?=[A-Z0-9_-]*[A-Z])[A-Z0-9_-]{10,}\b|\bchk_[a-f0-9]+\b|\bsub_[a-f0-9]+\b")


def speakable_text(text: str) -> str:
    """Texte prêt à être lu : sans liens, sans identifiants techniques, sans ponctuation vide."""
    text = _URL.sub("", text or "")
    text = _TECH_ID.sub("", text)
    text = re.sub(r"\b(Order|Capture|Commande|capture|order),?\s*(?=[,.])", "", text)
    text = re.sub(r"\s+([,.;:])", r"\1", text)
    text = re.sub(r"([,.;:]){2,}", r"\1", text)
    return re.sub(r"\s{2,}", " ", text).strip()[:1200]


class GCPTTSService:
    """Service d'intégration officiel Google Cloud Text-to-Speech (GCP TTS).
    Voix Chirp 3 HD (dernière génération Google, la plus naturelle), en français et en anglais, via ADC.
    """

    DEFAULT_VOICE_FR = "fr-FR-Chirp3-HD-Aoede"
    DEFAULT_VOICE_EN = "en-US-Chirp3-HD-Aoede"
    # Seules ces familles de voix peuvent être demandées par l'app (les autres retombent sur la voix par défaut)
    ALLOWED_VOICE_PREFIXES = ("fr-FR-Chirp3-HD-", "en-US-Chirp3-HD-", "fr-FR-Neural2-", "en-US-Neural2-")
    DEFAULT_LANG_FR = "fr-FR"
    DEFAULT_LANG_EN = "en-US"

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
        voice_name: Optional[str] = None,
        language_code: Optional[str] = None,
        speaking_rate: float = 1.05,
        pitch: float = 0.0
    ) -> Dict[str, Any]:
        """Synthétise un texte en audio MP3 encodé en base64 via l'API Google Cloud TTS."""
        if not text or not text.strip():
            return {"success": False, "error": "Le texte à synthétiser est vide."}

        if voice_name and not voice_name.startswith(self.ALLOWED_VOICE_PREFIXES):
            voice_name = None
        text = speakable_text(text)

        client = self._get_client()
        if not client:
            return {"success": False, "error": "Service GCP Text-to-Speech non disponible."}

        try:
            # Détection intelligente de la langue (EN vs FR)
            is_en_text = False
            try:
                from .sika_ai import sika_ai
                is_en_text = sika_ai._is_english(text)
            except Exception:
                pass

            is_en = (language_code and language_code.lower().startswith("en")) or (voice_name and voice_name.startswith("en-")) or is_en_text

            if not voice_name:
                voice_name = self.DEFAULT_VOICE_EN if is_en else self.DEFAULT_VOICE_FR
                language_code = self.DEFAULT_LANG_EN if is_en else self.DEFAULT_LANG_FR
            else:
                if voice_name.startswith("en-"):
                    language_code = language_code or "-".join(voice_name.split("-")[:2])
                elif voice_name.startswith("fr-"):
                    language_code = language_code or "-".join(voice_name.split("-")[:2])
                else:
                    language_code = language_code or (self.DEFAULT_LANG_EN if is_en else self.DEFAULT_LANG_FR)

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
