"""
SIKA Pay — Connexion avec PayPal (Log in with PayPal), état du profil et KYC.
Le client PayPal est simulé : aucun appel réseau.
"""

import secrets
from datetime import datetime, timezone, timedelta
from urllib.parse import urlparse, parse_qs

import jwt
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.config import settings
from app.database import engine, Base
from app.models.user import UserModel
from app.services.auth_service import oauth2_auth_service
from app.services.paypal_identity_service import paypal_identity_service, normalize_userinfo
from app.services.wallet_integrations.paypal_api_service import PayPalAPIError

client = TestClient(app)


class FakeIdentityAPI:
    def __init__(self, info):
        self.info = info
        self.codes = []
        self.fail_exchange = False

    def is_configured(self):
        return True

    def exchange_authorization_code(self, code):
        self.codes.append(code)
        if self.fail_exchange:
            raise PayPalAPIError(400, name="invalid_grant", message="expired")
        return {"access_token": f"user-{secrets.token_hex(4)}", "token_type": "Bearer"}

    def get_userinfo(self, token):
        return self.info


def _info(email="buyer@personal.example.com", verified="true", country="US", name="John Doe", confirmed=True, payer="PAYER123ABC"):
    return {
        "user_id": f"https://www.paypal.com/webapps/auth/identity/user/{payer}",
        "payer_id": payer,
        "name": name,
        "emails": [{"value": email, "primary": True, "confirmed": confirmed}],
        "address": {"country": country},
        "verified_account": verified,
    }


@pytest.fixture(autouse=True)
def db():
    from app.database.dev_schema import ensure_dev_columns
    Base.metadata.create_all(bind=engine)
    ensure_dev_columns(engine)
    with Session(engine) as s:
        s.query(UserModel).filter(UserModel.email.like("%example.com")).delete(synchronize_session=False)
        s.commit()
    yield


def _use(monkeypatch, info):
    fake = FakeIdentityAPI(info)
    monkeypatch.setattr(paypal_identity_service, "api", fake)
    return fake


def _state():
    return parse_qs(urlparse(paypal_identity_service.start()["authorize_url"]).query)["state"][0]


def test_start_builds_official_sandbox_connect_url(monkeypatch):
    _use(monkeypatch, _info())
    res = client.get("/api/v1/sika/auth/paypal/start").json()
    url = urlparse(res["authorize_url"])
    q = parse_qs(url.query)
    assert url.scheme == "https" and url.netloc == "www.sandbox.paypal.com" and url.path == "/connect"
    assert q["response_type"] == ["code"] and q["flowEntry"] == ["static"]
    assert q["redirect_uri"] == [settings.PAYPAL_LOGIN_REDIRECT_URI]
    assert "openid" in q["scope"][0] and "email" in q["scope"][0]
    assert q["client_id"] == [settings.PAYPAL_CLIENT_ID]
    assert settings.PAYPAL_CLIENT_SECRET not in res["authorize_url"]


def test_verified_paypal_account_signs_in_with_complete_verified_profile(monkeypatch):
    _use(monkeypatch, _info())
    res = client.post("/api/v1/sika/auth/paypal", json={"code": "AUTHCODE", "state": _state()})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["user"]["email"] == "buyer@personal.example.com"
    assert body["profile"] == {"missing_fields": [], "complete": True, "kyc_status": "paypal",
                               "kyc_verified": True, "kyc_source": "paypal", "paypal_linked": True}
    me = client.get("/api/v1/sika/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"}).json()["user"]
    assert me["is_kyc_verified"] is True and me["country"] == "US"


def test_unverified_paypal_account_is_not_kyc_verified(monkeypatch):
    _use(monkeypatch, _info(verified="false"))
    body = client.post("/api/v1/sika/auth/paypal", json={"code": "C", "state": _state()}).json()
    assert body["profile"]["kyc_verified"] is False and body["profile"]["kyc_status"] == "none"


def test_missing_country_is_reported(monkeypatch):
    _use(monkeypatch, _info(country=""))
    body = client.post("/api/v1/sika/auth/paypal", json={"code": "C", "state": _state()}).json()
    assert body["profile"]["missing_fields"] == ["country"] and body["profile"]["complete"] is False


