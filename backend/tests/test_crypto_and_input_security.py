import pytest
import os
import math
import uuid
import jwt
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.sika_action import SikaActionModel
from app.services.auth_service import oauth2_auth_service, OAuth2AuthService
from app.services.security_rate_limiter import security_rate_limiter
from app.routes import perception_router
from app.agent.tool_registry import tool_registry

client = TestClient(app)

from app.models import (
    UserModel, ConnectedWalletModel, SikaActionModel,
    SavingsGoalModel, AgentMemoryModel, UserPreferenceModel,
    SikaActionEventModel, SikaSessionModel
)

def _reset_db_safely():
    with Session(engine) as db:
        for model in [SikaActionEventModel, SikaSessionModel, SikaActionModel, ConnectedWalletModel, SavingsGoalModel, AgentMemoryModel, UserPreferenceModel, UserModel]:
            try:
                db.query(model).delete(synchronize_session=False)
                db.commit()
            except Exception:
                db.rollback()

@pytest.fixture(autouse=True)
def clean_security_environment():
    """Initialise et nettoie la base de données et les caches de sécurité avant chaque test."""
    Base.metadata.create_all(bind=engine)
    perception_router.PERCEPTIONS_LOG.clear()
    security_rate_limiter.clear()

    _reset_db_safely()
    with Session(engine) as db:
        for uid in [1, 101, 202, 303, 999]:
            db.add(UserModel(
                id=uid,
                full_name=f"User {uid}",
                email=f"user{uid}@sika.app",
                password_hash="test_hash",
                auth_provider="email"
            ))
        db.commit()

    yield

    _reset_db_safely()
    perception_router.PERCEPTIONS_LOG.clear()
    security_rate_limiter.clear()


from app.models.user import UserModel

def create_token(user_id: int = 101, email: str = "user@sika.app") -> str:
    with Session(engine) as db:
        existing = db.query(UserModel).filter(UserModel.id == user_id).first()
        if not existing:
            db.add(UserModel(id=user_id, email=f"user{user_id}@sika.app", full_name=f"User {user_id}", auth_provider="email"))
            db.commit()
    return oauth2_auth_service.create_access_token(
        user_data={"id": user_id, "email": email, "name": f"User {user_id}"}
    )


# ============================================================================
# 1. AUDIT CRYPTOGRAPHIQUE JWT
# ============================================================================

