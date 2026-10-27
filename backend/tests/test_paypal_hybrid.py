"""
SIKA Pay — Mode hybride, capture après approbation, erreurs PayPal et webhooks.

- Sans autorisation, seul l'utilisateur confirme : le tool de confirmation n'est pas présenté au modèle
  et le serveur refuse toute confirmation par l'agent.
- Avec une autorisation, l'agent confirme dans les limites fixées par l'utilisateur (vérifiées serveur).
- La capture suit l'approbation PayPal sans 4e confirmation, et jamais deux fois.
- Les erreurs PayPal donnent un statut et un message exploitables.
- Les webhooks ne sont traités qu'après vérification de signature, une seule fois chacun.
"""

import asyncio
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.user import UserModel
from app.models.paypal_checkout import PayPalCheckoutModel
from app.models.agent_mandate import AgentMandateModel
from app.models.paypal_webhook_event import PayPalWebhookEventModel
from app.routes import paypal_router
from app.services.auth_service import oauth2_auth_service
from app.services.agent_mandate_service import agent_mandate_service, MandateError
from app.services.paypal_checkout_service import paypal_checkout_service, CheckoutError
from app.services.wallet_integrations.paypal_api_service import PayPalAPIError
from app.services.sika_ai import SikaAI

from paypal_fakes import FakePayPalAPI

client = TestClient(app)


@pytest.fixture(autouse=True)
def fake(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).delete()
        db.query(AgentMandateModel).delete()
        db.query(PayPalWebhookEventModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"hybrid{uid}@sika.test", full_name=f"User {uid}"))
        db.commit()
    api = FakePayPalAPI()
    monkeypatch.setattr(paypal_checkout_service, "api", api)
    monkeypatch.setattr(paypal_router, "paypal_api_service", api)
    monkeypatch.setattr(paypal_router.settings, "PAYPAL_WEBHOOK_ID", "")
    monkeypatch.setattr(paypal_router.settings, "PUBLIC_BASE_URL", "http://localhost:8001")
    paypal_router._webhook_id_cache.clear()
    yield api


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"hybrid{uid}@sika.test"})}


def _prepare(uid=1, sku="SIKA-COURSE-EXCEL", budget=None):
    return paypal_checkout_service.prepare_checkout(uid, sku, 1, budget)


def _created(uid=1):
    chk = _prepare(uid)
    res = paypal_checkout_service.confirm_and_create_order(uid, chk["checkout_id"], chk["details_hash"])
    return chk["checkout_id"], res["paypal"]["order_id"]


# ---------------------------------------------------------------------------
# Autorisation (mandat)
# ---------------------------------------------------------------------------

def test_authorization_lifecycle_and_validation():
    assert agent_mandate_service.get(1) == {"active": False}
    m = agent_mandate_service.grant(1, "50", "100", 24)
    assert m["active"] and m["max_per_purchase"] == "50.00" and m["daily_limit"] == "100.00" and m["remaining_today"] == "100.00"
    for per, daily, hours in [("0", "10", 1), ("600", "600", 1), ("50", "20", 1), ("10", "10", 0), ("10", "10", 721)]:
        with pytest.raises(MandateError):
            agent_mandate_service.grant(1, per, daily, hours)
    assert agent_mandate_service.revoke(1) == {"active": False}
    assert agent_mandate_service.get(1) == {"active": False}


def test_agent_cannot_confirm_without_authorization(fake):
    chk = _prepare()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_by_agent(1, chk["checkout_id"])
    assert e.value.code == "NO_ACTIVE_AUTHORIZATION"
    assert fake.calls == []


def test_agent_confirms_within_authorization_and_is_audited(fake):
    agent_mandate_service.grant(1, "50", "100", 24)
    chk = _prepare(budget="50")
    res = paypal_checkout_service.confirm_by_agent(1, chk["checkout_id"])
    assert res["status"] == "AWAITING_PAYPAL_APPROVAL" and res["confirmed_by"] == "AGENT"
    events = paypal_checkout_service.get_checkout(1, chk["checkout_id"])["events"]
    assert any(e["event_type"] == "AGENT_CONFIRMED" and e["reason"] == "UNDER_USER_AUTHORIZATION" for e in events)
    assert agent_mandate_service.get(1)["remaining_today"] == "51.00"