def test_invalid_or_expired_state_is_rejected(monkeypatch):
    fake = _use(monkeypatch, _info())
    assert client.post("/api/v1/sika/auth/paypal", json={"code": "C", "state": "forged"}).status_code == 400
    expired = jwt.encode({"purpose": "paypal_login", "exp": datetime.now(timezone.utc) - timedelta(seconds=1)},
                         oauth2_auth_service.SECRET_KEY, algorithm="HS256")
    assert client.post("/api/v1/sika/auth/paypal", json={"code": "C", "state": expired}).status_code == 400
    assert fake.codes == []  # aucun échange de code sans state valide


def test_refused_code_is_reported_without_session(monkeypatch):
    fake = _use(monkeypatch, _info())
    fake.fail_exchange = True
    res = client.post("/api/v1/sika/auth/paypal", json={"code": "OLD", "state": _state()})
    assert res.status_code == 401 and res.json()["detail"]["error_code"] == "PAYPAL_LOGIN_REFUSED"


def test_existing_account_is_linked_only_when_paypal_confirms_email(monkeypatch):
    with Session(engine) as s:
        s.add(UserModel(email="owner@personal.example.com", full_name="Owner", auth_provider="email"))
        s.commit()
    _use(monkeypatch, _info(email="owner@personal.example.com", confirmed=False, payer="OTHERPAYER1"))
    res = client.post("/api/v1/sika/auth/paypal", json={"code": "C", "state": _state()})
    assert res.status_code == 409 and res.json()["detail"]["error_code"] == "EMAIL_NOT_CONFIRMED"

    _use(monkeypatch, _info(email="owner@personal.example.com", confirmed=True, payer="OTHERPAYER1"))
    res = client.post("/api/v1/sika/auth/paypal", json={"code": "C", "state": _state()})
    assert res.status_code == 200
    with Session(engine) as s:
        assert s.query(UserModel).filter(UserModel.email == "owner@personal.example.com").one().paypal_payer_id == "OTHERPAYER1"


def test_userinfo_normalization_handles_boolean_and_string_flags():
    n = normalize_userinfo({"payer_id": "P1", "email": "a@b.example.com", "email_verified": True, "verified_account": True})
    assert n["verified_account"] is True and n["email_confirmed"] is True and n["country"] is None


def test_in_app_kyc_submission_stays_pending():
    with Session(engine) as s:
        u = UserModel(email="kyc@self.example.com", full_name="Kyc User", auth_provider="email", country="CI")
        s.add(u)
        s.commit()
        uid = u.id
    token = oauth2_auth_service.create_access_token({"user_id": uid, "email": "kyc@self.example.com"})
    res = client.post("/api/v1/users/me/kyc", headers={"Authorization": f"Bearer {token}"}).json()
    assert res["profile"]["kyc_status"] == "submitted" and res["profile"]["kyc_verified"] is False


def test_forgot_password_never_leaks_code_outside_development(monkeypatch):
    with Session(engine) as s:
        s.add(UserModel(email="reset@self.example.com", full_name="Reset", auth_provider="email"))
        s.commit()
    known = client.post("/api/v1/sika/auth/forgot-password", json={"email": "reset@self.example.com"}).json()
    unknown = client.post("/api/v1/sika/auth/forgot-password", json={"email": "nobody@self.example.com"}).json()
    assert "otp" not in known and "otp" not in unknown and "dev_otp" not in unknown
    assert known["message"] == unknown["message"]  # pas d'énumération des comptes
    monkeypatch.setattr(settings, "ENV", "production")
    prod = client.post("/api/v1/sika/auth/forgot-password", json={"email": "reset@self.example.com"}).json()
    assert "dev_otp" not in prod and "otp" not in prod


def test_default_login_redirect_is_the_web_return_page():
    assert settings.PAYPAL_LOGIN_REDIRECT_URI.endswith("/api/v1/sika/auth/paypal/return")
    assert settings.PAYPAL_LOGIN_REDIRECT_URI.startswith("http")


def test_return_page_hands_code_and_state_back_to_the_app():
    r = client.get("/api/v1/sika/auth/paypal/return", params={"code": "C0de", "state": "s.t", "scope": "ignored"})
    assert r.status_code == 200
    assert r.headers["cache-control"] == "no-store"
    assert "sikapay://paypal/login?code=C0de&amp;state=s.t" in r.text
    assert "ignored" not in r.text


def test_return_page_escapes_and_reports_errors():
    r = client.get("/api/v1/sika/auth/paypal/return", params={"error": '"><script>x</script>'})
    assert "<script>x" not in r.text
    assert "sikapay://paypal/login?error=" in r.text
    r = client.get("/api/v1/sika/auth/paypal/return")
    assert "error=missing_code" in r.text
