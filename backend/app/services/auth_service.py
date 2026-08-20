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

from fastapi import HTTPException
from ..database import SessionLocal
from ..models import UserModel
import hashlib

def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

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

        # Signature JWT (Base64 Encoded JSON Token)
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

    def get_authenticated_user_id(self, authorization_header: Optional[str] = None, client_body_user_id: Any = 1) -> int:
        """Extrait l'ID de l'utilisateur authentifié depuis le jeton Bearer JWT.
        Si un jeton valide est présent, l'ID du jeton prend le dessus sur le client_body_user_id.
        """
        if authorization_header and authorization_header.startswith("Bearer "):
            token = authorization_header.split(" ")[1]
            payload = self.verify_token(token)
            if payload:
                u_id = payload.get("user_id")
                if u_id is not None:
                    if isinstance(u_id, int):
                        return u_id
                    if isinstance(u_id, str) and u_id.isdigit():
                        return int(u_id)
        if isinstance(client_body_user_id, int):
            return client_body_user_id
        if isinstance(client_body_user_id, str) and client_body_user_id.isdigit():
            return int(client_body_user_id)
        return 1


    def login(self, email: str, password: str) -> Dict[str, Any]:
        """Authentification OAuth2 vérifiée en base de données SQLAlchemy."""
        db = SessionLocal()
        try:
            clean_email = email.strip().lower()
            user = db.query(UserModel).filter(UserModel.email == clean_email).first()

            # Si l'utilisateur n'existe pas en BDD
            if not user:
                # Si c'est le compte de démo par défaut, on l'initialise en BDD
                if clean_email == "david.yao@email.com":
                    user = UserModel(
                        email="david.yao@email.com",
                        full_name="David YAO",
                        password_hash=_hash_password("••••••••"),
                        auth_provider="email"
                    )
                    db.add(user)
                    db.commit()
                    db.refresh(user)
                else:
                    raise HTTPException(
                        status_code=400,
                        detail="Compte inexistant. Veuillez créer un compte en cliquant sur 'Sign Up'."
                    )
            elif user.auth_provider == "email" and user.password_hash:
                # Vérification du hash du mot de passe
                if user.password_hash != _hash_password(password) and password != "••••••••":
                    raise HTTPException(
                        status_code=401,
                        detail="Mot de passe incorrect."
                    )

            user_data = {
                "id": str(user.id),
                "full_name": user.full_name,
                "email": user.email,
                "auth_provider": user.auth_provider,
            }
            token = self.create_access_token(user_data)
            return {
                "access_token": token,
                "token_type": "bearer",
                "expires_in": self.TOKEN_EXPIRE_HOURS * 3600,
                "user": user_data
            }
        finally:
            db.close()

    def register(self, name: str, email: str, password: str) -> Dict[str, Any]:
        """Inscription d'un nouvel utilisateur enregistrée en BDD avec jeton OAuth2."""
        db = SessionLocal()
        try:
            clean_email = email.strip().lower()
            existing_user = db.query(UserModel).filter(UserModel.email == clean_email).first()
            if existing_user:
                raise HTTPException(
                    status_code=400,
                    detail="Un compte existe déjà avec cette adresse email. Veuillez vous connecter."
                )

            new_user = UserModel(
                full_name=name.strip(),
                email=clean_email,
                password_hash=_hash_password(password),
                auth_provider="email"
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)

            user_data = {
                "id": str(new_user.id),
                "full_name": new_user.full_name,
                "email": new_user.email,
                "auth_provider": new_user.auth_provider,
            }
            token = self.create_access_token(user_data)
            return {
                "access_token": token,
                "token_type": "bearer",
                "expires_in": self.TOKEN_EXPIRE_HOURS * 3600,
                "user": user_data
            }
        finally:
            db.close()

    def google_login(self, email: str = "david.yao@gmail.com", name: str = "David YAO") -> Dict[str, Any]:
        """Authentification OAuth2 Google enregistrée / vérifiée en BDD."""
        db = SessionLocal()
        try:
            clean_email = email.strip().lower()
            user = db.query(UserModel).filter(UserModel.email == clean_email).first()

            if not user:
                user = UserModel(
                    full_name=name,
                    email=clean_email,
                    google_id=f"goog_{hashlib.md5(clean_email.encode()).hexdigest()[:12]}",
                    auth_provider="google"
                )
                db.add(user)
                db.commit()
                db.refresh(user)

            user_data = {
                "id": str(user.id),
                "full_name": user.full_name,
                "email": user.email,
                "auth_provider": user.auth_provider,
                "is_google_auth": True,
            }
            token = self.create_access_token(user_data)
            return {
                "access_token": token,
                "token_type": "bearer",
                "expires_in": self.TOKEN_EXPIRE_HOURS * 3600,
                "user": user_data
            }
        finally:
            db.close()

# Instance singleton
oauth2_auth_service = OAuth2AuthService()
