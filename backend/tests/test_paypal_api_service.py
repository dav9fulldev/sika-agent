"""
Tests du client bas niveau PayPal Orders v2 (session HTTP simulée, aucun appel réseau).
Vérifie les en-têtes, l'idempotence, la gestion des jetons et le mapping des erreurs officielles.
"""

import secrets

import pytest
import requests

from app.config import Settings, settings
from app.services.wallet_integrations.paypal_api_service import (
    PayPalAPIService, PayPalAPIError, PayPalNetworkError, PayPalConfigurationError,
)


class FakeResponse:
    def __init__(self, status, body=None, headers=None):
        self.status_code = status
        self._body = body if body is not None else {}
        self.headers = headers or {}

    def json(self):
        return self._body


class FakeSession:
    def __init__(self, responses):
        self.responses = list(responses)
        self.sent = []

    def post(self, url, **kwargs):
        self.sent.append(("POST", url, kwargs))
        return self._next()

    def request(self, method, url, **kwargs):
        self.sent.append((method, url, kwargs))
        return self._next()

    def _next(self):
        r = self.responses.pop(0)
        if isinstance(r, Exception):
            raise r
        return r


FAKE_ACCESS = f"dummy-{secrets.token_hex(8)}"  # jeton factice généré, jamais une vraie valeur
TOKEN = FakeResponse(200, {"access_token": FAKE_ACCESS, "expires_in": 32400})


def test_create_order_sends_official_body_and_idempotency_header():
    order = {"id": "5O190127TN364715T", "status": "PAYER_ACTION_REQUIRED",
             "links": [{"rel": "payer-action", "href": "https://www.sandbox.paypal.com/checkoutnow?token=5O190127TN364715T"}]}
    s = FakeSession([TOKEN, FakeResponse(200, order)])
    api = PayPalAPIService(session=s)
    res = api.create_order(reference_id="chk_1", custom_id="chk_1", currency="USD", total="49.00",
                           items=[{"name": "x", "quantity": "1", "unit_amount": {"currency_code": "USD", "value": "49.00"}}],
                           description="d", request_id="sika-create-123")
    assert res["id"] == "5O190127TN364715T"
    assert api.extract_approve_url(res).startswith("https://www.sandbox.paypal.com/")

    oauth = s.sent[0]
    assert oauth[1] == "https://api-m.sandbox.paypal.com/v1/oauth2/token"
    assert oauth[2]["data"] == {"grant_type": "client_credentials"}

    method, url, kw = s.sent[1]
    assert (method, url) == ("POST", "https://api-m.sandbox.paypal.com/v2/checkout/orders")
    assert kw["headers"]["PayPal-Request-Id"] == "sika-create-123"
    assert kw["headers"]["Authorization"] == f"Bearer {FAKE_ACCESS}"
    body = kw["json"]
    assert body["intent"] == "CAPTURE"
    assert body["purchase_units"][0]["amount"] == {"currency_code": "USD", "value": "49.00",
                                                   "breakdown": {"item_total": {"currency_code": "USD", "value": "49.00"}}}
    ctx = body["payment_source"]["paypal"]["experience_context"]
    assert ctx["shipping_preference"] == "NO_SHIPPING" and ctx["user_action"] == "PAY_NOW"
    assert ctx["return_url"].endswith("/api/v1/paypal/return") and ctx["cancel_url"].endswith("/api/v1/paypal/cancel")


def test_token_is_cached_between_calls():
    s = FakeSession([TOKEN, FakeResponse(200, {"id": "ORDER12345", "status": "APPROVED"}),
                     FakeResponse(200, {"id": "ORDER12345", "status": "APPROVED"})])
    api = PayPalAPIService(session=s)
    api.get_order("ORDER12345")
    api.get_order("ORDER12345")
    assert sum(1 for m in s.sent if m[1].endswith("/v1/oauth2/token")) == 1


def test_expired_token_is_refreshed_once_on_401():
    s = FakeSession([TOKEN, FakeResponse(401, {"error": "invalid_token"}), TOKEN,
                     FakeResponse(200, {"id": "ORDER12345", "status": "APPROVED"})])
    api = PayPalAPIService(session=s)
    assert api.get_order("ORDER12345")["status"] == "APPROVED"


def test_paypal_error_is_parsed_with_issue_and_debug_id():
    err = {"name": "UNPROCESSABLE_ENTITY", "debug_id": "f1a2b3",
           "details": [{"issue": "ORDER_NOT_APPROVED", "description": "Payer has not yet approved the Order for payment."}]}
    s = FakeSession([TOKEN, FakeResponse(422, err)])
    api = PayPalAPIService(session=s)
    with pytest.raises(PayPalAPIError) as e:
        api.capture_order("ORDER12345", request_id="sika-capture-1")
    assert e.value.issue == "ORDER_NOT_APPROVED" and e.value.debug_id == "f1a2b3" and e.value.status_code == 422
    assert s.sent[1][2]["headers"]["PayPal-Request-Id"] == "sika-capture-1"


def test_network_error_is_unknown_result_not_failure():
    s = FakeSession([TOKEN, requests.exceptions.ReadTimeout("timeout")])
    api = PayPalAPIService(session=s)
    with pytest.raises(PayPalNetworkError):
        api.capture_order("ORDER12345", request_id="sika-capture-1")


def test_rejects_invalid_order_id_before_any_http_call():
    s = FakeSession([])
    api = PayPalAPIService(session=s)
    with pytest.raises(ValueError):
        api.get_order("../../v1/oauth2/token")
    assert s.sent == []


def test_missing_credentials(monkeypatch):
    monkeypatch.setattr(settings, "PAYPAL_CLIENT_ID", None)
    api = PayPalAPIService(session=FakeSession([]))
    with pytest.raises(PayPalConfigurationError):
        api.get_order("ORDER12345")


def test_oauth_failure_does_not_leak_secret(monkeypatch, caplog):
    s = FakeSession([FakeResponse(401, {"error": "invalid_client", "error_description": "Client Authentication failed"})])
    api = PayPalAPIService(session=s)
    with pytest.raises(PayPalAPIError):
        api.get_order("ORDER12345")
    assert settings.PAYPAL_CLIENT_SECRET not in caplog.text


def test_configuration_is_sandbox_only():
    with pytest.raises(ValueError):
        Settings(PAYPAL_ENV="live")
    with pytest.raises(ValueError):
        Settings(PAYPAL_API_BASE="https://api-m.paypal.com")
    assert Settings().PAYPAL_API_BASE == "https://api-m.sandbox.paypal.com"


def test_production_reads_paypal_credentials_from_secret_manager(monkeypatch):
    """En production, PAYPAL_CLIENT_ID/SECRET doivent pouvoir venir de GCP Secret Manager."""
    resolved = {"PAYPAL_CLIENT_ID": f"sm-{secrets.token_hex(4)}", "PAYPAL_CLIENT_SECRET": f"sm-{secrets.token_hex(4)}"}
    monkeypatch.setattr(Settings, "_resolve_secrets", lambda self, overrides: dict(resolved))
    cfg = Settings()
    assert cfg.PAYPAL_CLIENT_ID == resolved["PAYPAL_CLIENT_ID"]
    assert cfg.PAYPAL_CLIENT_SECRET == resolved["PAYPAL_CLIENT_SECRET"]
    assert cfg.paypal_configured is True