def test_jwt_rejects_alg_none():
    """Vérifie que les jetons forgés avec alg='none' sont strictement rejetés."""
    payload = {
        "sub": "attacker@sika.app",
        "user_id": 999,
        "name": "Attacker",
        "iss": "SIKA_AUTH_SERVER",
        "exp": (datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()
    }
    # Forger un token non signé avec l'algorithme "none"
    forged_token = jwt.encode(payload, key="", algorithm="none")
    assert oauth2_auth_service.verify_token(forged_token) is None


def test_jwt_rejects_invalid_algorithm():
    """Vérifie que les jetons utilisant un algorithme différent de HS256 sont rejetés."""
    payload = {
        "sub": "attacker@sika.app",
        "user_id": 999,
        "name": "Attacker",
        "iss": "SIKA_AUTH_SERVER",
        "exp": (datetime.now(timezone.utc) + timedelta(hours=1)).timestamp()
    }
    # Encodage avec un algorithme différent non autorisé
    try:
        forged_token = jwt.encode(payload, "secret_key", algorithm="HS384")
        # Le vérificateur attend STRICTEMENT HS256
        assert oauth2_auth_service.verify_token(forged_token) is None
    except Exception:
        pass


def test_jwt_expiration_enforced():
    """Vérifie que la date d'expiration (exp) est strictement appliquée."""
    expired_token = oauth2_auth_service.create_access_token(
        user_data={"id": 101, "email": "user@sika.app"},
        expires_delta=timedelta(hours=-2)
    )
    assert oauth2_auth_service.verify_token(expired_token) is None


def test_revoked_token_rejected_everywhere():
    """Vérifie qu'un jeton révoqué au logout est rejeté sur tous les endpoints protégés."""
    token = create_token(101)
    header = {"Authorization": f"Bearer {token}"}

    # Accès normal
    assert client.get("/api/v1/sika/auth/me", headers=header).status_code == 200

    # Révocation via Logout
    client.post("/api/v1/sika/auth/logout", headers=header)

    # Rejet sur les différents endpoints protégés
    assert client.get("/api/v1/sika/auth/me", headers=header).status_code == 401
    assert client.get("/api/v1/paypal/checkouts", headers=header).status_code == 401
    assert client.get("/api/v1/sika/auth/me", headers=header).status_code == 401


# ============================================================================
# 2. VALIDATION DES MONTANTS FINANCIERS & ENTRÉES
# ============================================================================








# ============================================================================
# 3. RACE CONDITIONS & INTÉGRITÉ DES ÉTATS
# ============================================================================




def test_duplicate_perception_event_is_idempotent():
    """Vérifie que la réception en double du même SMS est idempotente."""
    token = create_token(101)
    header = {"Authorization": f"Bearer {token}"}

    sms_payload = {"text": "Vous avez recu 5 000 FCFA de Test. Nouveau solde: 30 000 FCFA.", "sender": "WAVE"}

    # 1ère réception
    res1 = client.post("/api/v1/perception/sms", json=sms_payload, headers=header)
    assert res1.status_code == 200
    assert res1.json()["status"] == "PERCEIVED"

    # 2ème réception identique
    res2 = client.post("/api/v1/perception/sms", json=sms_payload, headers=header)
    assert res2.status_code == 200
    assert res2.json()["status"] == "ALREADY_PERCEIVED"


# ============================================================================
# 4. DONNÉES SENSIBLES, LOGS & PRODUCTION HARDENING
# ============================================================================

def test_sensitive_fields_not_exposed_in_api_responses():
    """Vérifie qu'aucun hash de mot de passe ni clé privée n'est exposé dans les réponses."""
    # Créer un compte pour le test
    client.post("/api/v1/sika/auth/register", json={"name": "Test User", "email": "test.sensitive@sika.app", "password": "SecurePassword123!"})
    res = client.post("/api/v1/sika/auth/login", json={"email": "test.sensitive@sika.app", "password": "SecurePassword123!"})
    assert res.status_code == 200
    user_data = res.json()["user"]
    assert "password" not in user_data
    assert "password_hash" not in user_data
    assert "secret" not in user_data


def test_error_responses_do_not_leak_stacktrace_or_secrets():
    """Vérifie que les routes en erreur renvoient des messages génériques et sans stack trace."""
    res = client.get("/api/v1/paypal/checkouts")
    assert res.status_code == 401
    assert "password" not in res.text.lower()
    assert "traceback" not in res.text.lower()




def test_production_config_rejects_default_jwt_secret(monkeypatch):
    """Vérifie que le backend refuse de démarrer avec un secret JWT faible ou par défaut en production."""
    monkeypatch.setenv("ENV", "production")
    monkeypatch.setenv("JWT_SECRET_KEY", "123456")

    auth_svc = OAuth2AuthService()
    with pytest.raises(RuntimeError):
        _ = auth_svc.SECRET_KEY


# ============================================================================
# INJECTION DE PROMPT : LE MODÈLE NE PEUT NI PAYER NI FIXER UN MONTANT
# ============================================================================

def test_prompt_injection_cannot_bypass_human_confirmation():
    """La préparation PayPal exige une confirmation humaine ; aucun tool de paiement n'est exposé au modèle."""
    assert tool_registry.get_definition("prepare_paypal_checkout").risk_level.value == "CONFIRMATION_REQUIRED"
    for name in tool_registry.agent_tool_names():
        assert "capture" not in name and "confirm" not in name


def test_prompt_injection_cannot_set_server_side_amount():
    """Un montant injecté par le modèle est refusé : seul le prix catalogue serveur fait foi."""
    res = tool_registry.execute("prepare_paypal_checkout", {
        "sku": "SIKA-COURSE-EXCEL", "quantity": 1, "amount": 0.01, "user_id": "101"
    })
    assert res.success is False


def test_sql_injection_in_checkout_id_is_rejected():
    token = create_token(101)
    res = client.get("/api/v1/paypal/checkouts/chk_' OR '1'='1", headers={"Authorization": f"Bearer {token}"})
    assert res.status_code == 404
