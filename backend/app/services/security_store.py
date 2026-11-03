import logging
import time
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, Set
from ..config import settings

logger = logging.getLogger("SecurityStore")


class BaseSecurityStore(ABC):
    """Interface abstraite pour le stockage de sécurité et rate limiting."""

    @abstractmethod
    def add_revoked_token(self, token_identifier: str, expire_seconds: int = 259200) -> None:
        """Ajoute un jeton ou un JTI à la liste de révocation."""
        pass

    @abstractmethod
    def is_token_revoked(self, token_identifier: str) -> bool:
        """Vérifie si un jeton ou un JTI est révoqué."""
        pass

    @abstractmethod
    def record_failure(self, key: str, window_seconds: int = 900) -> int:
        """Incrémente le compteur d'échecs pour une clé (ex: login, PIN, OTP)."""
        pass

    @abstractmethod
    def get_failures(self, key: str) -> int:
        """Retourne le nombre d'échecs actuels pour une clé."""
        pass

    @abstractmethod
    def reset_failures(self, key: str) -> None:
        """Réinitialise les échecs après un succès."""
        pass

    @abstractmethod
    def check_rate_limit(self, key: str, max_requests: int, window_seconds: int) -> bool:
        """Vérifie et incrémente une requête sous rate limit. Retourne True si autorisé, False si bloqué."""
        pass

    @abstractmethod
    def clear(self) -> None:
        """Nettoie le magasin (utile pour les tests)."""
        pass

    @abstractmethod
    def store_otp(self, email: str, otp: str, expire_seconds: int = 900) -> None:
        """Stocke un OTP temporaire."""
        pass

    @abstractmethod
    def verify_otp(self, email: str, otp: str) -> bool:
        """Vérifie si un OTP est valide."""
        pass

    @abstractmethod
    def clear_otp(self, email: str) -> None:
        """Supprime un OTP après usage."""
        pass


class InMemorySecurityStore(BaseSecurityStore):
    """Implémentation en mémoire pour le développement local et les tests."""

    def __init__(self):
        self._revoked_tokens: Dict[str, float] = {}  # identifier -> expiry timestamp
        self._failure_counts: Dict[str, Dict[str, Any]] = {}  # key -> {"count": int, "reset_at": float}
        self._rate_limits: Dict[str, list] = {}  # key -> [timestamps]

    def add_revoked_token(self, token_identifier: str, expire_seconds: int = 259200) -> None:
        self._cleanup()
        self._revoked_tokens[token_identifier] = time.time() + expire_seconds

    def is_token_revoked(self, token_identifier: str) -> bool:
        self._cleanup()
        return token_identifier in self._revoked_tokens

    def record_failure(self, key: str, window_seconds: int = 900) -> int:
        now = time.time()
        record = self._failure_counts.get(key)
        if not record or now > record["reset_at"]:
            record = {"count": 1, "reset_at": now + window_seconds}
        else:
            record["count"] += 1
            record["reset_at"] = now + window_seconds
        self._failure_counts[key] = record
        return record["count"]

    def get_failures(self, key: str) -> int:
        now = time.time()
        record = self._failure_counts.get(key)
        if not record or now > record["reset_at"]:
            return 0
        return record["count"]

    def reset_failures(self, key: str) -> None:
        self._failure_counts.pop(key, None)

    def check_rate_limit(self, key: str, max_requests: int, window_seconds: int) -> bool:
        now = time.time()
        window_start = now - window_seconds
        timestamps = self._rate_limits.get(key, [])
        valid_timestamps = [t for t in timestamps if t > window_start]

        if len(valid_timestamps) >= max_requests:
            self._rate_limits[key] = valid_timestamps
            return False

        valid_timestamps.append(now)
        self._rate_limits[key] = valid_timestamps
        return True

    def clear(self) -> None:
        self._revoked_tokens.clear()
        self._failure_counts.clear()
        self._rate_limits.clear()
        if hasattr(self, '_otps'):
            self._otps.clear()

    def store_otp(self, email: str, otp: str, expire_seconds: int = 900) -> None:
        if not hasattr(self, '_otps'):
            self._otps = {}
        self._otps[email] = {"otp": otp, "expire_at": time.time() + expire_seconds}

    def verify_otp(self, email: str, otp: str) -> bool:
        if not hasattr(self, '_otps'):
            return False
        record = self._otps.get(email)
        if not record:
            return False
        if time.time() > record["expire_at"]:
            self.clear_otp(email)
            return False
        return record["otp"] == otp

    def clear_otp(self, email: str) -> None:
        if hasattr(self, '_otps'):
            self._otps.pop(email, None)

    def _cleanup(self) -> None:
        now = time.time()
        expired = [k for k, exp in self._revoked_tokens.items() if now > exp]
        for k in expired:
            self._revoked_tokens.pop(k, None)


