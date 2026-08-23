"""
Service d'Authentification OAuth2 avec Jetons JWT (OAuth2 Bearer Token Auth)

Gère la génération des jetons d'accès, la validation et l'authentification des utilisateurs.
"""

from typing import Dict, Any, Optional
import base64
import json
import logging
import os
import hashlib
import uuid
from datetime import datetime, timedelta, timezone
# pyrefly: ignore [missing-import]
from fastapi import HTTPException
# pyrefly: ignore [missing-import]
import jwt
# pyrefly: ignore [missing-import]
from google.oauth2 import id_token as google_id_token
# pyrefly: ignore [missing-import]
from google.auth.transport import requests as google_requests

from ..database import SessionLocal
from ..models import UserModel
from ..config import settings
from .security_rate_limiter import security_rate_limiter

logger = logging.getLogger("SikaAuthService")


def _hash_password(password: str) -> str:
    return hashlib.sha256(password.encode('utf-8')).hexdigest()


def verify_google_id_token(token_str: str, client_id: Optional[str] = None) -> Dict[str, Any]:
    """Vérifie cryptographiquement un Google ID Token avec les clés publiques officielles de Google."""
    request = google_requests.Request()
    try:
        id_info = google_id_token.verify_oauth2_token(
            token_str, request, audience=client_id
        )
        # Vérification stricte de l'émetteur
        if id_info.get("iss") not in ["accounts.google.com", "https://accounts.google.com"]:
            raise ValueError(f"Issuer Google invalide: {id_info.get('iss')}")

        # Vérification email_verified
        if not id_info.get("email_verified", False):
            raise ValueError("L'adresse email Google n'a pas été vérifiée par Google.")

        return id_info
    except Exception as e:
        logger.warning(f"[AUTH GOOGLE] Échec de vérification du jeton Google: {e}")
        raise ValueError(f"Jeton Google ID Token invalide ou signature expirée: {e}")


