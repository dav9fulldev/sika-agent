"""Mots de passe hachés avec scrypt (sel aléatoire), migration de l'ancien SHA-256, comptes PayPal/Google sans mot de passe."""

import hashlib
import uuid

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.user import UserModel
from app.services.auth_service import _hash_password, _verify_password

client = TestClient(app)


def _user(**kw):
    Base.metadata.create_all(bind=engine)
    email = f"pw-{uuid.uuid4().hex[:10]}@sika.test"
    with Session(engine) as db:
        db.add(UserModel(email=email, full_name="Pw Test", **kw))
        db.commit()
    return email


def _stored_hash(email):
    with Session(engine) as db:
        return db.query(UserModel).filter(UserModel.email == email).first().password_hash


def test_hash_is_salted_scrypt():
    a, b = _hash_password("Secret123!"), _hash_password("Secret123!")
    assert a.startswith("scrypt$") and a != b
    assert _verify_password("Secret123!", a) and not _verify_password("wrong", a)
    assert not _verify_password("anything", None)


def test_legacy_sha256_hash_still_works_and_is_upgraded():
    email = _user(password_hash=hashlib.sha256(b"Legacy123!").hexdigest())
    res = client.post("/api/v1/sika/auth/login", json={"email": email, "password": "Legacy123!"})
    assert res.status_code == 200
    assert _stored_hash(email).startswith("scrypt$")
    again = client.post("/api/v1/sika/auth/login", json={"email": email, "password": "Legacy123!"})
    assert again.status_code == 200


def test_wrong_password_gives_a_code():
    email = _user(password_hash=_hash_password("Right123!"))
    res = client.post("/api/v1/sika/auth/login", json={"email": email, "password": "Wrong123!"})
    assert res.status_code == 401 and res.json()["detail"]["error_code"] == "INVALID_CREDENTIALS"


def test_paypal_account_without_password_is_told_to_use_paypal():
    email = _user(auth_provider="paypal")
    res = client.post("/api/v1/sika/auth/login", json={"email": email, "password": "Whatever1!"})
    assert res.status_code == 401
    assert res.json()["detail"]["error_code"] == "USE_PAYPAL_SIGN_IN"
    assert "PayPal" in res.json()["detail"]["message"]


# ---------------------------------------------------------------------------
# Google : un email seul ne doit jamais ouvrir une session hors développement
# ---------------------------------------------------------------------------

def _register_victim():
    email = f"victim-{uuid.uuid4().hex[:8]}@sika.test"
    client.post("/api/v1/sika/auth/register", json={"email": email, "password": "Str0ng!Passw0rd", "name": "Victim"})
    return email


def test_google_email_without_token_is_refused_outside_development(monkeypatch):
    from app.config import settings
    email = _register_victim()
    monkeypatch.setattr(settings, "ENV", "staging")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "client-id.apps.googleusercontent.com")
    r = client.post("/api/v1/sika/auth/google", json={"email": email})
    assert r.status_code == 401
    assert r.json()["detail"]["error_code"] == "GOOGLE_TOKEN_REQUIRED"
    assert "access_token" not in r.text


def test_google_invalid_token_is_refused_outside_development(monkeypatch):
    from app.config import settings
    email = _register_victim()
    monkeypatch.setattr(settings, "ENV", "staging")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", "client-id.apps.googleusercontent.com")
    r = client.post("/api/v1/sika/auth/google", json={"email": email, "id_token": "forged.token.value"})
    assert r.status_code == 401
    assert r.json()["detail"]["error_code"] == "GOOGLE_TOKEN_INVALID"


def test_google_sign_in_unavailable_without_client_id(monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "ENV", "staging")
    monkeypatch.setattr(settings, "GOOGLE_CLIENT_ID", None)
    r = client.post("/api/v1/sika/auth/google", json={"email": "anyone@sika.test", "id_token": "x"})
    assert r.status_code == 503
    assert r.json()["detail"]["error_code"] == "GOOGLE_SIGN_IN_UNAVAILABLE"


def test_reset_code_is_invalidated_after_five_wrong_attempts(monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "ENV", "development")  # expose le code (dev_otp) pour le test
    email = _register_victim()
    code = client.post("/api/v1/sika/auth/forgot-password", json={"email": email}).json()["dev_otp"]
    wrong = "000000" if code != "000000" else "111111"
    for _ in range(5):
        r = client.post("/api/v1/sika/auth/reset-password", json={"email": email, "otp": wrong, "new_password": "N3w!Passw0rd"})
        assert r.status_code == 400
    # Même le bon code ne passe plus : il faut en demander un nouveau
    r = client.post("/api/v1/sika/auth/reset-password", json={"email": email, "otp": code, "new_password": "N3w!Passw0rd"})
    assert r.status_code == 429
    new_code = client.post("/api/v1/sika/auth/forgot-password", json={"email": email}).json()["dev_otp"]
    r = client.post("/api/v1/sika/auth/reset-password", json={"email": email, "otp": new_code, "new_password": "N3w!Passw0rd"})
    assert r.status_code == 200
