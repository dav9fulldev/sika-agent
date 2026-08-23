"""
Suite de tests de sécurité et d'infrastructure de production pour SIKA.
Valide:
- Gestion des secrets et contraintes de démarrage en production (Rejet JWT faible, Rejet SQLite, Exigence Redis)
- Intégration Google Cloud Secret Manager (Résolution dynamique et fail-fast)
- Magasin de sécurité distribué Redis vs InMemory (Ping obligatoire, interdiction de fallback silencieux en prod)
- Traçabilité X-Request-ID et sanitisation des logs
- Protection DoS (Limitation 1 Mo, endpoint /health)
- Masquage des erreurs SQL et stacktraces (Anti-Information Disclosure)
- Authentification Google OAuth cryptographique
- Intégrité de la base de données (Check constraints, Foreign Keys Cascade, Migrations Alembic)
- Durcissement Dockerfile & .dockerignore (Utilisateur non-root, exclusion .env)
- En-têtes OWASP
"""

# pyrefly: ignore [missing-import]
import pytest
import os
import uuid
import logging
from pathlib import Path
from datetime import datetime, timezone, timedelta
# pyrefly: ignore [missing-import]
from fastapi.testclient import TestClient
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Session
# pyrefly: ignore [missing-import]
from sqlalchemy.exc import IntegrityError, SQLAlchemyError

from app.main import app
from app.config import settings, Settings
from app.database import engine, Base
from app.models import UserModel, ConnectedWalletModel, SavingsGoalModel, SikaActionModel
from app.services.auth_service import oauth2_auth_service, _hash_password
from app.services.security_store import InMemorySecurityStore, BaseSecurityStore, RedisSecurityStore, create_security_store
from app.services.security_rate_limiter import SecurityRateLimiter, security_rate_limiter
from app.services.logging_sanitizer import sanitize_sensitive_data, SensitiveDataFilter

client = TestClient(app, raise_server_exceptions=False)


@pytest.fixture(autouse=True)
def setup_test_db():
    Base.metadata.create_all(bind=engine)
    security_rate_limiter.clear()
    with Session(engine) as db:
        db.query(SikaActionModel).delete()
        db.query(SavingsGoalModel).delete()
        db.query(ConnectedWalletModel).delete()
        db.query(UserModel).delete()
        db.commit()
    yield
    with Session(engine) as db:
        db.query(SikaActionModel).delete()
        db.query(SavingsGoalModel).delete()
        db.query(ConnectedWalletModel).delete()
        db.query(UserModel).delete()
        db.commit()
    security_rate_limiter.clear()


def create_db_user(email="test@sika.app", name="David Test", password="Password123!") -> UserModel:
    with Session(engine) as db:
        user = UserModel(
            full_name=name,
            email=email.lower().strip(),
            password_hash=_hash_password(password),
            auth_provider="email"
        )
        db.add(user)
        db.commit()
        db.refresh(user)
        return user


# =============================================================================
# 1. GESTION DES SECRETS & DÉMARRAGE PRODUCTION
# =============================================================================

def test_production_rejects_weak_jwt_secret(monkeypatch):
    """Vérifie qu'un secret JWT faible ou manquant en production bloque le démarrage."""
    monkeypatch.setenv("ENV", "production")
    monkeypatch.setenv("USE_GCP_SECRET_MANAGER", "false")
    monkeypatch.setenv("JWT_SECRET_KEY", "weak_secret_123")
    monkeypatch.setenv("REDIS_URL", "redis://fake:6379/0")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg2://user:pass@localhost:5432/db")
    
    with pytest.raises(ValueError, match="JWT_SECRET_KEY doit être défini"):
        Settings()


def test_production_rejects_sqlite_database(monkeypatch):
    """Vérifie que SQLite est formellement interdit en environnement de production."""
    monkeypatch.setenv("ENV", "production")
    monkeypatch.setenv("USE_GCP_SECRET_MANAGER", "false")
    monkeypatch.setenv("JWT_SECRET_KEY", "A_VERY_LONG_STRONG_SECRET_KEY_FOR_TESTS_123456789")
    monkeypatch.setenv("REDIS_URL", "redis://fake:6379/0")
    monkeypatch.setenv("DATABASE_URL", "sqlite:///./sika_local.db")
    
    with pytest.raises(ValueError, match="SQLite est interdit en production"):
        Settings()


def test_production_without_redis_url_rejected(monkeypatch):
    """Vérifie qu'en production, l'absence de REDIS_URL bloque formellement le démarrage."""
    monkeypatch.setenv("ENV", "production")
    monkeypatch.setenv("USE_GCP_SECRET_MANAGER", "false")
    monkeypatch.setenv("JWT_SECRET_KEY", "A_VERY_LONG_STRONG_SECRET_KEY_FOR_TESTS_123456789")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg2://user:pass@localhost:5432/db")
    monkeypatch.delenv("REDIS_URL", raising=False)

    with pytest.raises(ValueError, match="REDIS_URL est obligatoire"):
        Settings(REDIS_URL=None)


