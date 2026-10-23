# pyrefly: ignore [missing-import]
import pytest
from datetime import datetime, timezone, timedelta
# pyrefly: ignore [missing-import]
from fastapi.testclient import TestClient
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.sika_action import SikaActionModel
from app.services.auth_service import oauth2_auth_service
from app.routes import perception_router

client = TestClient(app)

from app.services.security_rate_limiter import security_rate_limiter
from app.models import UserModel, ConnectedWalletModel

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
def setup_test_db():
    """Initialise et nettoie la base de données et les caches avant chaque test."""
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


def create_jwt_header(user_id: int, email: str = "user@sika.app", expired: bool = False) -> dict:
    with Session(engine) as db:
        if not db.query(UserModel).filter(UserModel.id == user_id).first():
            db.add(UserModel(
                id=user_id,
                full_name=f"User {user_id}",
                email=f"user_{user_id}_{email}",
                password_hash="hash",
                auth_provider="email"
            ))
            db.commit()
    exp_delta = timedelta(hours=-1) if expired else timedelta(hours=1)
    token = oauth2_auth_service.create_access_token(
        user_data={"id": user_id, "email": email, "name": f"User {user_id}"},
        expires_delta=exp_delta
    )
    return {"Authorization": f"Bearer {token}"}


def test_missing_jwt_cannot_access_protected_resources():
    """Vérifie que les requêtes sans JWT sont systématiquement rejetées (HTTP 401)."""
    assert client.get("/api/v1/sika/auth/me").status_code == 401
    chk = "chk_" + "a" * 24
    assert client.post(f"/api/v1/paypal/checkouts/{chk}/confirm", json={"details_hash": "0" * 64}).status_code == 401
    assert client.post(f"/api/v1/paypal/checkouts/{chk}/capture").status_code == 401
    assert client.post(f"/api/v1/paypal/checkouts/{chk}/cancel").status_code == 401
    assert client.get("/api/v1/paypal/checkouts").status_code == 401
    assert client.post("/api/v1/perception/sms", json={"text": "SMS"}).status_code == 401
    assert client.get("/api/v1/perception/logs").status_code == 401


def test_expired_jwt_cannot_access_protected_resources():
    """Vérifie qu'un JWT expiré est rejeté avec HTTP 401."""
    expired_header = create_jwt_header(101, expired=True)
    assert client.get("/api/v1/sika/auth/me", headers=expired_header).status_code == 401
    assert client.post("/api/v1/paypal/checkouts/chk_" + "a" * 24 + "/capture", headers=expired_header).status_code == 401
    assert client.get("/api/v1/paypal/checkouts", headers=expired_header).status_code == 401


def test_invalid_jwt_cannot_access_protected_resources():
    """Vérifie qu'un JWT altéré ou malformé est rejeté avec HTTP 401."""
    invalid_header = {"Authorization": "Bearer fake.token.signature"}
    assert client.get("/api/v1/sika/auth/me", headers=invalid_header).status_code == 401
    assert client.post("/api/v1/sika/agent/process", json={"query": "Solde"}, headers=invalid_header).status_code == 401








def test_perception_routes_enforce_jwt_and_user_isolation():
    """Vérifie que le moteur de perception isole strictement les logs et modifications de solde par utilisateur."""
    h_user_a = create_jwt_header(user_id=101, email="userA@sika.app")
    h_user_b = create_jwt_header(user_id=202, email="userB@sika.app")

    with Session(engine) as db:
        db.add(ConnectedWalletModel(
            user_id=101,
            provider="Wave",
            external_wallet_id="0101010101",
            connection_status="connected"
        ))
        db.add(ConnectedWalletModel(
            user_id=202,
            provider="Wave",
            external_wallet_id="0202020202",
            connection_status="connected"
        ))
        db.commit()

    # User A perçoit un SMS Wave indiquant un solde de 25 000 FCFA
    res_sms_a = client.post(
        "/api/v1/perception/sms",
        json={"text": "Vous avez recu 15 000 FCFA. Nouveau solde: 25 000 FCFA.", "sender": "WAVE"},
        headers=h_user_a
    )
    assert res_sms_a.status_code == 200
    assert res_sms_a.json()["updated_wallet"]["balance"] == 25000.0
    assert res_sms_a.json()["updated_wallet"]["user_id"] == "101"

    # Vérifier que le wallet de User B n'a ABSOLUMENT PAS été modifié
    with Session(engine) as db:
        w_b = db.query(ConnectedWalletModel).filter(ConnectedWalletModel.user_id == 202).first()
        assert w_b.external_wallet_id == "0202020202"

    # Vérifier l'isolation des logs de perception
    logs_a = client.get("/api/v1/perception/logs", headers=h_user_a).json()
    logs_b = client.get("/api/v1/perception/logs", headers=h_user_b).json()

    assert logs_a["count"] == 1
    assert logs_b["count"] == 0 # User B ne voit aucun log de User A
