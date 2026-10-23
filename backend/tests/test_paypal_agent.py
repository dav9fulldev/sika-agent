"""
SIKA Pay — Tests de la couche agent IA (PayPal est l'unique fournisseur de paiement).

Vérifie que :
- le modèle ne voit que des tools autorisés (aucun tool EXECUTION, aucun tool de transfert) ;
- le modèle ne peut ni fournir un montant, ni usurper un user_id ;
- la boucle Gemini (simulée) prépare un checkout sans créer de commande PayPal ;
- le mode de secours déterministe demande des précisions en cas d'ambiguïté ;
- aucun ancien endpoint Mobile Money ne subsiste.
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
from app.agent.tool_registry import tool_registry
from app.services.auth_service import oauth2_auth_service
from app.services.paypal_checkout_service import paypal_checkout_service
from app.services.sika_ai import SikaAI

from paypal_fakes import FakePayPalAPI

client = TestClient(app)

@pytest.fixture(autouse=True)
def paypal_only(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"agent{uid}@sika.test", full_name=f"User {uid}"))
        db.commit()
    fake = FakePayPalAPI()
    monkeypatch.setattr(paypal_checkout_service, "api", fake)
    yield fake


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"agent{uid}@sika.test"})}


# ---------------------------------------------------------------------------
# Autorisations des tools
# ---------------------------------------------------------------------------

def test_agent_only_sees_paypal_and_safe_tools():
    names = set(tool_registry.agent_tool_names())
    assert {"search_demo_catalog", "prepare_paypal_checkout", "get_paypal_checkout_status"} <= names
    for forbidden in ["update_user_habit", "create_backup_snapshot"]:
        assert forbidden not in names
    for name in names:
        assert tool_registry.get_definition(name).risk_level.value != "EXECUTION"


def test_paypal_tools_have_strict_schemas_without_user_id_or_amount():
    for name in ["search_demo_catalog", "prepare_paypal_checkout", "get_paypal_checkout_status", "list_recent_paypal_checkouts"]:
        props = tool_registry.get_definition(name).input_schema.get("properties", {})
        assert "user_id" not in props
        assert "amount" not in props and "total" not in props and "unit_price" not in props


def test_prepare_tool_rejects_model_supplied_amount():
    res = tool_registry.execute("prepare_paypal_checkout", {"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "amount": 0.01, "user_id": "1"})
    assert res.success is False and "Arguments invalides" in res.error_message


def test_prepare_tool_never_contacts_paypal(paypal_only):
    res = tool_registry.execute("prepare_paypal_checkout", {"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "budget_limit": 50, "user_id": "1"})
    assert res.success and res.requires_confirmation
    assert res.data["checkout"]["status"] == "AWAITING_USER_CONFIRMATION"
    assert paypal_only.calls == []


def test_status_tool_isolated_per_user(paypal_only):
    prep = tool_registry.execute("prepare_paypal_checkout", {"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "user_id": "1"})
    cid = prep.data["checkout"]["checkout_id"]
    other = tool_registry.execute("get_paypal_checkout_status", {"checkout_id": cid, "user_id": "2"})
    assert other.success is False and other.data["error_code"] == "FORBIDDEN"


# ---------------------------------------------------------------------------
# Boucle Gemini simulée : le serveur impose user_id et ne laisse pas créer de commande
# ---------------------------------------------------------------------------

def _call(name, args):
    return SimpleNamespace(name=name, args=args)


class ScriptedModels:
    """Réponses Gemini scriptées : search -> prepare (avec tentative d'usurpation de user_id) -> texte."""

    def __init__(self, script):
        self.script = list(script)
        self.configs = []

    async def generate_content(self, model, contents, config):
        self.configs.append(config)
        calls, text = self.script.pop(0)
        content = SimpleNamespace(role="model", parts=[])
        return SimpleNamespace(function_calls=calls, text=text, candidates=[SimpleNamespace(content=content)])


def _scripted_ai(script):
    ai = SikaAI.__new__(SikaAI)
    ai.provider, ai.model, ai.project, ai.location = "vertex_ai", "gemini-test", "p", "global"
    models = ScriptedModels(script)
    ai.client = SimpleNamespace(aio=SimpleNamespace(models=models))
    return ai, models


def test_gemini_loop_prepares_checkout_with_server_user_id(paypal_only):
    ai, models = _scripted_ai([
        ([_call("search_demo_catalog", {"query": "excel course", "max_price": 50})], None),
        ([_call("prepare_paypal_checkout", {"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "budget_limit": 50, "user_id": "2"})], None),
        (None, "I prepared the Excel course for 49.00 USD. Nothing has been charged yet."),
    ])
    res = asyncio.run(ai.chat("Help me buy an Excel course under $50", user_id="1"))

    assert res["action"] == "prepare_paypal_checkout" and res["requires_confirmation"] is True
    checkout = res["action_data"]["checkout"]
    assert checkout["total_amount"] == "49.00" and checkout["status"] == "AWAITING_USER_CONFIRMATION"
    with Session(engine) as db:
        row = db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.checkout_id == res["action_id"]).first()
        assert row.user_id == 1  # le user_id "2" proposé par le modèle est ignoré
        assert row.user_request == "Help me buy an Excel course under $50"
    assert [s["type"] for s in res["agent_steps"]] == ["search_demo_catalog", "prepare_paypal_checkout"]
    assert "Nothing has been charged" in res["response"]
    assert paypal_only.calls == []  # aucune commande PayPal créée par l'agent
    assert models.configs[0].automatic_function_calling.disable is True


def test_gemini_loop_refuses_tools_outside_allowlist(paypal_only):
    ai, _ = _scripted_ai([
        ([_call("create_backup_snapshot", {})], None),
        (None, "I cannot do that."),
    ])
    res = asyncio.run(ai.chat("make a backup of my data", user_id="1"))
    assert res["action"] == "chat" and res["action_id"] is None
    assert res["agent_steps"][0]["status"] == "failed"


def test_gemini_over_budget_is_explained_not_prepared(paypal_only):
    ai, _ = _scripted_ai([
        ([_call("prepare_paypal_checkout", {"sku": "SIKA-COURSE-MARKETING", "quantity": 1, "budget_limit": 50})], None),
        (None, "This course costs 64.00 USD, above your 50 USD budget."),
    ])
    res = asyncio.run(ai.chat("buy the marketing course, max 50 dollars", user_id="1"))
    assert res["requires_confirmation"] is False and res["action_id"] is None


def test_react_loop_is_bounded(paypal_only):
    ai, models = _scripted_ai([([_call("search_demo_catalog", {"query": "x"})], None)] * 10)
    asyncio.run(ai.chat("buy something", user_id="1"))
    assert len(models.configs) == 5


# ---------------------------------------------------------------------------
# Mode de secours déterministe (sans LLM)
# ---------------------------------------------------------------------------

def _offline_ai():
    ai = SikaAI.__new__(SikaAI)
    ai.provider, ai.model, ai.client = "vertex_ai", "none", None
    return ai


def test_fallback_prepares_clear_request(paypal_only):
    res = asyncio.run(_offline_ai().chat("Help me buy an Excel course under $50", user_id="1"))
    assert res["provider"] == "SIKA_LOCAL_FALLBACK"
    assert res["action"] == "prepare_paypal_checkout"
    assert res["action_data"]["checkout"]["item"]["sku"] == "SIKA-COURSE-EXCEL"
    assert paypal_only.calls == []


@pytest.mark.parametrize("query,lang", [
    ("Help me buy an Excel course without going over my 50 dollar budget.", "en"),
    ("Je veux acheter un cours Excel à moins de 50 dollars", "fr"),
])
def test_fallback_handles_natural_phrasings(paypal_only, query, lang):
    res = asyncio.run(_offline_ai().chat(query, user_id="1"))
    assert res["language"] == lang
    checkout = res["action_data"]["checkout"]
    assert checkout["item"]["sku"] == "SIKA-COURSE-EXCEL"
    assert checkout["budget"]["limit"] == "50.00" and checkout["budget"]["within_budget"] is True


def test_purchase_requests_are_detected_as_english():
    ai = _offline_ai()
    assert ai.detect_language("I want to buy a course.") == "en"
    assert ai.detect_language("Did my payment go through?") == "en"


def test_fallback_asks_when_ambiguous(paypal_only):
    res = asyncio.run(_offline_ai().chat("I want to buy a course", user_id="1"))
    assert res["action"] == "ask_ambiguity" and res["action_id"] is None


def test_fallback_reports_nothing_within_budget(paypal_only):
    res = asyncio.run(_offline_ai().chat("buy the photo editing software under $20", user_id="1"))
    assert res["action_id"] is None


# ---------------------------------------------------------------------------
# PayPal, unique fournisseur : plus aucun endpoint ni module Mobile Money
# ---------------------------------------------------------------------------

def test_legacy_wallet_and_transfer_endpoints_are_gone():
    h = _auth(1)
    assert client.get("/api/v1/wallets/me", headers=h).status_code == 404
    assert client.post("/api/v1/sika/agent/confirm", json={"action_id": "act_x"}, headers=h).status_code == 404


def test_no_legacy_payment_module_is_importable():
    import importlib
    for mod in ["app.routes.wallet_router", "app.agent.tools.transaction_tools", "app.agent.tools.wallet_tools"]:
        with pytest.raises(ModuleNotFoundError):
            importlib.import_module(mod)


def test_chat_endpoint_prepares_paypal_checkout(paypal_only, monkeypatch):
    from app.routes import sika_router
    monkeypatch.setattr(sika_router.sika_ai, "client", None)
    res = client.post("/api/v1/sika/chat", json={"query": "Help me buy an Excel course under $50"}, headers=_auth(1))
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["intent"] == "prepare_paypal_checkout" and body["requires_confirmation"] is True
    assert body["action_data"]["checkout"]["provider"] == "PAYPAL"
    assert paypal_only.calls == []
