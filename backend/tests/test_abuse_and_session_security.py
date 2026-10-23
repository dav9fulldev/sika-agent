# pyrefly: ignore [missing-import]
import pytest
from datetime import datetime, timezone, timedelta
# pyrefly: ignore [missing-import]
from fastapi import HTTPException
from fastapi.testclient import TestClient
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.sika_action import SikaActionModel
from app.services.auth_service import oauth2_auth_service
from app.services.security_rate_limiter import security_rate_limiter
from app.routes import perception_router

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


def create_auth_token(user_id: int = 101, email: str = "test@sika.app") -> str:
    with Session(engine) as db:
        if not db.query(UserModel).filter(UserModel.id == user_id).first():
            db.add(UserModel(
                id=user_id,
                full_name=f"User {user_id}",
                email=email,
                password_hash="hash",
                auth_provider="email"
            ))
            db.commit()
    return oauth2_auth_service.create_access_token(
        user_data={"id": user_id, "email": email, "name": f"User {user_id}"}
    )


# ============================================================================
# 1. CYCLE DE VIE JWT, LOGOUT & RÉVOCATION
# ============================================================================

def test_token_logout_revocation():
    """Vérifie qu'un jeton JWT révoqué après logout est immédiatement rejeté (HTTP 401)."""
    token = create_auth_token(101, "user101@sika.app")
    auth_header = {"Authorization": f"Bearer {token}"}

    # 1. Accès autorisé avec le jeton actif
    res_me = client.get("/api/v1/sika/auth/me", headers=auth_header)
    assert res_me.status_code == 200

    # 2. Déconnexion (Logout)
    res_logout = client.post("/api/v1/sika/auth/logout", headers=auth_header)
    assert res_logout.status_code == 200
    assert res_logout.json()["status"] == "LOGGED_OUT"

    # 3. Tentative de réutilisation du jeton révoqué -> HTTP 401 Rejeté
    res_me_after = client.get("/api/v1/sika/auth/me", headers=auth_header)
    assert res_me_after.status_code == 401

    # 4. Tentative d'accès aux routes SIKA Pay avec le jeton révoqué -> HTTP 401
    assert client.get("/api/v1/paypal/checkouts", headers=auth_header).status_code == 401
    assert client.post("/api/v1/paypal/checkouts", json={"sku": "SIKA-COURSE-EXCEL"}, headers=auth_header).status_code == 401








# ============================================================================
# 4. PROTECTION BRUTE-FORCE CONNEXION (/auth/login)
# ============================================================================

def test_brute_force_login_locks_after_5_failures():
    """Vérifie que 5 mots de passe erronés consécutifs bloquent l'adresse email (HTTP 429)."""
    email = "target.user@sika.app"

    # Enregistrer un utilisateur
    client.post("/api/v1/sika/auth/register", json={
        "name": "Target User",
        "email": email,
        "password": "CorrectPassword123!"
    })

    # 5 tentatives avec mauvais mot de passe
    for _ in range(5):
        res = client.post("/api/v1/sika/auth/login", json={"email": email, "password": "WrongPassword"})
        assert res.status_code in [400, 401]

    # 6ème tentative (même avec le bon mot de passe) -> Verrouillé temporairement HTTP 429
    res_locked = client.post("/api/v1/sika/auth/login", json={"email": email, "password": "CorrectPassword123!"})
    assert res_locked.status_code == 429
    assert "bloqué" in res_locked.json()["detail"].lower() or "verrouillé" in res_locked.json()["detail"].lower()


# ============================================================================
# 5. ANTI-FLOOD SUR LES CONFIRMATIONS FINANCIÈRES (/paypal/checkouts/{id}/confirm|capture)
# ============================================================================

def test_flood_confirm_requests_throttled():
    """Vérifie qu'un burst excessif de confirmations financières est régulé par un rate limit (HTTP 429)."""
    with pytest.raises(HTTPException) as exc_info:
        for _ in range(10):
            security_rate_limiter.check_confirm_rate_limit("101", max_per_second=5)
    assert exc_info.value.status_code == 429