class RedisSecurityStore(BaseSecurityStore):
    """Implémentation distribuée adossée à Redis pour la production multi-instance."""

    def __init__(self, redis_url: str):
        # pyrefly: ignore [missing-import]
        import redis
        self._redis = redis.from_url(redis_url, decode_responses=True)
        # Vérification immédiate de la connectivité au démarrage
        self._redis.ping()
        logger.info(f"[REDIS STORE] Connecté avec succès au cluster Redis ({redis_url.split('@')[-1]}).")

    def add_revoked_token(self, token_identifier: str, expire_seconds: int = 259200) -> None:
        try:
            self._redis.setex(f"sika:revoked:{token_identifier}", expire_seconds, "1")
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur lors de l'ajout du jeton révoqué: {e}")

    def is_token_revoked(self, token_identifier: str) -> bool:
        try:
            return bool(self._redis.exists(f"sika:revoked:{token_identifier}"))
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur de vérification du jeton révoqué: {e}")
            return False

    def record_failure(self, key: str, window_seconds: int = 900) -> int:
        try:
            rkey = f"sika:failures:{key}"
            count = self._redis.incr(rkey)
            if count == 1:
                self._redis.expire(rkey, window_seconds)
            return count
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur d'enregistrement d'échec: {e}")
            return 1

    def get_failures(self, key: str) -> int:
        try:
            val = self._redis.get(f"sika:failures:{key}")
            return int(val) if val else 0
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur de lecture d'échecs: {e}")
            return 0

    def reset_failures(self, key: str) -> None:
        try:
            self._redis.delete(f"sika:failures:{key}")
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur de réinitialisation: {e}")

    def check_rate_limit(self, key: str, max_requests: int, window_seconds: int) -> bool:
        try:
            rkey = f"sika:ratelimit:{key}"
            count = self._redis.incr(rkey)
            if count == 1:
                self._redis.expire(rkey, window_seconds)
            return count <= max_requests
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur de vérification rate limit: {e}")
            return True

    def clear(self) -> None:
        try:
            keys = self._redis.keys("sika:*")
            if keys:
                self._redis.delete(*keys)
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur lors du nettoyage Redis: {e}")

    def store_otp(self, email: str, otp: str, expire_seconds: int = 900) -> None:
        try:
            self._redis.setex(f"sika:otp:{email}", expire_seconds, otp)
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur lors de l'ajout de l'OTP: {e}")

    def verify_otp(self, email: str, otp: str) -> bool:
        try:
            val = self._redis.get(f"sika:otp:{email}")
            return val == otp
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur de vérification OTP: {e}")
            return False

    def clear_otp(self, email: str) -> None:
        try:
            self._redis.delete(f"sika:otp:{email}")
        except Exception as e:
            logger.warning(f"[REDIS WARN] Erreur lors de la suppression de l'OTP: {e}")


