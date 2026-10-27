"""Recherche web (Channel3) : comparaison d'offres réelles, lecture seule, jamais de paiement. Aucun appel réseau."""

import asyncio
from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.agent.tool_registry import tool_registry
from app.services import web_shopping_service as ws
from app.services.sika_ai import SikaAI


def _raw(pid, title, offers):
    return {"id": pid, "title": title, "brands": [{"id": "b", "name": "Acme"}],
            "images": [{"url": "https://img.example/x.jpg", "cleaned_url": "https://cdn.example/x.png", "is_main_image": True}],
            "offers": offers}


def _o(domain, price, availability="InStock", condition="new", key="price"):
    return {"domain": domain, "price": {key: price, "currency": "USD"}, "availability": availability,
            "condition": condition, "url": f"https://www.buy.example/{domain}"}


RAW = [
    _raw("p1", "Wireless Headphones X", [_o("store-a.com", 59.99), _o("store-b.com", 47.5), _o("store-c.com", 39.0, condition="used")]),
    _raw("p2", "Wireless Headphones Y", [_o("store-d.com", 44.0, key="amount"), _o("store-e.com", 49.99, availability="OutOfStock")]),
    _raw("p3", "Too Expensive Z", [_o("store-f.com", 120.0)]),
]


class FakeSession:
    def __init__(self, status=200, payload=None, raise_exc=None):
        self.status, self.payload, self.raise_exc, self.calls = status, payload, raise_exc, []

    def post(self, url, json, headers, timeout):
        self.calls.append((url, json, headers))
        if self.raise_exc:
            raise self.raise_exc
        return SimpleNamespace(status_code=self.status, json=lambda: self.payload)


@pytest.fixture
def configured(monkeypatch):
    monkeypatch.setattr(ws.settings, "CHANNEL3_API_KEY", "test-key")
    session = FakeSession(payload={"products": RAW})
    monkeypatch.setattr(ws, "web_shopping_service", ws.WebShoppingService(session=session))
    return session


def test_best_offer_is_cheapest_new_in_stock_within_budget():
    p = ws.normalize_product(RAW[0], Decimal("50"))
    assert p["best_offer"]["merchant"] == "store-b.com" and p["best_offer"]["price"] == "47.50"
    assert [o["merchant"] for o in p["offers"]] == ["store-c.com", "store-b.com", "store-a.com"]
    assert p["within_budget"] is True and p["image_url"] == "https://cdn.example/x.png"


def test_price_amount_variant_and_out_of_stock_are_handled():
    p = ws.normalize_product(RAW[1], None)
    assert p["best_offer"]["merchant"] == "store-d.com" and p["best_offer"]["price"] == "44.00"
    assert ws.normalize_product(RAW[2], Decimal("50"))["best_offer"] is None


def test_search_sends_budget_and_key_and_ranks_results(configured):
    data = ws.web_shopping_service.search("wireless headphones", 50)
    url, body, headers = configured.calls[0]
    assert url.endswith("/v1/search") and headers["x-api-key"] == "test-key"
    assert body["filters"]["price"] == {"max_price": 50.0}
    assert [p["product_id"] for p in data["products"]] == ["p2", "p1", "p3"]
    assert "cannot pay" in data["payment_note"]


def test_not_configured_and_errors_are_explicit(monkeypatch):
    monkeypatch.setattr(ws.settings, "CHANNEL3_API_KEY", None)
    with pytest.raises(ws.WebShoppingError) as e:
        ws.WebShoppingService(session=FakeSession()).search("x")
    assert e.value.code == "WEB_SEARCH_NOT_CONFIGURED"
    monkeypatch.setattr(ws.settings, "CHANNEL3_API_KEY", "k")
    with pytest.raises(ws.WebShoppingError) as e:
        ws.WebShoppingService(session=FakeSession(status=500, payload={})).search("x")
    assert e.value.code == "WEB_SEARCH_UNAVAILABLE"


def test_non_https_links_are_dropped():
    raw = _raw("p", "T", [{"domain": "x.com", "price": {"price": 5, "currency": "USD"}, "availability": "InStock",
                           "url": "javascript:alert(1)"}])
    assert ws.normalize_product(raw) is None


def test_web_tool_is_read_only_and_exposed():
    assert "search_web_products" in tool_registry.agent_tool_names()
    assert tool_registry.get_definition("search_web_products").risk_level.value == "READ_ONLY"


def test_agent_returns_web_offer_cards(configured):
    class Models:
        def __init__(self):
            self.script = [([SimpleNamespace(name="search_web_products", args={"query": "wireless headphones", "max_price": 50})], None),
                           (None, "I compared 4 merchants: the best is Wireless Headphones Y at 44.00 USD on store-d.com.")]

        async def generate_content(self, model, contents, config):
            calls, text = self.script.pop(0)
            return SimpleNamespace(function_calls=calls, text=text, candidates=[SimpleNamespace(content=SimpleNamespace(role="model", parts=[]))])

    ai = SikaAI.__new__(SikaAI)
    ai.provider, ai.model, ai.project, ai.location = "vertex_ai", "gemini-test", "p", "global"
    ai.client = SimpleNamespace(aio=SimpleNamespace(models=Models()))
    res = asyncio.run(ai.chat("Find wireless headphones under $50 online", user_id="1"))
    assert res["action"] == "web_offers" and res["requires_confirmation"] is False
    cards = res["action_data"]["products"]
    assert [c["product_id"] for c in cards] == ["p2", "p1"]  # p3 n'a aucune offre dans le budget
    assert all(c["best_offer"]["url"].startswith("https://") for c in cards)
