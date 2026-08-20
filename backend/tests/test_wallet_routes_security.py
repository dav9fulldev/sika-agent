import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.services.auth_service import oauth2_auth_service
from app.routes import wallet_router

client = TestClient(app)

@pytest.fixture(autouse=True)
def clean_wallet_state():
    """Nettoie l'état des wallets en mémoire avant chaque test."""
    wallet_router.CONNECTED_USER_WALLETS.clear()
    wallet_router.PENDING_OTP_SESSIONS.clear()
    yield
    wallet_router.CONNECTED_USER_WALLETS.clear()
    wallet_router.PENDING_OTP_SESSIONS.clear()

def create_auth_header(user_id: int, email: str = "test@sika.app") -> dict:
    token = oauth2_auth_service.create_access_token({
        "id": user_id,
        "email": email,
        "name": f"User {user_id}"
    })
    return {"Authorization": f"Bearer {token}"}

def test_wallet_routes_reject_unauthenticated():
    """Vérifie que toutes les routes wallet rejettent les requêtes sans JWT (HTTP 401)."""
    assert client.get("/api/v1/wallets/me").status_code == 401
    assert client.get("/api/v1/wallets/transactions/history").status_code == 401
    assert client.get("/api/v1/wallets/coffres").status_code == 401
    assert client.post("/api/v1/wallets/connect", json={"provider": "Wave", "account_number": "0102030405"}).status_code == 401
    assert client.post("/api/v1/wallets/verify-otp", json={"session_id": "s1", "otp_code": "123456"}).status_code == 401
    assert client.post("/api/v1/wallets/sync").status_code == 401
    assert client.post("/api/v1/wallets/reset").status_code == 401
    assert client.post("/api/v1/wallets/verify-pin", json={"pin": "1234"}).status_code == 401

def test_wallet_routes_reject_invalid_token():
    """Vérifie que les routes wallet rejettent les jetons altérés ou invalides."""
    invalid_header = {"Authorization": "Bearer invalid.jwt.token"}
    assert client.get("/api/v1/wallets/me", headers=invalid_header).status_code == 401
    assert client.post("/api/v1/wallets/sync", headers=invalid_header).status_code == 401

def test_wallet_routes_accept_valid_token_and_isolate_users():
    """Vérifie l'isolation stricte des données entre User 101 et User 202."""
    h101 = create_auth_header(101, "user101@sika.app")
    h202 = create_auth_header(202, "user202@sika.app")

    # Connecter un wallet pour User 101
    conn_res101 = client.post(
        "/api/v1/wallets/connect",
        json={"provider": "Wave", "account_number": "0701010101", "auth_method": "OAUTH2_API"},
        headers=h101
    )
    assert conn_res101.status_code == 200
    sess_id_101 = conn_res101.json()["session_id"]

    verify_res101 = client.post(
        "/api/v1/wallets/verify-otp",
        json={"session_id": sess_id_101, "otp_code": "123456", "provider": "Wave", "account_number": "0701010101"},
        headers=h101
    )
    assert verify_res101.status_code == 200
    assert verify_res101.json()["wallet"]["user_id"] == "101"

    # Connecter un wallet pour User 202
    conn_res202 = client.post(
        "/api/v1/wallets/connect",
        json={"provider": "Orange Money", "account_number": "0702020202", "auth_method": "OAUTH2_API"},
        headers=h202
    )
    assert conn_res202.status_code == 200
    sess_id_202 = conn_res202.json()["session_id"]

    verify_res202 = client.post(
        "/api/v1/wallets/verify-otp",
        json={"session_id": sess_id_202, "otp_code": "123456", "provider": "Orange Money", "account_number": "0702020202"},
        headers=h202
    )
    assert verify_res202.status_code == 200
    assert verify_res202.json()["wallet"]["user_id"] == "202"

    # Vérification: User 101 ne voit QUE son wallet
    res_me_101 = client.get("/api/v1/wallets/me", headers=h101)
    assert res_me_101.status_code == 200
    w_101 = res_me_101.json()["wallets"]
    assert len(w_101) == 1
    assert w_101[0]["account_number"] == "0701010101"
    assert w_101[0]["provider"] == "Wave"

    # Vérification: User 202 ne voit QUE son wallet
    res_me_202 = client.get("/api/v1/wallets/me", headers=h202)
    assert res_me_202.status_code == 200
    w_202 = res_me_202.json()["wallets"]
    assert len(w_202) == 1
    assert w_202[0]["account_number"] == "0702020202"
    assert w_202[0]["provider"] == "Orange Money"

def test_client_cannot_spoof_user_id_in_body_or_query():
    """Vérifie qu'un attaquant ne peut pas usurper le user_id d'une autre personne."""
    h_attacker = create_auth_header(999, "attacker@evil.com")

    conn_res = client.post(
        "/api/v1/wallets/connect",
        json={"provider": "MTN", "account_number": "0505050505", "auth_method": "OAUTH2_API"},
        headers=h_attacker
    )
    assert conn_res.status_code == 200
    sess_id = conn_res.json()["session_id"]

    # Tente de passer user_id=1 en body pour verify-otp
    res = client.post(
        "/api/v1/wallets/verify-otp",
        json={
            "session_id": sess_id,
            "otp_code": "123456",
            "provider": "MTN",
            "account_number": "0505050505",
            "user_id": 1 # Tentative d'usurpation
        },
        headers=h_attacker
    )
    assert res.status_code == 200
    # Le wallet est FORCÉ sur l'ID de l'attaquant 999 extrait du JWT
    assert res.json()["wallet"]["user_id"] == "999"