class DatabaseSecurityStore(BaseSecurityStore):
    """Implémentation partagée adossée à PostgreSQL (table security_entries), sans serveur Redis.

    Les instances Cloud Run partagent la même base : révocations, échecs et limites restent cohérents
    entre instances et survivent aux redémarrages. Chaque mise à jour verrouille sa ligne (SELECT … FOR UPDATE).
    """

    def __init__(self, engine=None):
        from ..database import engine as default_engine
        from ..models.security_entry import SecurityEntryModel
        self._engine = engine or default_engine
        self._model = SecurityEntryModel

    @staticmethod
    def _key(kind: str, raw: str) -> str:
        import hashlib
        return f"{kind}:{hashlib.sha256(raw.encode()).hexdigest()}"

    @staticmethod
    def _now():
        from datetime import datetime, timezone
        return datetime.now(timezone.utc).replace(tzinfo=None)  # colonnes DateTime sans fuseau (UTC)

    def _live(self, db, key: str, lock: bool = False):
        query = db.query(self._model).filter(self._model.key == key)
        if lock:
            query = query.with_for_update()
        row = query.first()
        if row and row.expires_at <= self._now():
            db.delete(row)
            db.flush()
            return None
        return row

    def _increment(self, key: str, window_seconds: int, refresh_expiry: bool) -> int:
        from datetime import timedelta
        from sqlalchemy.exc import IntegrityError
        from sqlalchemy.orm import Session
        for _ in range(2):  # une seconde tentative si deux instances créent la même ligne en même temps
            with Session(self._engine) as db:
                row = self._live(db, key, lock=True)
                expiry = self._now() + timedelta(seconds=window_seconds)
                if row is None:
                    row = self._model(key=key, count=1, expires_at=expiry)
                    db.add(row)
                else:
                    row.count += 1
                    if refresh_expiry:
                        row.expires_at = expiry
                try:
                    db.commit()
                    return row.count
                except IntegrityError:
                    db.rollback()
        return 1

    def add_revoked_token(self, token_identifier: str, expire_seconds: int = 259200) -> None:
        from datetime import timedelta
        from sqlalchemy.orm import Session
        key = self._key("revoked", token_identifier)
        with Session(self._engine) as db:
            row = db.get(self._model, key)
            expiry = self._now() + timedelta(seconds=expire_seconds)
            if row:
                row.expires_at = max(row.expires_at, expiry)
            else:
                db.add(self._model(key=key, count=1, expires_at=expiry))
            db.commit()

    def is_token_revoked(self, token_identifier: str) -> bool:
        from sqlalchemy.orm import Session
        with Session(self._engine) as db:
            row = db.get(self._model, self._key("revoked", token_identifier))
            return bool(row and row.expires_at > self._now())

    def record_failure(self, key: str, window_seconds: int = 900) -> int:
        return self._increment(self._key("failures", key), window_seconds, refresh_expiry=True)

    def get_failures(self, key: str) -> int:
        from sqlalchemy.orm import Session
        with Session(self._engine) as db:
            row = db.get(self._model, self._key("failures", key))
            return row.count if row and row.expires_at > self._now() else 0

    def reset_failures(self, key: str) -> None:
        self._delete(self._key("failures", key))

    def check_rate_limit(self, key: str, max_requests: int, window_seconds: int) -> bool:
        # Fenêtre fixe, comme l'implémentation Redis (INCR + EXPIRE)
        return self._increment(self._key("rate", key), window_seconds, refresh_expiry=False) <= max_requests

    def clear(self) -> None:
        from sqlalchemy.orm import Session
        with Session(self._engine) as db:
            db.query(self._model).delete()
            db.commit()

    def store_otp(self, email: str, otp: str, expire_seconds: int = 900) -> None:
        import hashlib
        from datetime import timedelta
        from sqlalchemy.orm import Session
        key = self._key("otp", email)
        with Session(self._engine) as db:
            row = db.get(self._model, key) or self._model(key=key, count=0)
            row.value = hashlib.sha256(otp.encode()).hexdigest()
            row.expires_at = self._now() + timedelta(seconds=expire_seconds)
            db.merge(row)
            db.commit()

    def verify_otp(self, email: str, otp: str) -> bool:
        import hashlib
        import hmac
        from sqlalchemy.orm import Session
        with Session(self._engine) as db:
            row = db.get(self._model, self._key("otp", email))
            if not row or row.expires_at <= self._now() or not row.value:
                return False
            return hmac.compare_digest(row.value, hashlib.sha256(otp.encode()).hexdigest())

    def clear_otp(self, email: str) -> None:
        self._delete(self._key("otp", email))

    def _delete(self, key: str) -> None:
        from sqlalchemy.orm import Session
        with Session(self._engine) as db:
            db.query(self._model).filter(self._model.key == key).delete()
            db.commit()


def create_security_store(env: Optional[str] = None, redis_url: Optional[str] = None,
                          store_kind: Optional[str] = None) -> BaseSecurityStore:
    """Factory instanciant le store approprié selon la configuration de l'environnement."""
    current_env = (env or settings.ENV).lower().strip()
    target_redis_url = redis_url or settings.REDIS_URL

    if (store_kind or settings.SECURITY_STORE) == "database":
        # Table PostgreSQL partagée par toutes les instances : pas de serveur Redis à faire tourner
        return DatabaseSecurityStore()

    if current_env == "production":
        if not target_redis_url:
            raise RuntimeError(
                "[SECURITY FATAL] En production (ENV=production), REDIS_URL est obligatoire. "
                "L'application refuse de démarrer sans store distribué Redis."
            )
        try:
            return RedisSecurityStore(target_redis_url)
        except Exception as e:
            raise RuntimeError(
                f"[SECURITY FATAL] Impossible de se connecter à Redis en production ({e}). "
                f"Démarrage refusé pour préserver l'isolation et la sécurité multi-instance."
            ) from e

    # Environnement de développement ou test local
    if target_redis_url:
        try:
            return RedisSecurityStore(target_redis_url)
        except Exception as e:
            logger.warning(f"[SECURITY STORE DEV] Connexion Redis échouée ({e}). Bascule sur InMemorySecurityStore (autorisé en dev uniquement).")
    return InMemorySecurityStore()
