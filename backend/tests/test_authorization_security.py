import pytest
from datetime import datetime, timezone, timedelta
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.sika_action import SikaActionModel
from app.services.auth_service import oauth2_auth_service
from app.routes import wallet_router, perception_router
from app.agent.orchestrator import sika_orchestrator

client = TestClient(app)

from app.services.security_rate_limiter import security_rate_limiter

@pytest.fixture(autouse=True)
def setup_test_db():
    """Initialise et nettoie la base de données et les caches avant chaque test."""
    Base.metadata.create_all(bind=engine)
    wallet_router.CONNECTED_USER_WALLETS.clear()
    wallet_router.PENDING_OTP_SESSIONS.clear()
    perception_router.PERCEPTIONS_LOG.clear()
    sika_orchestrator.action_store.clear()
    security_rate_limiter.clear()

    with Session(engine) as db:
        db.query(SikaActionModel).delete()
        db.commit()

    yield

    with Session(engine) as db:
        db.query(SikaActionModel).delete()
        db.commit()
    wallet_router.CONNECTED_USER_WALLETS.clear()
    wallet_router.PENDING_OTP_SESSIONS.clear()
    perception_router.PERCEPTIONS_LOG.clear()
    sika_orchestrator.action_store.clear()
    security_rate_limiter.clear()


def create_jwt_header(user_id: int, email: str = "user@sika.app", expired: bool = False) -> dict:
    exp_delta = timedelta(hours=-1) if expired else timedelta(hours=1)
    token = oauth2_auth_service.create_access_token(
        user_data={"id": user_id, "email": email, "name": f"User {user_id}"},
        expires_delta=exp_delta
    )
    return {"Authorization": f"Bearer {token}"}


def test_missing_jwt_cannot_access_protected_resources():
    """Vérifie que les requêtes sans JWT sont systématiquement rejetées (HTTP 401)."""
    assert client.get("/api/v1/sika/auth/me").status_code == 401
    assert client.post("/api/v1/sika/agent/confirm", json={"action_id": "act_1"}).status_code == 401
    assert client.post("/api/v1/sika/agent/cancel", json={"action_id": "act_1"}).status_code == 401
    assert client.post("/api/v1/sika/actions/act_1/reconcile").status_code == 401
    assert client.post("/api/v1/sika/actions/cleanup-stale").status_code == 401
    assert client.get("/api/v1/wallets/me").status_code == 401
    assert client.post("/api/v1/perception/sms", json={"text": "SMS"}).status_code == 401
    assert client.get("/api/v1/perception/logs").status_code == 401


def test_expired_jwt_cannot_access_protected_resources():
    """Vérifie qu'un JWT expiré est rejeté avec HTTP 401."""
    expired_header = create_jwt_header(101, expired=True)
    assert client.get("/api/v1/sika/auth/me", headers=expired_header).status_code == 401
    assert client.post("/api/v1/sika/agent/confirm", json={"action_id": "act_1"}, headers=expired_header).status_code == 401
    assert client.get("/api/v1/wallets/me", headers=expired_header).status_code == 401


def test_invalid_jwt_cannot_access_protected_resources():
    """Vérifie qu'un JWT altéré ou malformé est rejeté avec HTTP 401."""
    invalid_header = {"Authorization": "Bearer fake.token.signature"}
    assert client.get("/api/v1/sika/auth/me", headers=invalid_header).status_code == 401
    assert client.post("/api/v1/sika/agent/process", json={"query": "Solde"}, headers=invalid_header).status_code == 401


