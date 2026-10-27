"""Abonnements PayPal : prix revérifié avec PayPal, confirmation utilisateur obligatoire, statuts relus chez PayPal."""

import asyncio
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.user import UserModel
from app.models.paypal_subscription import PayPalSubscriptionModel
from app.agent.tool_registry import tool_registry
from app.routes import paypal_router
from app.services.auth_service import oauth2_auth_service
from app.services.paypal_checkout_service import paypal_checkout_service
from app.services.paypal_subscription_service import paypal_subscription_service, SubscriptionError
from app.services.sika_ai import SikaAI

from paypal_fakes import FakePayPalAPI

client = TestClient(app)


@pytest.fixture(autouse=True)
def fake(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PayPalSubscriptionModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"sub{uid}@sika.test", full_name=f"User {uid}"))
        db.commit()
    api = FakePayPalAPI()
    monkeypatch.setattr(paypal_subscription_service, "api", api)
    monkeypatch.setattr(paypal_subscription_service, "_plans", {})
    monkeypatch.setattr(paypal_checkout_service, "api", api)
    monkeypatch.setattr(paypal_router, "paypal_api_service", api)
    monkeypatch.setattr(paypal_router.settings, "PAYPAL_WEBHOOK_ID", "WH-TEST-0001")
    yield api


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"sub{uid}@sika.test"})}


def test_full_subscription_flow(fake):
    sub = paypal_subscription_service.prepare(1, "tunewave-music")
    assert sub["status"] == "AWAITING_USER_CONFIRMATION" and sub["price"] == "9.99"
    assert not any(c[0] == "create_subscription" for c in fake.calls)  # préparer ne souscrit rien

    ref = sub["subscription_ref"]
    assert client.post(f"/api/v1/paypal/subscriptions/{ref}/confirm", headers=_auth(2)).status_code == 404
    r = client.post(f"/api/v1/paypal/subscriptions/{ref}/confirm", headers=_auth(1))
    assert r.status_code == 200 and r.json()["status"] == "AWAITING_PAYPAL_APPROVAL"
    sid = r.json()["paypal"]["subscription_id"]
    assert r.json()["paypal"]["approve_url"].startswith("https://www.sandbox.paypal.com/")
    again = client.post(f"/api/v1/paypal/subscriptions/{ref}/confirm", headers=_auth(1))
    assert again.json()["paypal"]["subscription_id"] == sid  # pas de second abonnement

    fake.activate(sid)
    page = client.get(f"/api/v1/paypal/subscriptions-return?subscription_id={sid}")
    assert "Subscription approved" in page.text
    view = client.get(f"/api/v1/paypal/subscriptions/{ref}", headers=_auth(1)).json()
    assert view["status"] == "ACTIVE" and view["paypal"]["next_billing_time"]

    cancelled = client.post(f"/api/v1/paypal/subscriptions/{ref}/cancel", headers=_auth(1)).json()
    assert cancelled["status"] == "CANCELLED" and ("cancel_subscription", sid) in fake.calls


def test_price_mismatch_with_paypal_is_never_offered(fake):
    fake.plan_overrides["P-STREAMBOXBASIC"] = "1.00"
    with pytest.raises(SubscriptionError) as e:
        paypal_subscription_service.prepare(1, "streambox-basic")
    assert e.value.code == "PLAN_MISMATCH"
    with pytest.raises(SubscriptionError) as e:
        paypal_subscription_service.prepare(1, "invented-plan")
    assert e.value.code == "UNKNOWN_PLAN"


def test_cancel_before_approval_charges_nothing(fake):
    ref = paypal_subscription_service.prepare(1, "cloudvault-200")["subscription_ref"]
    paypal_subscription_service.confirm(1, ref)
    out = paypal_subscription_service.cancel(1, ref)
    assert out["status"] == "CANCELLED" and not any(c[0] == "cancel_subscription" for c in fake.calls)


def test_subscription_webhook_refreshes_status(fake):
    ref = paypal_subscription_service.prepare(1, "fitpulse-coach")["subscription_ref"]
    sid = paypal_subscription_service.confirm(1, ref)["paypal"]["subscription_id"]
    fake.activate(sid)
    r = client.post("/api/v1/paypal/webhook", json={"id": "WH-SUB-1", "event_type": "BILLING.SUBSCRIPTION.ACTIVATED",
                                                     "resource": {"id": sid}})
    assert r.status_code == 200 and r.json()["outcome"] == "SUBSCRIPTION_ACTIVE"


def test_agent_tools_never_subscribe(fake):
    names = tool_registry.agent_tool_names()
    assert {"search_subscription_plans", "prepare_subscription", "list_my_subscriptions"} <= set(names)
    assert not any("cancel" in n or "subscribe" in n for n in names)
    plans = tool_registry.execute("search_subscription_plans", {"query": "video streaming", "max_monthly_price": 10}).data["plans"]
    assert [p["key"] for p in plans] == ["streambox-basic"]


def test_agent_prepares_subscription_and_hands_over(fake):
    class Models:
        def __init__(self):
            self.script = [([SimpleNamespace(name="search_subscription_plans", args={"query": "music"})], None),
                           ([SimpleNamespace(name="prepare_subscription", args={"plan_key": "tunewave-music"})], None),
                           (None, "Prepared TuneWave Music at 9.99 USD per month.")]

        async def generate_content(self, model, contents, config):
            calls, text = self.script.pop(0)
            return SimpleNamespace(function_calls=calls, text=text, candidates=[SimpleNamespace(content=SimpleNamespace(role="model", parts=[]))])

    ai = SikaAI.__new__(SikaAI)
    ai.provider, ai.model, ai.project, ai.location = "vertex_ai", "gemini-test", "p", "global"
    ai.client = SimpleNamespace(aio=SimpleNamespace(models=Models()))
    res = asyncio.run(ai.chat("Subscribe me to a music service", user_id="1"))
    assert res["action"] == "prepare_subscription" and res["requires_confirmation"] is True
    assert res["action_data"]["subscription"]["status"] == "AWAITING_USER_CONFIRMATION"
    assert not any(c[0] == "create_subscription" for c in fake.calls)
