"""Suivi automatique et notifications de changements (Channel3 + FCM). Aucun appel réseau réel."""

import base64
import hashlib
import hmac
import json
import time
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.user import UserModel
from app.models.price_watch import (PriceWatchModel, PushDeviceModel, ShoppingWebhookEventModel,
                                    UserNotificationModel)
from app.services import notification_service as ns
from app.services import price_watch_service as pws
from app.services.auth_service import oauth2_auth_service

client = TestClient(app)
SECRET = "whsec_" + base64.b64encode(b"sika-test-signing-key-32-bytes!!").decode()
TOKEN = "fcm-token-" + "x" * 40
real_is_quiet_hour = ns.is_quiet_hour  # la fixture le remplace pour les autres tests


def _product(pid="p1", price="59.00", merchant="store-b.com"):
    return {"product_id": pid, "title": f"Keyboard {pid}", "image_url": None,
            "best_offer": {"price": price, "merchant": merchant, "currency": "USD"}}


class FakeChannel3:
    def __init__(self):
        self.calls = []

    def request(self, method, url, json=None, headers=None, timeout=None):
        self.calls.append((method, url, json))
        sub = f"sub_{json['product_id']}" if json else "sub"
        return SimpleNamespace(status_code=200, json=lambda: {"subscription_id": sub, "status": "active"})


class FakePush:
    def __init__(self, outcome="SENT"):
        self.sent = []
        self.outcome = outcome

    def enabled(self):
        return True

    def send(self, token, title, body, data=None):
        self.sent.append((token, title, body, data))
        return self.outcome


@pytest.fixture(autouse=True)
def setup(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        for model in (UserNotificationModel, PushDeviceModel, PriceWatchModel, ShoppingWebhookEventModel):
            db.query(model).delete()
        for uid in (1, 2):
            user = db.query(UserModel).filter(UserModel.id == uid).first()
            if not user:
                db.add(UserModel(id=uid, email=f"alert{uid}@sika.test", full_name=f"User {uid}"))
            else:
                user.auto_follow_products = True
        db.commit()
    fake = FakeChannel3()
    monkeypatch.setattr(pws.settings, "CHANNEL3_API_KEY", "test-key")
    monkeypatch.setattr(pws.settings, "CHANNEL3_WEBHOOK_SECRET", SECRET)
    monkeypatch.setattr(pws.price_watch_service, "_session", fake)
    push = FakePush()
    monkeypatch.setattr(ns, "push_service", push)
    monkeypatch.setattr(ns, "is_quiet_hour", lambda offset, now=None: False)
    yield SimpleNamespace(channel3=fake, push=push)


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"alert{uid}@sika.test"})}


def _send(event, msg_id):
    body = json.dumps(event).encode()
    ts = str(int(time.time()))
    key = base64.b64decode(SECRET.split("_", 1)[1])
    sig = base64.b64encode(hmac.new(key, f"{msg_id}.{ts}.".encode() + body, hashlib.sha256).digest()).decode()
    headers = {"svix-id": msg_id, "svix-timestamp": ts, "svix-signature": f"v1,{sig}", "content-type": "application/json"}
    r = client.post("/api/v1/shopping/channel3/webhook", content=body, headers=headers)
    assert r.status_code == 200, r.text
    return r.json()["outcome"]


def _price(eid, before, after, domain="store-b.com", pid="p1"):
    return {"id": eid, "type": "offer.price.changed", "timestamp": "2026-10-31T10:00:00Z",
            "data": {"subscription_id": "sub", "subject": {"product_id": pid, "domain": domain},
                     "previous": {"price": before, "currency": "USD"}, "current": {"price": after, "currency": "USD"}}}


def _notes(uid=1):
    return client.get("/api/v1/notifications", headers=_auth(uid)).json()


def _reset_cooldown():
    with Session(engine) as db:
        db.query(PriceWatchModel).update({"last_notified_at": None})
        db.commit()


def test_products_shown_are_followed_for_30_days_with_all_offer_events(setup):
    assert pws.price_watch_service.auto_follow(1, [_product("p1"), _product("p2")]) == 2
    post = [c for c in setup.channel3.calls if c[0] == "POST"][0]
    assert post[1].endswith("/v1/product-subscriptions") and "offer.deleted" in post[2]["events"]
    watches = client.get("/api/v1/shopping/price-watches", headers=_auth(1)).json()["watches"]
    assert {w["source"] for w in watches} == {"auto"} and len(watches) == 2
    expires = datetime.fromisoformat(watches[0]["expires_at"])
    assert timedelta(days=29) < expires - datetime.now(timezone.utc) <= timedelta(days=30)
    # Montré à nouveau : pas de second abonnement
    assert pws.price_watch_service.auto_follow(1, [_product("p1")]) == 0
    assert len([c for c in setup.channel3.calls if c[0] == "POST"]) == 2