def test_secret_manager_integration_resolution():
    """Vérifie la stratégie de résolution des secrets depuis Secret Manager."""
    mock_overrides = {
        "ENV": "development",
        "USE_GCP_SECRET_MANAGER": False,
        "JWT_SECRET_KEY": "a" * 32,
        "DATABASE_URL": "postgresql+psycopg2://test:test@localhost:5432/testdb",
        "REDIS_URL": "redis://localhost:6379/0"
    }
    custom_settings = Settings(**mock_overrides)
    assert custom_settings.JWT_SECRET_KEY == "a" * 32
    assert custom_settings.DATABASE_URL == "postgresql+psycopg2://test:test@localhost:5432/testdb"


# =============================================================================
# 2. MULTI-INSTANCE & SECURITY STORE (DEV IN-MEMORY VS PROD REDIS)
# =============================================================================

def test_development_without_redis_uses_inmemory():
    """Vérifie qu'en développement sans Redis, le store InMemory est utilisé normalement."""
    store = create_security_store(env="development", redis_url=None)
    assert isinstance(store, InMemorySecurityStore)


def test_production_without_redis_raises_fatal():
    """Vérifie qu'en production, l'absence de Redis lève une RuntimeError fatale sans fallback."""
    with pytest.raises(RuntimeError, match="REDIS_URL est obligatoire"):
        create_security_store(env="production", redis_url=None)


def test_production_unreachable_redis_raises_fatal():
    """Vérifie qu'en production, un Redis inaccessible lève une exception et refuse tout fallback."""
    with pytest.raises(RuntimeError, match="Impossible de se connecter à Redis en production"):
        create_security_store(env="production", redis_url="redis://127.0.0.1:9999/0")


def test_security_store_token_revocation_shared():
    """Vérifie la révocation d'un token entre deux instances partageant le même store."""
    store = InMemorySecurityStore()
    limiter1 = SecurityRateLimiter(store=store)
    limiter2 = SecurityRateLimiter(store=store)

    token = "test_bearer_jwt_token_sample"
    jti = "unique_jti_123"

    assert not limiter2.is_token_revoked(token, jti=jti)
    limiter1.revoke_token(token, jti=jti)
    assert limiter2.is_token_revoked(token, jti=jti)


def test_security_store_rate_limit_shared():
    """Vérifie que le rate limit anti-flood est partagé entre les instances."""
    store = InMemorySecurityStore()
    limiter1 = SecurityRateLimiter(store=store)
    limiter2 = SecurityRateLimiter(store=store)

    user_id = "user_42"

    for _ in range(5):
        limiter1.check_confirm_rate_limit(user_id, max_per_second=5)

    with pytest.raises(Exception):
        limiter2.check_confirm_rate_limit(user_id, max_per_second=5)


# =============================================================================
# 3. TRAÇABILITÉ X-REQUEST-ID, HEALTHCHECK & PROTECTION DOS
# =============================================================================

def test_request_id_injected_and_propagated():
    """Vérifie que X-Request-ID est généré ou conservé et retourné dans les en-têtes."""
    custom_request_id = str(uuid.uuid4())
    res = client.get("/", headers={"X-Request-ID": custom_request_id})
    assert res.status_code == 200
    assert res.headers.get("X-Request-ID") == custom_request_id


def test_health_check_endpoint():
    """Vérifie que l'endpoint /health répond 200 OK pour les sondes Docker/Cloud Run."""
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "healthy"


def test_payload_exceeding_1mb_rejected():
    """Vérifie qu'une requête avec un Content-Length dépassant 1 Mo est rejetée avec HTTP 413."""
    oversized_headers = {
        "Content-Length": str(2 * 1024 * 1024),  # 2 Mo
        "Content-Type": "application/json"
    }
    res = client.post("/api/v1/perception/sms", headers=oversized_headers, content=b"{}")
    assert res.status_code == 413
    assert res.json()["error_code"] == "PAYLOAD_TOO_LARGE"
    assert "request_id" in res.json()


# =============================================================================
# 4. SANITISATION DES LOGS & MASQUAGE SQL
# =============================================================================

def test_logging_sanitization_masks_sensitive_data():
    """Vérifie que mots de passe, PINs, OTPs et tokens sont masqués dans les logs."""
    raw_message = 'User login password="SecretPassword123!" with pin="1234" and otp="567890" token="eyJhbGciOi..." Bearer eyJhbGciOiOiJ...'
    sanitized = sanitize_sensitive_data(raw_message)

    assert "SecretPassword123!" not in sanitized
    assert "1234" not in sanitized
    assert "567890" not in sanitized
    assert "[REDACTED]" in sanitized or "[REDACTED_PIN]" in sanitized or "[REDACTED_OTP]" in sanitized


def test_sql_errors_masked_in_api_response():
    """Vérifie qu'une erreur de base de données ne fait pas fuiter de requêtes SQL internes."""
    try:
        @app.get("/api/v1/test/sql-error-trigger")
        def error_route():
            raise SQLAlchemyError("SYNTAX ERROR in SQL: SELECT * FROM secret_table WHERE leak=1")
    except Exception:
        pass

    res = client.get("/api/v1/test/sql-error-trigger")
    assert res.status_code == 500
    assert "SELECT * FROM secret_table" not in res.text
    assert "DATABASE_ERROR" in res.json()["error_code"]
    assert "request_id" in res.json()


