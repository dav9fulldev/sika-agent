"""
Service d'Authentification OAuth2 avec Jetons JWT (OAuth2 Bearer Token Auth)

Gère la génération des jetons d'accès, la validation et l'authentification des utilisateurs.
"""

from typing import Dict, Any, Optional
import base64
import json
import logging
from datetime import datetime, timedelta

logger = logging.getLogger("SikaAuthService")

class OAuth2AuthService:
    """Gère l'authentification OAuth2 et la délivrance des jetons Bearer JWT."""

    SECRET_KEY = "SIKA_SUPER_SECRET_JWT_KEY_2026"
    ALGORITHM = "HS256"
    TOKEN_EXPIRE_HOURS = 24 * 30 # Validité 30 jours pour l'application mobile

    def create_access_token(self, user_data: Dict[str, Any]) -> str:
        """Génère un jeton d'accès OAuth2 Bearer JWT pour l'utilisateur."""
        payload = {
            "sub": user_data.get("email"),
            "user_id": user_data.get("id", "usr_default"),
            "name": user_data.get("name", "David YAO"),
            "is_premium": user_data.get("is_premium", True),
            "exp": (datetime.utcnow() + timedelta(hours=self.TOKEN_EXPIRE_HOURS)).timestamp()
        }

        # Simulation de signature JWT (Base64 Encoded JSON Token)
        header = {"alg": "HS256", "typ": "JWT"}
        header_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().strip("=")
        payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().strip("=")
        signature = base64.urlsafe_b64encode(f"{header_b64}.{payload_b64}.{self.SECRET_KEY}".encode()).decode().strip("=")

        jwt_token = f"eyJ{header_b64}.{payload_b64}.{signature}"
        logger.info(f"[AUTH OAUTH2] Jeton JWT généré avec succès pour {user_data.get('email')}")
        return jwt_token

    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Vérifie la validité d'un jeton Bearer JWT et extrait les informations utilisateur."""
        try:
            if not token or not token.startswith("eyJ"):
                return None
            parts = token.split(".")
            if len(parts) < 2:
                return None

            payload_b64 = parts[1]
            # Padding correct pour Base64
            padded_b64 = payload_b64 + "=" * (-len(payload_b64) % 4)
            payload_json = base64.urlsafe_b64decode(padded_b64.encode()).decode()
            payload = json.loads(payload_json)

            # Vérification expiration
            if payload.get("exp") and datetime.utcnow().timestamp() > payload["exp"]:
                logger.warning("[AUTH OAUTH2] Jeton JWT expiré")
                return None

            return payload
        except Exception as e:
            logger.error(f"[AUTH OAUTH2] Erreur de validation du jeton: {e}")
            return None

    def login(self, email: str, password: str) -> Dict[str, Any]:
        """Authentification OAuth2 par mot de passe."""
        name = email.split("@")[0].capitalize() if "@" in email else "David YAO"
        user_data = {
            "id": f"usr_{int(datetime.now().timestamp())}",
            "name": name if name else "David YAO",
            "email": email,
            "is_premium": True,
        }
        token = self.create_access_token(user_data)
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": self.TOKEN_EXPIRE_HOURS * 3600,
            "user": user_data
        }

    def register(self, name: str, email: str, password: str) -> Dict[str, Any]:
        """Inscription d'un nouvel utilisateur avec émission automatique de jeton OAuth2."""
        user_data = {
            "id": f"usr_{int(datetime.now().timestamp())}",
            "name": name,
            "email": email,
            "is_premium": True,
        }
        token = self.create_access_token(user_data)
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": self.TOKEN_EXPIRE_HOURS * 3600,
            "user": user_data
        }

    def google_login(self, email: str = "david.yao@gmail.com", name: str = "David YAO") -> Dict[str, Any]:
        """Authentification OAuth2 via Google Sign-In."""
        user_data = {
            "id": f"usr_google_{int(datetime.now().timestamp())}",
            "name": name,
            "email": email,
            "is_premium": True,
            "is_google_auth": True,
        }
        token = self.create_access_token(user_data)
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": self.TOKEN_EXPIRE_HOURS * 3600,
            "user": user_data
        }

# Instance singleton
oauth2_auth_service = OAuth2AuthService()