def test_auto_follow_respects_the_setting_and_turning_it_off_stops_following(setup):
    pws.price_watch_service.auto_follow(1, [_product("p1")])
    r = client.put("/api/v1/notifications/preferences", json={"auto_follow_products": False}, headers=_auth(1))
    assert r.json() == {"auto_follow_products": False}
    assert client.get("/api/v1/shopping/price-watches", headers=_auth(1)).json()["watches"] == []
    assert ("DELETE", f"{pws.settings.CHANNEL3_API_BASE}/v1/product-subscriptions/sub_p1", None) in setup.channel3.calls
    assert pws.price_watch_service.auto_follow(1, [_product("p2")]) == 0


def test_only_the_20_most_recent_products_are_followed(setup):
    for i in range(22):
        pws.price_watch_service.auto_follow(1, [_product(f"p{i}")])
    with Session(engine) as db:
        active = db.query(PriceWatchModel).filter(PriceWatchModel.status == "active").count()
        oldest = db.query(PriceWatchModel).filter(PriceWatchModel.product_id == "p0").first()
    assert active == 20 and oldest.status == "cancelled"


def test_best_price_changes_are_notified_without_spam(setup):
    pws.price_watch_service.auto_follow(1, [_product("p1", "59.00", "store-b.com")])
    # Baisse chez le marchand le moins cher : signalée
    assert _send(_price("e1", 59.0, 52.0), "m1").endswith("NOTIFIED_1")
    note = _notes()["notifications"][0]
    assert note["kind"] == "price_drop" and note["price"] == "52.00" and note["previous_price"] == "59.00"
    # Seconde baisse le même jour : enregistrée comme meilleur prix, pas de seconde notification
    assert _send(_price("e2", 52.0, 45.0), "m2").endswith("NOTIFIED_0")
    _reset_cooldown()
    # Variation de moins de 2 % : ignorée
    assert _send(_price("e3", 45.0, 44.5), "m3").endswith("NOTIFIED_0")
    # Hausse chez un marchand plus cher : sans effet pour l'utilisateur
    assert _send(_price("e4", 70.0, 90.0, domain="store-z.com"), "m4").endswith("NOTIFIED_0")
    # Hausse chez le marchand le moins cher : signalée
    assert _send(_price("e5", 44.5, 49.0), "m5").endswith("NOTIFIED_1")
    assert _notes()["notifications"][0]["kind"] == "price_rise"
    _reset_cooldown()
    # Un autre marchand devient le moins cher
    assert _send(_price("e6", 60.0, 40.0, domain="store-c.com"), "m6").endswith("NOTIFIED_1")
    note = _notes()["notifications"][0]
    assert note["kind"] == "price_drop" and note["merchant"] == "store-c.com" and note["previous_price"] == "49.00"


def test_stock_and_offer_changes(setup):
    pws.price_watch_service.auto_follow(1, [_product("p1", "59.00", "store-b.com")])
    out = {"id": "a1", "type": "offer.availability.changed",
           "data": {"subject": {"product_id": "p1", "domain": "store-b.com"}, "previous": "InStock", "current": "OutOfStock"}}
    assert _send(out, "n1").endswith("NOTIFIED_1") and _notes()["notifications"][0]["kind"] == "out_of_stock"
    back = {**out, "id": "a2", "data": {**out["data"], "previous": "OutOfStock", "current": "InStock"}}
    # Retour en stock : signalé même dans la journée
    assert _send(back, "n2").endswith("NOTIFIED_1") and _notes()["notifications"][0]["kind"] == "back_in_stock"
    _reset_cooldown()
    created = {"id": "c1", "type": "offer.created",
               "data": {"subject": {"product_id": "p1", "domain": "store-n.com"},
                        "offer": {"domain": "store-n.com", "price": {"price": 49.0, "currency": "USD"},
                                  "availability": "InStock", "condition": "new"}}}
    assert _send(created, "n3").endswith("NOTIFIED_1")
    note = _notes()["notifications"][0]
    assert note["kind"] == "new_offer" and note["merchant"] == "store-n.com" and note["previous_price"] == "59.00"
    _reset_cooldown()
    deleted = {"id": "d1", "type": "offer.deleted",
               "data": {"subject": {"product_id": "p1", "domain": "store-n.com"},
                        "offer": {"domain": "store-n.com", "price": {"price": 49.0, "currency": "USD"}, "availability": "InStock"}}}
    assert _send(deleted, "n4").endswith("NOTIFIED_1") and _notes()["notifications"][0]["kind"] == "offer_removed"


