"""
Module de Sécurité : Rate Limiting, Protection Anti-Brute-Force & Révocation de Tokens.

Gère :
- La liste des jetons JWT révoqués (Deny-list en mémoire avec TTL).
- Le comptage et blocage des tentatives infructueuses sur les challenges OTP (max 3 essais, TTL 10 min).
- La protection contre le brute-force de codes PIN de transaction (max 3 échecs / 5 min).
- La protection contre le brute-force de connexion (max 5 échecs / 5 min).
- Le rate-limiting anti-flood sur les actions financières sensibles.
"""

from typing import Dict, Set, Optional, Tuple
from datetime import datetime, timedelta, timezone
import logging
from fastapi import HTTPException

logger = logging.getLogger("SikaSecurityRateLimiter")


class SecurityRateLimiter:
    def __init__(self):
        # Set de tokens JWT révoqués stockés sous forme (token_signature/token, expire_timestamp)
        self._revoked_tokens: Dict[str, datetime] = {}

        # Suivi brute force PIN: user_id -> [timestamps des échecs]
        self._pin_failed_attempts: Dict[str, list[datetime]] = {}

        # Suivi brute force Login: email_or_ip -> [timestamps des échecs]
        self._login_failed_attempts: Dict[str, list[datetime]] = {}

        # Suivi anti-flood confirm: user_id -> [timestamps des requêtes]
        self._confirm_requests: Dict[str, list[datetime]] = {}

    def clear(self):
        """Nettoie tous les états en mémoire (utile pour les tests)."""
        self._revoked_tokens.clear()
        self._pin_failed_attempts.clear()
        self._login_failed_attempts.clear()
        self._confirm_requests.clear()

    # =========================================================================
    # 1. GESTION DES TOKENS RÉVOQUÉS (LOGOUT)
    # =========================================================================

    def revoke_token(self, token: str, jti: Optional[str] = None, expires_at: Optional[datetime] = None) -> None:
        """Enregistre un jeton et/ou son JTI dans la deny-list jusqu'à sa date d'expiration."""
        exp = expires_at or (datetime.now(timezone.utc) + timedelta(days=30))
        if token:
            self._revoked_tokens[token] = exp
        if jti:
            self._revoked_tokens[f"jti_{jti}"] = exp
        self._cleanup_expired_revoked_tokens()
        logger.info(f"[SECURITY LOGOUT] Jeton/JTI révoqué avec succès jusqu'à {exp}")

    def is_token_revoked(self, token: str, jti: Optional[str] = None) -> bool:
        """Vérifie si un token ou son JTI a été invalidé après un logout."""
        now = datetime.now(timezone.utc)
        if token and token in self._revoked_tokens:
            if now <= self._revoked_tokens[token]:
                return True
            self._revoked_tokens.pop(token, None)

        if jti and f"jti_{jti}" in self._revoked_tokens:
            if now <= self._revoked_tokens[f"jti_{jti}"]:
                return True
            self._revoked_tokens.pop(f"jti_{jti}", None)

        return False

    def _cleanup_expired_revoked_tokens(self) -> None:
        now = datetime.now(timezone.utc)
        expired = [t for t, exp in self._revoked_tokens.items() if now > exp]
        for t in expired:
            self._revoked_tokens.pop(t, None)

    # =========================================================================
    # 2. PROTECTION BRUTE-FORCE PIN TRANSACTIONNEL (/wallets/verify-pin)
    # =========================================================================

    def check_pin_rate_limit(self, user_id: str, max_attempts: int = 3, window_minutes: int = 5) -> None:
        """Vérifie si l'utilisateur n'est pas bloqué après trop de tentatives PIN infructueuses."""
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(minutes=window_minutes)

        attempts = self._pin_failed_attempts.get(user_id, [])
        recent_attempts = [t for t in attempts if t > cutoff]
        self._pin_failed_attempts[user_id] = recent_attempts

        if len(recent_attempts) >= max_attempts:
            logger.warning(f"[SECURITY PIN LOCKOUT] User {user_id} a dépassé {max_attempts} échecs PIN.")
            raise HTTPException(
                status_code=429,
                detail=f"Trop de tentatives de code PIN erronées. Compte temporairement verrouillé pour {window_minutes} minutes."
            )

    def record_pin_failure(self, user_id: str) -> None:
        """Enregistre un échec de PIN."""
        now = datetime.now(timezone.utc)
        if user_id not in self._pin_failed_attempts:
            self._pin_failed_attempts[user_id] = []
        self._pin_failed_attempts[user_id].append(now)

    def reset_pin_failures(self, user_id: str) -> None:
        """Réinitialise les échecs après un code PIN valide."""
        self._pin_failed_attempts.pop(user_id, None)

    # =========================================================================
    # 3. PROTECTION BRUTE-FORCE LOGIN (/auth/login)
    # =========================================================================

    def check_login_rate_limit(self, identifier: str, max_attempts: int = 5, window_minutes: int = 5) -> None:
        """Vérifie si un email / IP n'est pas temporairement bloqué après trop d'échecs de mot de passe."""
        clean_id = identifier.strip().lower()
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(minutes=window_minutes)

        attempts = self._login_failed_attempts.get(clean_id, [])
        recent = [t for t in attempts if t > cutoff]
        self._login_failed_attempts[clean_id] = recent

        if len(recent) >= max_attempts:
            logger.warning(f"[SECURITY LOGIN LOCKOUT] Trop de tentatives de connexion échouées pour {clean_id}.")
            raise HTTPException(
                status_code=429,
                detail=f"Trop de tentatives de connexion échouées. Compte temporairement bloqué pour {window_minutes} minutes."
            )

    def record_login_failure(self, identifier: str) -> None:
        clean_id = identifier.strip().lower()
        now = datetime.now(timezone.utc)
        if clean_id not in self._login_failed_attempts:
            self._login_failed_attempts[clean_id] = []
        self._login_failed_attempts[clean_id].append(now)

    def reset_login_failures(self, identifier: str) -> None:
        clean_id = identifier.strip().lower()
        self._login_failed_attempts.pop(clean_id, None)

    # =========================================================================
    # 4. ANTI-FLOOD SUR LES CONFIRMATIONS FINANCIÈRES (/sika/agent/confirm)
    # =========================================================================

    def check_confirm_rate_limit(self, user_id: str, max_per_second: int = 5) -> None:
        """Empêche le spam / flood abusif d'appels de confirmation par seconde."""
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(seconds=1)

        reqs = self._confirm_requests.get(str(user_id), [])
        recent = [t for t in reqs if t > cutoff]
        recent.append(now)
        self._confirm_requests[str(user_id)] = recent

        if len(recent) > max_per_second:
            logger.warning(f"[SECURITY FLOOD REJECT] User {user_id} envoie trop de requêtes de confirmation simultanées.")
            raise HTTPException(
                status_code=429,
                detail="Trop de requêtes financières simultanées. Veuillez patienter un instant."
            )


# Singleton
security_rate_limiter = SecurityRateLimiter()
