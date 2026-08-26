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
from app.routes import wallet_router, perception_router
from app.agent.orchestrator import sika_orchestrator

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
    wallet_router.CONNECTED_USER_WALLETS.clear()
    perception_router.PERCEPTIONS_LOG.clear()
    sika_orchestrator.action_store.clear()
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
    wallet_router.CONNECTED_USER_WALLETS.clear()
    perception_router.PERCEPTIONS_LOG.clear()
    sika_orchestrator.action_store.clear()
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

    # 4. Tentative d'accès aux routes wallets avec le jeton révoqué -> HTTP 401
    assert client.get("/api/v1/wallets/me", headers=auth_header).status_code == 401
    assert client.post("/api/v1/wallets/sync", headers=auth_header).status_code == 401


# ============================================================================
# 2. PROTECTION BRUTE-FORCE & SÉCURITÉ OTP (/wallets/verify-otp)
# ============================================================================

def test_brute_force_otp_blocks_after_3_attempts(monkeypatch):
    """Vérifie que 3 tentatives OTP erronées invalident la session et bloquent les essais (HTTP 429)."""
    monkeypatch.setattr(
        "app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.initiate_otp_challenge",
        lambda account: {"success": True, "message": "OTP envoyé"}
    )
    monkeypatch.setattr(
        "app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.verify_otp_code",
        lambda account, code: {"success": False}
    )

    token = create_auth_token(101, "user101@sika.app")
    header = {"Authorization": f"Bearer {token}"}

    # 1. Initier un challenge OTP
    conn_res = client.post(
        "/api/v1/wallets/connect",
        json={"provider": "PayMeChap", "account_number": "0799053977"},
        headers=header
    )
    assert conn_res.status_code == 200
    session_id = conn_res.json()["session_id"]

    # 2. Tentative 1 incorrecte -> 400 (1/3)
    res1 = client.post("/api/v1/wallets/verify-otp", json={"session_id": session_id, "otp_code": "000001", "provider": "PayMeChap"}, headers=header)
    assert res1.status_code == 400
    assert "1/3" in res1.json()["detail"]

    # 3. Tentative 2 incorrecte -> 400 (2/3)
    res2 = client.post("/api/v1/wallets/verify-otp", json={"session_id": session_id, "otp_code": "000002", "provider": "PayMeChap"}, headers=header)
    assert res2.status_code == 400
    assert "2/3" in res2.json()["detail"]

    # 4. Tentative 3 incorrecte -> 429 (Verrouillage & Destruction)
    res3 = client.post("/api/v1/wallets/verify-otp", json={"session_id": session_id, "otp_code": "000003", "provider": "PayMeChap"}, headers=header)
    assert res3.status_code == 429

    # 5. Tentative 4 -> Session détruite (400 introuvable)
    res4 = client.post("/api/v1/wallets/verify-otp", json={"session_id": session_id, "otp_code": "123456", "provider": "PayMeChap"}, headers=header)
    assert res4.status_code == 400


def test_otp_replay_attack_prevented():
    """Anti-Replay : Un code OTP consommé avec succès ne peut JAMAIS être réutilisé."""
    token = create_auth_token(101, "user101@sika.app")
    header = {"Authorization": f"Bearer {token}"}

    conn_res = client.post(
        "/api/v1/wallets/connect",
        json={"provider": "Wave", "account_number": "0701020304"},
        headers=header
    )
    session_id = conn_res.json()["session_id"]

    # Première validation avec succès
    res1 = client.post(
        "/api/v1/wallets/verify-otp",
        json={"session_id": session_id, "otp_code": "123456", "provider": "Wave"},
        headers=header
    )
    assert res1.status_code == 200

    # Tentative de rejouer la même requête avec la même session -> 400 (déjà consommée)
    res2 = client.post(
        "/api/v1/wallets/verify-otp",
        json={"session_id": session_id, "otp_code": "123456", "provider": "Wave"},
        headers=header
    )
    assert res2.status_code == 400
    assert "déjà consommée" in res2.json()["detail"].lower() or "introuvable" in res2.json()["detail"].lower()


def test_expired_otp_session_rejected():
    """TTL Test : Une session OTP expirée (>10 minutes) est rejetée."""
    token = create_auth_token(101, "user101@sika.app")
    header = {"Authorization": f"Bearer {token}"}

    old_dt = datetime.now(timezone.utc) - timedelta(minutes=15)
    session_id = "sess_expired_test_001"
    wallet_router.PENDING_OTP_SESSIONS[session_id] = {
        "session_id": session_id,
        "user_id": "101",
        "provider": "Wave",
        "account_number": "0701020304",
        "created_at_dt": old_dt
    }

    res = client.post(
        "/api/v1/wallets/verify-otp",
        json={"session_id": session_id, "otp_code": "123456", "provider": "Wave"},
        headers=header
    )
    assert res.status_code == 400
    assert "expirée" in res.json()["detail"].lower()


# ============================================================================
# 3. PROTECTION BRUTE-FORCE PIN TRANSACTIONNEL (/wallets/verify-pin)
# ============================================================================

def test_brute_force_pin_locks_account_after_3_failures(monkeypatch):
    """Vérifie que 3 échecs consécutifs de code PIN verrouillent le compte temporairement (HTTP 429)."""
    monkeypatch.setattr(
        "app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.verify_transaction_pin",
        lambda acc, pin: {"success": False, "valid": False, "message": "Code PIN incorrect"}
    )

    token = create_auth_token(101, "user101@sika.app")
    header = {"Authorization": f"Bearer {token}"}

    # 3 échecs consécutifs
    for i in range(3):
        res = client.post("/api/v1/wallets/verify-pin", json={"pin": f"000{i}", "account_number": "0799053977"}, headers=header)
        assert res.status_code == 401

    # 4ème tentative -> Blocage temporaire HTTP 429
    res_locked = client.post("/api/v1/wallets/verify-pin", json={"pin": "1234", "account_number": "0799053977"}, headers=header)
    assert res_locked.status_code == 429
    assert "verrouillé" in res_locked.json()["detail"].lower()


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
# 5. ANTI-FLOOD SUR LES CONFIRMATIONS FINANCIÈRES (/sika/agent/confirm)
# ============================================================================

def test_flood_confirm_requests_throttled():
    """Vérifie qu'un burst excessif de confirmations financières est régulé par un rate limit (HTTP 429)."""
    with pytest.raises(HTTPException) as exc_info:
        for _ in range(10):
            security_rate_limiter.check_confirm_rate_limit("101", max_per_second=5)
    assert exc_info.value.status_code == 429