def test_expired_follow_stops_and_unsubscribes(setup):
    pws.price_watch_service.auto_follow(1, [_product("p1")])
    with Session(engine) as db:
        db.query(PriceWatchModel).update({"expires_at": datetime.now(timezone.utc) - timedelta(days=1)})
        db.commit()
    assert _send(_price("x1", 59.0, 30.0), "x1").endswith("NOTIFIED_0")
    assert any(c[0] == "DELETE" for c in setup.channel3.calls)
    assert client.get("/api/v1/shopping/price-watches", headers=_auth(1)).json()["watches"] == []


def test_notifications_are_private_and_can_be_marked_read(setup):
    pws.price_watch_service.auto_follow(1, [_product("p1")])
    _send(_price("r1", 59.0, 50.0), "r1")
    assert _notes(1)["unread"] == 1
    assert _notes(2) == {"notifications": [], "unread": 0}
    assert client.get("/api/v1/notifications").status_code == 401
    client.post("/api/v1/notifications/read", headers=_auth(1))
    assert _notes(1)["unread"] == 0 and _notes(1)["notifications"][0]["read"] is True


def test_push_goes_to_registered_phones_in_their_language(setup):
    r = client.post("/api/v1/notifications/devices", headers=_auth(1),
                    json={"token": TOKEN, "language": "fr", "tz_offset_minutes": 0})
    assert r.status_code == 200
    pws.price_watch_service.auto_follow(1, [_product("p1")])
    _send(_price("f1", 59.0, 50.0), "f1")
    token, title, body, data = setup.push.sent[0]
    assert token == TOKEN and title == "Baisse de prix" and "50.00 USD" in body and "59.00 USD" in body
    assert data["type"] == "product_alert"
    # Après la déconnexion, plus rien n'est envoyé à ce téléphone
    client.post("/api/v1/notifications/devices/remove", headers=_auth(1), json={"token": TOKEN})
    _reset_cooldown()
    _send(_price("f2", 50.0, 40.0), "f2")
    assert len(setup.push.sent) == 1


def test_invalid_tokens_are_removed(setup):
    client.post("/api/v1/notifications/devices", headers=_auth(1), json={"token": TOKEN})
    setup.push.outcome = "INVALID_TOKEN"
    pws.price_watch_service.auto_follow(1, [_product("p1")])
    _send(_price("q1", 59.0, 50.0), "q1")
    with Session(engine) as db:
        assert db.query(PushDeviceModel).count() == 0


def test_quiet_hours():
    noon = datetime(2026, 10, 31, 12, 0, tzinfo=timezone.utc)
    assert not real_is_quiet_hour(0, noon)
    assert real_is_quiet_hour(11 * 60, noon)          # 23 h à l'heure du téléphone
    assert real_is_quiet_hour(-6 * 60, noon)          # 6 h du matin
    assert not real_is_quiet_hour(-5 * 60, noon)      # 7 h : fin des heures calmes
    assert real_is_quiet_hour(0, noon.replace(hour=22))


def test_search_tool_follows_the_products_it_shows(setup, monkeypatch):
    from app.agent.tools import commerce_tools
    from app.services import web_shopping_service as ws

    class SyncThread:
        def __init__(self, target, daemon=None):
            self.target = target

        def start(self):
            self.target()

    monkeypatch.setattr(commerce_tools.threading, "Thread", SyncThread)
    monkeypatch.setattr(ws.web_shopping_service, "search",
                        lambda q, m=None, limit=10, user_ref=None: {"products": [_product("p7"), _product("p8")]})
    result = commerce_tools.search_web_products("keyboard", user_id="1")
    assert result.success
    with Session(engine) as db:
        assert {w.product_id for w in db.query(PriceWatchModel).filter(PriceWatchModel.source == "auto")} == {"p7", "p8"}