def test_user_a_cannot_confirm_user_b_action(monkeypatch):
    """IDOR/BOLA : User A ne peut PAS confirmer une action financière appartenant à User B."""
    monkeypatch.setattr(
        "app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout",
        lambda *args, **kwargs: {"success": True, "status": "COMPLETED", "message": "Succès payout", "new_balance": 50000.0}
    )

    header_user_a = create_jwt_header(user_id=101, email="userA@sika.app")
    header_user_b = create_jwt_header(user_id=202, email="userB@sika.app")

    action_b_id = "act_tr_user_b_001"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_b_id,
            user_id=202, # Appartient à User B
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            payload_json='{"amount": 50000, "recipient": "Koffi"}',
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        ))
        db.commit()

    # User A tente de confirmer l'action de User B
    res_a = client.post(
        "/api/v1/sika/agent/confirm",
        json={"action_id": action_b_id},
        headers=header_user_a
    )
    assert res_a.status_code == 403
    assert "non autorisé" in res_a.json()["detail"].lower()

    # Vérifier que le statut n'a pas été altéré en base
    with Session(engine) as db:
        act = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_b_id).first()
        assert act.status == "WAITING_CONFIRMATION"

    # User B peut confirmer sa propre action
    res_b = client.post(
        "/api/v1/sika/agent/confirm",
        json={"action_id": action_b_id},
        headers=header_user_b
    )
    assert res_b.status_code == 200
    assert res_b.json()["status"] == "EXECUTED"


def test_user_a_cannot_cancel_user_b_action():
    """IDOR/BOLA : User A ne peut PAS annuler une action financière appartenant à User B."""
    header_user_a = create_jwt_header(user_id=101, email="userA@sika.app")

    action_b_id = "act_tr_user_b_002"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_b_id,
            user_id=202,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            payload_json='{"amount": 25000, "recipient": "Awa"}',
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        ))
        db.commit()

    res = client.post(
        "/api/v1/sika/agent/cancel",
        json={"action_id": action_b_id, "reason": "Attaque User A"},
        headers=header_user_a
    )
    assert res.status_code == 403

    # Vérifier que l'action est restée intacte
    with Session(engine) as db:
        act = db.query(SikaActionModel).filter(SikaActionModel.action_id == action_b_id).first()
        assert act.status == "WAITING_CONFIRMATION"


def test_user_a_cannot_reconcile_user_b_action():
    """IDOR/BOLA : User A ne peut PAS réconcilier une action incertaine appartenant à User B."""
    header_user_a = create_jwt_header(user_id=101, email="userA@sika.app")

    action_b_id = "act_tr_user_b_003"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_b_id,
            user_id=202,
            action_type="TRANSFER",
            status="UNKNOWN_RESULT",
            payload_json='{"amount": 10000}',
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        ))
        db.commit()

    res = client.post(
        f"/api/v1/sika/actions/{action_b_id}/reconcile",
        headers=header_user_a
    )
    assert res.status_code == 403


def test_atomic_claim_requires_action_ownership():
    """Vérifie que la clause UPDATE atomique inclut obligatoirement user_id."""
    action_id = "act_atomic_ownership_test"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_id,
            user_id=202, # Propriétaire: User 202
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            payload_json='{}',
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=5),
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc)
        ))
        db.commit()

        # Tentative d'UPDATE atomique en spécifiant un mauvais user_id (101)
        affected = db.query(SikaActionModel).filter(
            SikaActionModel.action_id == action_id,
            SikaActionModel.user_id == 101, # User A
            SikaActionModel.status.in_(["WAITING_CONFIRMATION", "PREPARED"])
        ).update({"status": "EXECUTING"}, synchronize_session=False)

        assert affected == 0 # 0 ligne affectée !

        # UPDATE avec le bon user_id (202)
        affected_correct = db.query(SikaActionModel).filter(
            SikaActionModel.action_id == action_id,
            SikaActionModel.user_id == 202, # User B
            SikaActionModel.status.in_(["WAITING_CONFIRMATION", "PREPARED"])
        ).update({"status": "EXECUTING"}, synchronize_session=False)

        assert affected_correct == 1