def test_agent_refused_above_limits_or_budget(fake):
    agent_mandate_service.grant(1, "30", "100", 24)
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_by_agent(1, _prepare()["checkout_id"])  # 49 > 30
    assert e.value.code == "ABOVE_AUTHORIZED_AMOUNT"

    agent_mandate_service.grant(1, "50", "60", 24)
    paypal_checkout_service.confirm_by_agent(1, _prepare()["checkout_id"])  # 49 dépensés
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_by_agent(1, _prepare()["checkout_id"])  # 98 > 60
    assert e.value.code == "DAILY_LIMIT_REACHED"

    agent_mandate_service.revoke(1)
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_by_agent(1, _prepare()["checkout_id"])
    assert e.value.code == "NO_ACTIVE_AUTHORIZATION"


def test_authorization_http_endpoints():
    assert client.get("/api/v1/paypal/agent-authorization").status_code == 401
    r = client.put("/api/v1/paypal/agent-authorization", json={"max_per_purchase": "25", "daily_limit": "50", "duration_hours": 2},
                   headers=_auth(1))
    assert r.status_code == 200 and r.json()["active"] is True
    assert client.get("/api/v1/paypal/agent-authorization", headers=_auth(2)).json() == {"active": False}
    bad = client.put("/api/v1/paypal/agent-authorization", json={"max_per_purchase": "25", "daily_limit": "10", "duration_hours": 2},
                     headers=_auth(1))
    assert bad.status_code == 400 and bad.json()["detail"]["error_code"] == "INVALID_LIMIT"
    assert client.delete("/api/v1/paypal/agent-authorization", headers=_auth(1)).json() == {"active": False}


# ---------------------------------------------------------------------------
# Boucle agent : le tool de confirmation n'existe que sous autorisation
# ---------------------------------------------------------------------------

def _call(name, args):
    return SimpleNamespace(name=name, args=args)


class ScriptedModels:
    def __init__(self, script):
        self.script = list(script)
        self.configs = []

    async def generate_content(self, model, contents, config):
        self.configs.append(config)
        calls, text = self.script.pop(0) if self.script else (None, "ok")
        return SimpleNamespace(function_calls=calls, text=text, candidates=[SimpleNamespace(content=SimpleNamespace(role="model", parts=[]))])


def _scripted_ai(script):
    ai = SikaAI.__new__(SikaAI)
    ai.provider, ai.model, ai.project, ai.location = "vertex_ai", "gemini-test", "p", "global"
    models = ScriptedModels(script)
    ai.client = SimpleNamespace(aio=SimpleNamespace(models=models))
    return ai, models


def _declared_names(config):
    names = set()
    for tool in config.tools or []:
        for decl in getattr(tool, "function_declarations", None) or []:
            names.add(decl.name)
    return names


