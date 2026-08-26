"""
Module de Sécurité : Rate Limiting, Protection Anti-Brute-Force & Révocation de Tokens.

Gère :
- La liste des jetons JWT révoqués (Deny-list avec TTL, support InMemory ou Redis distribué).
- Le comptage et blocage des tentatives infructueuses sur les challenges OTP (max 3 essais, TTL 10 min).
- La protection contre le brute-force de codes PIN de transaction (max 3 échecs / 5 min).
- La protection contre le brute-force de connexion (max 5 échecs / 5 min).
- Le rate-limiting anti-flood sur les actions financières sensibles.
"""

from typing import Dict, Set, Optional, Tuple
from datetime import datetime, timedelta, timezone
import logging
# pyrefly: ignore [missing-import]
from fastapi import HTTPException
from .security_store import BaseSecurityStore, create_security_store

logger = logging.getLogger("SikaSecurityRateLimiter")


class SecurityRateLimiter:
    def __init__(self, store: Optional[BaseSecurityStore] = None):
        self.store = store or create_security_store()

    def set_store(self, store: BaseSecurityStore):
        """Permet d'injecter un store spécifique (utile pour les tests et la configuration)."""
        self.store = store

    def clear(self):
        """Nettoie tous les états dans le store."""
        self.store.clear()

    # =========================================================================
    # 1. GESTION DES TOKENS RÉVOQUÉS (LOGOUT)
    # =========================================================================

    def revoke_token(self, token: str, jti: Optional[str] = None, expires_at: Optional[datetime] = None) -> None:
        """Enregistre un jeton et/ou son JTI dans la deny-list jusqu'à sa date d'expiration."""
        ttl_seconds = 259200  # 3 jours par défaut
        if expires_at:
            now = datetime.now(timezone.utc)
            if expires_at.tzinfo is None:
                expires_at = expires_at.replace(tzinfo=timezone.utc)
            diff = (expires_at - now).total_seconds()
            if diff > 0:
                ttl_seconds = int(diff)

        if token:
            self.store.add_revoked_token(token, expire_seconds=ttl_seconds)
        if jti:
            self.store.add_revoked_token(f"jti_{jti}", expire_seconds=ttl_seconds)
        logger.info(f"[SECURITY LOGOUT] Jeton/JTI révoqué avec succès (TTL: {ttl_seconds}s).")

    def is_token_revoked(self, token: str, jti: Optional[str] = None) -> bool:
        """Vérifie si un token ou son JTI a été invalidé après un logout."""
        if token and self.store.is_token_revoked(token):
            return True
        if jti and self.store.is_token_revoked(f"jti_{jti}"):
            return True
        return False

    # =========================================================================
    # 2. PROTECTION BRUTE-FORCE PIN TRANSACTIONNEL (/wallets/verify-pin)
    # =========================================================================

    def check_pin_rate_limit(self, user_id: str, max_attempts: int = 3, window_minutes: int = 5) -> None:
        """Vérifie si l'utilisateur n'est pas bloqué après trop de tentatives PIN infructueuses."""
        failures = self.store.get_failures(f"pin_{user_id}")
        if failures >= max_attempts:
            logger.warning(f"[SECURITY PIN LOCKOUT] User {user_id} a dépassé {max_attempts} échecs PIN.")
            raise HTTPException(
                status_code=429,
                detail=f"Trop de tentatives de code PIN erronées. Compte temporairement verrouillé pour {window_minutes} minutes."
            )

    def record_pin_failure(self, user_id: str, window_minutes: int = 5) -> None:
        """Enregistre un échec de PIN."""
        self.store.record_failure(f"pin_{user_id}", window_seconds=window_minutes * 60)

    def reset_pin_failures(self, user_id: str) -> None:
        """Réinitialise les échecs après un code PIN valide."""
        self.store.reset_failures(f"pin_{user_id}")

    # =========================================================================
    # 3. PROTECTION BRUTE-FORCE LOGIN (/auth/login)
    # =========================================================================

    def check_login_rate_limit(self, identifier: str, max_attempts: int = 5, window_minutes: int = 5) -> None:
        """Vérifie si un email / IP n'est pas temporairement bloqué après trop d'échecs de mot de passe."""
        clean_id = identifier.strip().lower()
        failures = self.store.get_failures(f"login_{clean_id}")
        if failures >= max_attempts:
            logger.warning(f"[SECURITY LOGIN LOCKOUT] Trop de tentatives de connexion échouées pour {clean_id}.")
            raise HTTPException(
                status_code=429,
                detail=f"Trop de tentatives de connexion échouées. Compte temporairement bloqué pour {window_minutes} minutes."
            )

    def record_login_failure(self, identifier: str, window_minutes: int = 5) -> None:
        clean_id = identifier.strip().lower()
        self.store.record_failure(f"login_{clean_id}", window_seconds=window_minutes * 60)

    def reset_login_failures(self, identifier: str) -> None:
        clean_id = identifier.strip().lower()
        self.store.reset_failures(f"login_{clean_id}")

    # =========================================================================
    # 4. ANTI-FLOOD SUR LES CONFIRMATIONS FINANCIÈRES (/sika/agent/confirm)
    # =========================================================================

    def check_confirm_rate_limit(self, user_id: str, max_per_second: int = 5) -> None:
        """Empêche le spam / flood abusif d'appels de confirmation par seconde."""
        allowed = self.store.check_rate_limit(f"confirm_{user_id}", max_requests=max_per_second, window_seconds=1)
        if not allowed:
            logger.warning(f"[SECURITY FLOOD REJECT] User {user_id} envoie trop de requêtes de confirmation simultanées.")
            raise HTTPException(
                status_code=429,
                detail="Trop de requêtes financières simultanées. Veuillez patienter un instant."
            )

    def check_ai_rate_limit(self, user_id: str, max_requests: int = 20, window_minutes: int = 1) -> None:
        """Protège les endpoints IA contre le spam pour éviter l'explosion des coûts de l'API externe."""
        allowed = self.store.check_rate_limit(f"ai_chat_{user_id}", max_requests=max_requests, window_seconds=window_minutes * 60)
        if not allowed:
            logger.warning(f"[SECURITY AI SPAM] User {user_id} a dépassé la limite d'usage de l'IA.")
            raise HTTPException(
                status_code=429,
                detail="Trop de messages envoyés à l'assistant. Veuillez patienter un moment avant de réessayer."
            )

    # =========================================================================
    # 5. GESTION DES OTP (MOT DE PASSE OUBLIÉ)
    # =========================================================================

    def store_otp(self, email: str, otp: str, expire_seconds: int = 900) -> None:
        self.store.store_otp(email, otp, expire_seconds)

    def verify_otp(self, email: str, otp: str) -> bool:
        return self.store.verify_otp(email, otp)

    def clear_otp(self, email: str) -> None:
        self.store.clear_otp(email)


# Singleton
security_rate_limiter = SecurityRateLimiter()
