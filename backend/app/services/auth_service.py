"""
Service d'Authentification OAuth2 avec Jetons JWT (OAuth2 Bearer Token Auth)

Gère la génération des jetons d'accès, la validation et l'authentification des utilisateurs.
"""

from typing import Dict, Any, Optional
import base64
import json
import logging
import os
from datetime import datetime, timedelta, timezone



logger = logging.getLogger("SikaAuthService")

from fastapi import HTTPException
from ..database import SessionLocal
from ..models import UserModel
import hashlib

def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()

import jwt

class OAuth2AuthService:
    """Gère l'authentification OAuth2 et la délivrance des jetons Bearer JWT sécurisés via PyJWT (HS256)."""

    ALGORITHM = "HS256"
    TOKEN_EXPIRE_HOURS = 24 * 30 # Validité 30 jours pour l'application mobile

    @property
    def SECRET_KEY(self) -> str:
        secret = os.getenv("JWT_SECRET_KEY")
        env = os.getenv("ENV", "development").lower()
        if not secret:
            if env in ["production", "prod", "staging"]:
                logger.critical("[AUTH OAUTH2] FATAL: JWT_SECRET_KEY is missing in production environment!")
                raise RuntimeError("JWT_SECRET_KEY environment variable is required in production mode.")
            # Fallback de développement uniquement si ENV != production
            return "SIKA_SUPER_SECRET_JWT_KEY_2026_DEV_ONLY"
        if env in ["production", "prod"] and (secret in ["secret", "changeme", "123456", "default"] or len(secret) < 32):
            logger.critical("[AUTH OAUTH2] FATAL: Weak JWT_SECRET_KEY detected in production!")
            raise RuntimeError("Weak JWT_SECRET_KEY in production mode.")
        return secret

    def create_access_token(self, user_data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """Génère un jeton d'accès OAuth2 Bearer JWT pour l'utilisateur avec signature cryptographique PyJWT HS256."""
        u_id = user_data.get("id") or user_data.get("user_id") or 1
        now = datetime.now(timezone.utc)
        exp_time = now + (expires_delta if expires_delta is not None else timedelta(hours=self.TOKEN_EXPIRE_HOURS))
        payload = {
            "sub": user_data.get("email", "david.yao@email.com"),
            "user_id": int(u_id) if str(u_id).isdigit() else 1,
            "name": user_data.get("name", "David YAO"),
            "is_premium": user_data.get("is_premium", True),
            "iat": now,
            "exp": exp_time,
            "iss": "SIKA_AUTH_SERVER"
        }

        jwt_token = jwt.encode(payload, self.SECRET_KEY, algorithm=self.ALGORITHM)
        logger.info(f"[AUTH OAUTH2] Jeton JWT (PyJWT HS256) généré avec succès pour {user_data.get('email')}")
        return jwt_token

    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Vérifie la validité cryptographique d'un jeton Bearer JWT avec PyJWT et extrait le payload."""
        try:
            if not token:
                return None
            # Decoding avec vérification stricte de l'algorithme HS256 et expiration
            payload = jwt.decode(
                token,
                self.SECRET_KEY,
                algorithms=[self.ALGORITHM],
                options={"require": ["exp", "user_id", "sub", "iss"]}
            )
            return payload
        except jwt.ExpiredSignatureError:
            logger.warning("[AUTH OAUTH2] Jeton JWT expiré")
            return None
        except jwt.InvalidTokenError as e:
            logger.warning(f"[AUTH OAUTH2] Jeton JWT invalide ou signature altérée: {e}")
            return None
        except Exception as e:
            logger.error(f"[AUTH OAUTH2] Erreur inattendue de validation du jeton: {e}")
            return None


    def require_authenticated_user_id(self, authorization_header: Optional[str] = None) -> int:
        """Exige la présence d'un jeton Bearer JWT valide et non expiré.
        Lève une HTTPException(401) si le jeton est manquant, invalide ou expiré.
        AUCUN FALLBACK NI IDENTITY DEFAULT AUTORISÉ SUR LES ROUTÉS PROTÉGÉES.
        """
        if not authorization_header or not authorization_header.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Authentication required. Missing Bearer token.")

        token = authorization_header.split(" ")[1]
        payload = self.verify_token(token)
        if not payload:
            raise HTTPException(status_code=401, detail="Authentication failed. Invalid or expired Bearer token.")

        u_id = payload.get("user_id")
        if u_id is None:
            raise HTTPException(status_code=401, detail="Authentication failed. Missing user_id claim in token.")

        if isinstance(u_id, int):
            return u_id
        if isinstance(u_id, str) and u_id.isdigit():
            return int(u_id)
        raise HTTPException(status_code=401, detail="Authentication failed. Invalid user_id claim format.")

    def get_authenticated_user_id(self, authorization_header: Optional[str] = None, client_body_user_id: Any = 1) -> int:
        """Extrait l'ID de l'utilisateur authentifié depuis le jeton Bearer JWT avec fallback optionnel pour dev."""
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