def test_user_a_cannot_hijack_user_b_otp_session():
    """Vérifie qu'un utilisateur B ne peut pas valider l'enrôlement OTP initié par un utilisateur A."""
    header_user_a = create_jwt_header(user_id=101, email="userA@sika.app")
    header_user_b = create_jwt_header(user_id=202, email="userB@sika.app")

    # User A déclenche une connexion
    conn_res = client.post(
        "/api/v1/wallets/connect",
        json={"provider": "Wave", "account_number": "0701010101"},
        headers=header_user_a
    )
    assert conn_res.status_code == 200
    session_id = conn_res.json()["session_id"]

    # User B tente de valider l'OTP avec la session de User A
    hijack_res = client.post(
        "/api/v1/wallets/verify-otp",
        json={"session_id": session_id, "otp_code": "123456", "provider": "Wave", "account_number": "0701010101"},
        headers=header_user_b
    )
    assert hijack_res.status_code == 403
    assert "non autorisée" in hijack_res.json()["detail"].lower()


def test_cleanup_endpoint_cannot_modify_other_users_actions():
    """Vérifie que l'endpoint de cleanup appelé par User A ne nettoie QUE les actions expirées de User A."""
    header_user_a = create_jwt_header(user_id=101, email="userA@sika.app")

    past_time = datetime.now(timezone.utc) - timedelta(minutes=10)
    with Session(engine) as db:
        # Action expirée User A
        db.add(SikaActionModel(
            action_id="act_exp_user_a",
            user_id=101,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            payload_json='{}',
            expires_at=past_time,
            created_at=past_time,
            updated_at=past_time
        ))
        # Action expirée User B
        db.add(SikaActionModel(
            action_id="act_exp_user_b",
            user_id=202,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            payload_json='{}',
            expires_at=past_time,
            created_at=past_time,
            updated_at=past_time
        ))
        db.commit()

    # User A appelle cleanup-stale
    res = client.post("/api/v1/sika/actions/cleanup-stale", headers=header_user_a)
    assert res.status_code == 200
    res_data = res.json()
    assert res_data["expired_count"] == 1
    assert "act_exp_user_a" in res_data["expired_action_ids"]
    assert "act_exp_user_b" not in res_data["expired_action_ids"]

    # Vérifier en base que l'action de User B est toujours intacte
    with Session(engine) as db:
        act_b = db.query(SikaActionModel).filter(SikaActionModel.action_id == "act_exp_user_b").first()
        assert act_b.status == "WAITING_CONFIRMATION"


def test_perception_routes_enforce_jwt_and_user_isolation():
    """Vérifie que le moteur de perception isole strictement les logs et modifications de solde par utilisateur."""
    h_user_a = create_jwt_header(user_id=101, email="userA@sika.app")
    h_user_b = create_jwt_header(user_id=202, email="userB@sika.app")

    # Enrôler un wallet Wave pour User A
    wallet_router.CONNECTED_USER_WALLETS.append({
        "id": "w_wave_101",
        "user_id": "101",
        "provider": "Wave",
        "balance": 10000.0,
        "is_active": True
    })
    # Enrôler un wallet Wave pour User B
    wallet_router.CONNECTED_USER_WALLETS.append({
        "id": "w_wave_202",
        "user_id": "202",
        "provider": "Wave",
        "balance": 50000.0,
        "is_active": True
    })

    # User A perçoit un SMS Wave indiquant un solde de 25 000 FCFA
    res_sms_a = client.post(
        "/api/v1/perception/sms",
        json={"text": "Vous avez recu 15 000 FCFA. Nouveau solde: 25 000 FCFA.", "sender": "WAVE"},
        headers=h_user_a
    )
    assert res_sms_a.status_code == 200
    assert res_sms_a.json()["updated_wallet"]["balance"] == 25000.0
    assert res_sms_a.json()["updated_wallet"]["user_id"] == "101"

    # Vérifier que le wallet de User B n'a ABSOLUMENT PAS été modifié (toujours 50 000)
    w_b = next(w for w in wallet_router.CONNECTED_USER_WALLETS if w["id"] == "w_wave_202")
    assert w_b["balance"] == 50000.0

    # Vérifier l'isolation des logs de perception
    logs_a = client.get("/api/v1/perception/logs", headers=h_user_a).json()
    logs_b = client.get("/api/v1/perception/logs", headers=h_user_b).json()

    assert logs_a["count"] == 1
    assert logs_b["count"] == 0 # User B ne voit aucun log de User A
