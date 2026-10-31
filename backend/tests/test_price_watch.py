"""Alertes de prix Channel3 : signature Standard Webhooks, dédoublonnage, déclenchement, isolation. Aucun appel réseau."""

import base64
import hashlib
import hmac
import json
import time
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.user import UserModel
from app.models.price_watch import PriceWatchModel, ShoppingWebhookEventModel
from app.services import price_watch_service as pws
from app.services import web_shopping_service as ws
from app.services.auth_service import oauth2_auth_service

client = TestClient(app)
SECRET = "whsec_" + base64.b64encode(b"sika-test-signing-key-32-bytes!!").decode()

PRODUCT = {"id": "p1", "title": "Wireless Headphones X", "images": [],
           "offers": [{"domain": "store-b.com", "price": {"price": 59.0, "currency": "USD"}, "availability": "InStock",
                       "condition": "new", "url": "https://buy.example/b"}]}


class FakeChannel3:
    def __init__(self):
        self.calls = []

    def get(self, url, headers, timeout):
        self.calls.append(("GET", url, None))
        ok = url.endswith("/v1/products/p1")
        return SimpleNamespace(status_code=200 if ok else 404, json=lambda: PRODUCT if ok else {})

    def request(self, method, url, json=None, headers=None, timeout=None):
        self.calls.append((method, url, json))
        return SimpleNamespace(status_code=200, json=lambda: {"subscription_id": "sub_123", "status": "active"})


@pytest.fixture(autouse=True)
def setup(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PriceWatchModel).delete()
        db.query(ShoppingWebhookEventModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"watch{uid}@sika.test", full_name=f"User {uid}"))
        db.commit()
    fake = FakeChannel3()
    monkeypatch.setattr(pws.settings, "CHANNEL3_API_KEY", "test-key")
    monkeypatch.setattr(pws.settings, "CHANNEL3_WEBHOOK_SECRET", SECRET)
    monkeypatch.setattr(ws, "web_shopping_service", ws.WebShoppingService(session=fake))
    monkeypatch.setattr(pws.price_watch_service, "_session", fake)
    yield fake


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"watch{uid}@sika.test"})}


def _signed(event, secret=SECRET, ts=None, msg_id="msg_1"):
    body = json.dumps(event).encode()
    ts = str(int(ts if ts is not None else time.time()))
    key = base64.b64decode(secret.split("_", 1)[1])
    sig = base64.b64encode(hmac.new(key, f"{msg_id}.{ts}.".encode() + body, hashlib.sha256).digest()).decode()
    return body, {"svix-id": msg_id, "svix-timestamp": ts, "svix-signature": f"v1,{sig}", "content-type": "application/json"}


def _price_event(event_id, price, domain="store-c.com"):
    return {"id": event_id, "type": "offer.price.changed", "timestamp": "2026-10-27T15:00:00Z",
            "data": {"subscription_id": "sub_123", "subject": {"product_id": "p1", "domain": domain},
                     "previous": {"price": 59.0, "currency": "USD"}, "current": {"price": price, "currency": "USD"}}}


def test_signature_verification():
    body, headers = _signed({"a": 1})
    assert pws.verify_standard_webhook(SECRET, headers, body)
    assert not pws.verify_standard_webhook(SECRET, headers, body + b" ")                       # corps modifié
    other = "whsec_" + base64.b64encode(b"another-key-another-key-123456!!").decode()
    assert not pws.verify_standard_webhook(other, headers, body)                              # mauvais secret
    old_body, old_headers = _signed({"a": 1}, ts=time.time() - 3600)
    assert not pws.verify_standard_webhook(SECRET, old_headers, old_body)                     # rejeu
    assert not pws.verify_standard_webhook(SECRET, {}, body)