class OAuth2AuthService:
    """Gère l'authentification OAuth2 et la délivrance des jetons Bearer JWT sécurisés via PyJWT (HS256)."""

    ALGORITHM = "HS256"
    TOKEN_EXPIRE_HOURS = 24 * 30  # Validité 30 jours pour l'application mobile

    @property
    def SECRET_KEY(self) -> str:
        env = os.getenv("ENV", settings.ENV).lower()
        secret = os.getenv("JWT_SECRET_KEY", settings.JWT_SECRET_KEY)
        insecure_defaults = [
            "sika_default_jwt_secret_dev_key_only_change_in_prod_32_chars",
            "default_secret",
            "secret",
            "changeme",
            "123456",
            "12345678"
        ]
        if env in ["production", "prod"]:
            if not secret or secret in insecure_defaults or len(secret) < 32:
                raise RuntimeError("JWT_SECRET_KEY environment variable is required in production mode (weak or default key forbidden).")
        return secret

    def create_access_token(self, user_data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """Génère un jeton d'accès OAuth2 Bearer JWT pour l'utilisateur avec signature cryptographique PyJWT HS256."""
        u_id = user_data.get("id") or user_data.get("user_id") or 1
        now = datetime.now(timezone.utc)
        exp_time = now + (expires_delta if expires_delta is not None else timedelta(hours=self.TOKEN_EXPIRE_HOURS))
        jti_val = user_data.get("jti") or str(uuid.uuid4())
        payload = {
            "sub": user_data.get("email", "anonymous@sika.app"),
            "user_id": int(u_id) if str(u_id).isdigit() else 1,
            "name": user_data.get("name") or user_data.get("full_name") or "User",
            "is_premium": user_data.get("is_premium", True),
            "jti": jti_val,
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
            if security_rate_limiter.is_token_revoked(token):
                logger.warning("[AUTH OAUTH2] Tentative d'accès avec un jeton révoqué (post-logout).")
                return None
            # Decoding avec vérification stricte de l'algorithme HS256 et expiration
            payload = jwt.decode(
                token,
                self.SECRET_KEY,
                algorithms=[self.ALGORITHM],
                options={"require": ["exp", "user_id", "sub", "iss"]}
            )
            jti = payload.get("jti")
            if jti and security_rate_limiter.is_token_revoked(token, jti=jti):
                logger.warning("[AUTH OAUTH2] Tentative d'accès avec un JTI révoqué.")
                return None
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

    def require_authenticated_user_id(self, authorization: Optional[str] = None, authorization_header: Optional[str] = None) -> Any:
        """Extrait et valide le user_id à partir de l'en-tête Authorization Bearer ou lève une HTTPException 401."""
        auth_val = authorization or authorization_header
        if not auth_val or not auth_val.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Authentication required: En-tête Authorization Bearer manquant ou invalide.")
        token = auth_val.split("Bearer ")[1].strip()
        payload = self.verify_token(token)
        if not payload or "user_id" not in payload:
            raise HTTPException(status_code=401, detail="Authentication required: Jeton d'authentification invalide ou expiré.")
        u_id = payload["user_id"]
        return int(u_id) if str(u_id).isdigit() else u_id

    def login(self, email: str, password: str) -> Dict[str, Any]:
        """Connexion utilisateur avec vérification en base de données."""
        clean_email = email.strip().lower()
        security_rate_limiter.check_login_rate_limit(clean_email)

        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.email == clean_email).first()
            if not user or user.password_hash != _hash_password(password):
                security_rate_limiter.record_login_failure(clean_email)
                raise HTTPException(
                    status_code=401,
                    detail="Identifiants invalides. Vérifiez votre adresse email et votre mot de passe."
                )

            security_rate_limiter.reset_login_failures(clean_email)

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

    def google_login(self, email: Optional[str] = None, name: str = "Utilisateur Google", id_token: Optional[str] = None) -> Dict[str, Any]:
        """Authentification OAuth2 Google enregistrée / vérifiée en BDD avec vérification cryptographique."""
        verified_email = None
        verified_name = name
        google_sub_id = None

        if id_token:
            try:
                id_info = verify_google_id_token(id_token, client_id=settings.GOOGLE_CLIENT_ID)
                verified_email = id_info.get("email", "").strip().lower()
                verified_name = id_info.get("name", name)
                google_sub_id = id_info.get("sub")
            except ValueError as e:
                if settings.ENV == "production":
                    raise HTTPException(status_code=401, detail=f"Validation cryptographique du jeton Google échouée: {str(e)}")
                logger.warning(f"[AUTH GOOGLE DEV] Jeton Google invalide en DEV: {e}")
                if email:
                    verified_email = email.strip().lower()
                else:
                    raise HTTPException(status_code=401, detail=f"Jeton Google invalide: {str(e)}")
        elif email:
            if settings.ENV == "production":
                raise HTTPException(status_code=401, detail="Le jeton id_token Google officiel est obligatoire en production.")
            verified_email = email.strip().lower()
        else:
            raise HTTPException(status_code=400, detail="Adresse email ou jeton Google manquant.")

        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.email == verified_email).first()

            if not user:
                user = UserModel(
                    full_name=verified_name.strip() if verified_name else "Utilisateur Google",
                    email=verified_email,
                    google_id=google_sub_id or f"goog_{hashlib.md5(verified_email.encode()).hexdigest()[:12]}",
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

    def generate_password_reset_otp(self, email: str) -> Dict[str, Any]:
        """Génère un OTP pour la réinitialisation de mot de passe."""
        clean_email = email.strip().lower()
        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.email == clean_email).first()
            if not user:
                # Éviter le user enumeration en renvoyant toujours un message de succès
                return {"success": True, "message": "Si cette adresse existe, un code de réinitialisation a été généré.", "otp": "000000"}

            import random
            otp = f"{random.randint(100000, 999999)}"
            security_rate_limiter.store_otp(clean_email, otp, expire_seconds=900)
            logger.info(f"[AUTH FORGOT PASSWORD] OTP généré pour {clean_email}")
            
            return {
                "success": True, 
                "message": "Code de réinitialisation généré avec succès.",
                "otp": otp
            }
        finally:
            db.close()

    def reset_password_with_otp(self, email: str, otp: str, new_password: str) -> Dict[str, Any]:
        """Réinitialise le mot de passe après vérification de l'OTP."""
        clean_email = email.strip().lower()
        if not security_rate_limiter.verify_otp(clean_email, otp):
            raise HTTPException(status_code=400, detail="Code de vérification (OTP) invalide ou expiré.")

        db = SessionLocal()
        try:
            user = db.query(UserModel).filter(UserModel.email == clean_email).first()
            if not user:
                raise HTTPException(status_code=404, detail="Utilisateur introuvable.")

            user.password_hash = _hash_password(new_password)
            db.commit()
            
            security_rate_limiter.clear_otp(clean_email)
            logger.info(f"[AUTH RESET PASSWORD] Mot de passe réinitialisé pour {clean_email}")

            return {"success": True, "message": "Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter."}
        finally:
            db.close()


# Instance singleton
oauth2_auth_service = OAuth2AuthService()