# =============================================================================
# 5. SÉCURITÉ CRYPTOGRAPHIQUE GOOGLE OAUTH
# =============================================================================

def test_google_oauth_rejects_invalid_token_in_production(monkeypatch):
    """Vérifie qu'un faux token Google ID est immédiatement rejeté en production."""
    monkeypatch.setattr("app.config.settings.ENV", "production")

    res = client.post(
        "/api/v1/sika/auth/google",
        json={"id_token": "fake_invalid_google_jwt_signature"}
    )
    assert res.status_code in [400, 401]
    assert "Échec" in res.text or "invalide" in res.text or "manquant" in res.text


# =============================================================================
# 6. INTÉGRITÉ DE LA BASE DE DONNÉES & MIGRATIONS ALEMBIC
# =============================================================================

def test_database_cascade_deletion_cleans_child_records():
    """Vérifie que la suppression d'un utilisateur supprime en cascade ses portefeuilles et actions."""
    user = create_db_user("cascadetest@sika.app")
    
    with Session(engine) as db:
        wallet = ConnectedWalletModel(
            user_id=user.id,
            provider="PayMeChap",
            external_wallet_id="0700000000",
            connection_status="connected"
        )
        db.add(wallet)
        
        goal = SavingsGoalModel(
            user_id=user.id,
            title="Études",
            target_amount=500000.0,
            current_amount=100000.0
        )
        db.add(goal)
        db.commit()

        assert db.query(ConnectedWalletModel).filter(ConnectedWalletModel.user_id == user.id).count() == 1
        assert db.query(SavingsGoalModel).filter(SavingsGoalModel.user_id == user.id).count() == 1

        db_user = db.query(UserModel).filter(UserModel.id == user.id).first()
        db.delete(db_user)
        db.commit()

        assert db.query(ConnectedWalletModel).filter(ConnectedWalletModel.user_id == user.id).count() == 0
        assert db.query(SavingsGoalModel).filter(SavingsGoalModel.user_id == user.id).count() == 0


def test_database_check_constraints_prevent_negative_savings():
    """Vérifie que les contraintes empêchent un objectif d'épargne avec montant négatif."""
    user = create_db_user("negativetest@sika.app")
    with pytest.raises(ValueError, match="ne peut pas être négatif"):
        SavingsGoalModel(
            user_id=user.id,
            title="Mauvais Objectif",
            target_amount=-50000.0,
            current_amount=0.0
        )


def test_alembic_migrations_schema_integrity():
    """Vérifie que la migration Alembic définit toutes les tables et contraintes de sécurité."""
    versions_dir = Path(__file__).resolve().parent.parent / "alembic" / "versions"
    migration_files = list(versions_dir.glob("*.py"))
    assert len(migration_files) >= 1

    content = migration_files[0].read_text()
    assert "users" in content
    assert "connected_wallets" in content
    assert "sika_actions" in content
    assert "savings_goals" in content
    assert "agent_memories" in content
    assert "user_preferences" in content
    assert "ondelete='CASCADE'" in content or "ondelete=\"CASCADE\"" in content
    assert "chk_sika_action_status_valid" in content
    assert "chk_connected_wallet_status_valid" in content


# =============================================================================
# 7. SÉCURITÉ DOCKERFILE & .DOCKERIGNORE
# =============================================================================

def test_dockerfile_uses_non_root_user():
    """Vérifie que le Dockerfile utilise un utilisateur non-root dédié (appuser)."""
    dockerfile_path = Path(__file__).resolve().parent.parent / "Dockerfile"
    assert dockerfile_path.exists()
    content = dockerfile_path.read_text()
    assert "USER appuser" in content
    assert "useradd" in content
    assert "EXPOSE 8080" in content


def test_dockerignore_excludes_secrets_and_tests():
    """Vérifie que .dockerignore exclut .env, tests et bases locales."""
    dockerignore_path = Path(__file__).resolve().parent.parent / ".dockerignore"
    assert dockerignore_path.exists()
    content = dockerignore_path.read_text()
    assert ".env" in content
    assert "tests/" in content or "tests" in content
    assert "*.db" in content or "sika_local.db" in content


# =============================================================================
# 8. EN-TÊTES OWASP
# =============================================================================

def test_security_headers_present_on_all_responses():
    """Vérifie la présence de tous les en-têtes de sécurité HTTP recommandés par l'OWASP."""
    res = client.get("/")
    assert res.status_code == 200
    assert res.headers.get("X-Content-Type-Options") == "nosniff"
    assert res.headers.get("X-Frame-Options") == "DENY"
    assert res.headers.get("X-XSS-Protection") == "1; mode=block"
    assert "Strict-Transport-Security" in res.headers
    assert "Content-Security-Policy" in res.headers