def test_create_watch_subscribes_and_is_per_user(setup):
    r = client.post("/api/v1/shopping/price-watches", json={"product_id": "p1", "target_price": "50"}, headers=_auth(1))
    assert r.status_code == 200, r.text
    w = r.json()
    assert w["status"] == "active" and w["target_price"] == "50.00" and w["last_price"] == "59.00"
    with Session(engine) as db:
        assert db.query(PriceWatchModel).first().subscription_id == "sub_123"
    post = [c for c in setup.calls if c[0] == "POST"][0]
    assert post[1].endswith("/v1/product-subscriptions") and post[2]["product_id"] == "p1"
    assert client.get("/api/v1/shopping/price-watches", headers=_auth(2)).json()["watches"] == []
    assert client.delete(f"/api/v1/shopping/price-watches/{w['watch_id']}", headers=_auth(2)).status_code == 404
    bad = client.post("/api/v1/shopping/price-watches", json={"product_id": "p1", "target_price": "-3"}, headers=_auth(1))
    assert bad.status_code == 400 and bad.json()["detail"]["error_code"] == "INVALID_TARGET"


def test_webhook_rejects_unsigned_and_triggers_once(setup):
    client.post("/api/v1/shopping/price-watches", json={"product_id": "p1", "target_price": "50"}, headers=_auth(1))
    body, headers = _signed(_price_event("evt_1", 55.0))
    assert client.post("/api/v1/shopping/channel3/webhook", content=body,
                       headers={**headers, "svix-signature": "v1,AAAA"}).status_code == 401
    r = client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers)
    assert r.status_code == 200 and r.json()["outcome"] == "MATCHED_1_TRIGGERED_0_NOTIFIED_1"   # 55 > 50 : pas encore, mais baisse signalée

    body, headers = _signed(_price_event("evt_2", 47.99), msg_id="msg_2")
    assert client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers).json()["outcome"] == "MATCHED_1_TRIGGERED_1_NOTIFIED_1"
    again = client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers)
    assert again.json()["outcome"] == "DUPLICATE"

    data = client.get("/api/v1/shopping/price-watches", headers=_auth(1)).json()
    w = data["watches"][0]
    assert w["status"] == "triggered" and w["last_price"] == "47.99" and w["last_merchant"] == "store-c.com"
    assert data["unseen"] == 1
    client.post("/api/v1/shopping/price-watches/seen", headers=_auth(1))
    assert client.get("/api/v1/shopping/price-watches", headers=_auth(1)).json()["unseen"] == 0


def test_back_in_stock_alert_and_unconfigured_secret(setup, monkeypatch):
    client.post("/api/v1/shopping/price-watches", json={"product_id": "p1"}, headers=_auth(1))
    event = {"id": "evt_3", "type": "offer.availability.changed",
             "data": {"subject": {"product_id": "p1", "domain": "store-b.com"}, "previous": "OutOfStock", "current": "InStock"}}
    body, headers = _signed(event, msg_id="msg_3")
    assert client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers).json()["outcome"] == "MATCHED_1_TRIGGERED_1_NOTIFIED_1"
    monkeypatch.setattr(pws.settings, "CHANNEL3_WEBHOOK_SECRET", None)
    assert client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers).status_code == 503


def test_watch_tool_is_read_only():
    from app.agent.tool_registry import tool_registry
    for name in ("watch_web_product_price", "list_price_watches"):
        assert name in tool_registry.agent_tool_names()
        assert tool_registry.get_definition(name).risk_level.value == "READ_ONLY"
        assert "user_id" not in tool_registry.get_definition(name).input_schema.get("properties", {})


def test_legacy_price_changed_event_is_handled_and_deduplicated_on_svix_id(setup):
    client.post("/api/v1/shopping/price-watches", json={"product_id": "p1", "target_price": "50"}, headers=_auth(1))
    legacy = {"type": "price.changed", "canonical_product_id": "p1", "domain": "store-d.com", "old_price": 59.0,
              "new_price": 49.5, "currency": "USD", "buy_url": "https://buy.example/d", "timestamp": "2026-10-27T15:49:00Z"}
    body, headers = _signed(legacy, msg_id="msg_legacy_1")
    assert client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers).json()["outcome"] == "MATCHED_1_TRIGGERED_1_NOTIFIED_1"
    assert client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers).json()["outcome"] == "DUPLICATE"
    w = client.get("/api/v1/shopping/price-watches", headers=_auth(1)).json()["watches"][0]
    assert w["status"] == "triggered" and w["last_price"] == "49.50" and w["last_merchant"] == "store-d.com"
