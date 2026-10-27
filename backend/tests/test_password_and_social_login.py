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
