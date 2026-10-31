"""
SIKA Pay — Envoi de notifications push (Firebase Cloud Messaging, API HTTP v1).

L'authentification utilise les identifiants par défaut de Google Cloud (compte de service de Cloud Run,
rôle « Firebase Cloud Messaging API Admin »). Aucune clé n'est stockée dans le code. Sans FCM_PROJECT_ID,
le push est désactivé et les notifications restent visibles dans l'app.
"""

import logging
from typing import Dict, Optional

from ..config import settings

logger = logging.getLogger("SikaPush")

FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"


class PushService:
    def __init__(self, session=None):
        self._session = session

    def enabled(self) -> bool:
        return bool(settings.FCM_PROJECT_ID)

    def _authorized_session(self):
        if self._session is None:
            import google.auth
            from google.auth.transport.requests import AuthorizedSession

            credentials, _ = google.auth.default(scopes=[FCM_SCOPE])
            self._session = AuthorizedSession(credentials)
        return self._session

    def send(self, token: str, title: str, body: str, data: Optional[Dict[str, str]] = None) -> str:
        """Retourne SENT, INVALID_TOKEN (à supprimer), FAILED ou DISABLED. Ne lève jamais d'exception."""
        if not self.enabled():
            return "DISABLED"
        message = {
            "token": token,
            "notification": {"title": title[:120], "body": body[:240]},
            "data": {k: str(v) for k, v in (data or {}).items()},
            "android": {"priority": "high"},
        }
        try:
            resp = self._authorized_session().post(
                f"https://fcm.googleapis.com/v1/projects/{settings.FCM_PROJECT_ID}/messages:send",
                json={"message": message},
                timeout=10,
            )
        except Exception as e:  # réseau, identifiants Google absents : le push ne doit jamais casser le webhook
            logger.warning(f"[PUSH] FCM unreachable: {type(e).__name__}")
            return "FAILED"
        if resp.status_code == 200:
            return "SENT"
        text = resp.text or ""
        # Jeton désinstallé ou expiré : 404 UNREGISTERED, ou 400 sur un jeton mal formé
        if resp.status_code == 404 or (resp.status_code == 400 and "registration token" in text.lower()):
            return "INVALID_TOKEN"
        logger.warning(f"[PUSH] FCM HTTP {resp.status_code}")
        return "FAILED"


push_service = PushService()