def test_confirm_tool_hidden_and_refused_without_authorization(fake):
    ai, models = _scripted_ai([
        ([_call("prepare_paypal_checkout", {"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "budget_limit": 50})], None),
    ])
    res = asyncio.run(ai.chat("Buy the Excel course under $50", user_id="1"))
    assert "confirm_checkout_with_authorization" not in _declared_names(models.configs[0])
    assert res["requires_confirmation"] is True and res["action_data"]["checkout"]["status"] == "AWAITING_USER_CONFIRMATION"
    assert fake.calls == []


def test_agent_confirms_purchase_under_authorization(fake):
    agent_mandate_service.grant(1, "50", "100", 24)
    ai, models = _scripted_ai([
        ([_call("prepare_paypal_checkout", {"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "budget_limit": 50})], None),
        ([_call("confirm_checkout_with_authorization", {"checkout_id": "PLACEHOLDER"})], None),
    ])
    # Le modèle reprend le checkout_id renvoyé par prepare : on l'injecte dans le script après coup
    original = models.generate_content

    async def patched(model, contents, config):
        if len(models.configs) == 1 and models.script and models.script[0][0]:
            cid = paypal_checkout_service.list_checkouts(1, 1)[0]["checkout_id"]
            models.script[0] = ([_call("confirm_checkout_with_authorization", {"checkout_id": cid})], None)
        return await original(model, contents, config)

    models.generate_content = patched
    res = asyncio.run(ai.chat("Buy the Excel course under $50", user_id="1"))
    assert "confirm_checkout_with_authorization" in _declared_names(models.configs[0])
    assert res["requires_confirmation"] is False
    assert res["action_data"]["confirmed_by"] == "AGENT"
    assert res["action_data"]["checkout"]["status"] == "AWAITING_PAYPAL_APPROVAL"
    assert [c[0] for c in fake.calls] == ["create"]  # commande créée, aucune capture
    assert [s["type"] for s in res["agent_steps"]] == ["prepare_paypal_checkout", "confirm_checkout_with_authorization"]


# ---------------------------------------------------------------------------
# Erreurs PayPal à la capture
# ---------------------------------------------------------------------------

def test_instrument_declined_sends_payer_back_to_paypal(fake):
    cid, order_id = _created()
    fake.approve(order_id)
    fake.capture_failure = PayPalAPIError(422, name="UNPROCESSABLE_ENTITY", issue="INSTRUMENT_DECLINED", debug_id="d1")
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.capture(1, cid)
    assert e.value.code == "INSTRUMENT_DECLINED" and "another" in e.value.message
    view = paypal_checkout_service.get_checkout(1, cid)
    assert view["status"] == "AWAITING_PAYPAL_APPROVAL" and view["paypal"]["approve_url"]


@pytest.mark.parametrize("issue", ["PAYER_CANNOT_PAY", "TRANSACTION_REFUSED", "MAX_NUMBER_OF_PAYMENT_ATTEMPTS_EXCEEDED", "CANNOT_PAY_SELF"])
def test_refused_payment_is_declined_with_clear_message(fake, issue):
    cid, order_id = _created()
    fake.approve(order_id)
    fake.capture_failure = PayPalAPIError(422, name="UNPROCESSABLE_ENTITY", issue=issue, debug_id="d2")
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.capture(1, cid)
    assert e.value.code == issue and "No funds were captured" in e.value.message
    view = paypal_checkout_service.get_checkout(1, cid)
    assert view["status"] == "DECLINED" and view["last_error"]["code"] == issue


def test_order_unknown_to_paypal_is_expired(fake):
    cid, order_id = _created()
    del fake.orders[order_id]
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.capture(1, cid)
    assert e.value.code == "ORDER_EXPIRED"
    assert paypal_checkout_service.get_checkout(1, cid)["status"] == "EXPIRED"


# ---------------------------------------------------------------------------
# Webhooks
# ---------------------------------------------------------------------------

def _event(event_id, event_type, order_id):
    resource = {"id": order_id} if event_type.startswith("CHECKOUT.") else {
        "id": "CAP123", "supplementary_data": {"related_ids": {"order_id": order_id}}}
    return {"id": event_id, "event_type": event_type, "resource": resource}


def test_webhook_rejects_invalid_signature(fake):
    cid, order_id = _created()
    fake.approve(order_id)
    fake.webhook_signature_valid = False
    r = client.post("/api/v1/paypal/webhook", json=_event("WH-1", "CHECKOUT.ORDER.APPROVED", order_id))
    assert r.status_code == 401
    assert paypal_checkout_service.get_checkout(1, cid)["status"] == "AWAITING_PAYPAL_APPROVAL"
    assert fake.capture_count() == 0


def test_webhook_order_approved_captures_once_even_if_repeated(fake):
    cid, order_id = _created()
    fake.approve(order_id)
    body = _event("WH-2", "CHECKOUT.ORDER.APPROVED", order_id)
    first = client.post("/api/v1/paypal/webhook", json=body)
    assert first.status_code == 200 and first.json()["outcome"] == "STATUS_COMPLETED"
    again = client.post("/api/v1/paypal/webhook", json=body)
    assert again.json()["duplicate"] is True
    assert fake.capture_count() == 1
    assert ("verify_webhook", "WH-TEST-0001") in fake.calls  # ID retrouvé par l'URL du webhook


def test_webhook_refund_is_reported_without_hiding_the_capture(fake):
    cid, order_id = _created()
    fake.approve(order_id)
    paypal_checkout_service.sync_with_paypal(1, cid)
    fake.refund(order_id)
    r = client.post("/api/v1/paypal/webhook", json=_event("WH-3", "PAYMENT.CAPTURE.REFUNDED", order_id))
    assert r.status_code == 200
    view = paypal_checkout_service.get_checkout(1, cid)
    assert view["status"] == "COMPLETED" and view["paypal"]["capture_status"] == "REFUNDED"
    assert any(e["event_type"] == "PAYPAL_CAPTURE_REFUNDED_WEBHOOK" for e in view["events"])


def test_webhook_for_unknown_order_is_acknowledged(fake):
    r = client.post("/api/v1/paypal/webhook", json=_event("WH-4", "PAYMENT.CAPTURE.COMPLETED", "NOTOURS12345"))
    assert r.status_code == 200 and r.json()["outcome"] == "UNKNOWN_ORDER"


def test_return_page_auto_captures_after_approval(fake):
    cid, order_id = _created()
    fake.approve(order_id)
    page = client.get(f"/api/v1/paypal/return?token={order_id}")
    assert "Payment completed" in page.text and "sikapay://paypal/return" in page.text
    assert paypal_checkout_service.get_checkout(1, cid)["status"] == "COMPLETED"
    assert fake.capture_count() == 1
