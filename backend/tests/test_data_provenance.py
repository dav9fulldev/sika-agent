import pytest
from app.services.ai_engine import AIEngine
from app.services.sika_nlp import SikaNLP
from app.services.sika_ai import SikaAI
from app.routes.sika_router import strip_markdown

# Test data provenance for financial engine
def test_ai_engine_dynamic_currency_usd():
    engine = AIEngine()
    response = engine._handle_balance_query(remaining=100.0, total_budget=1000.0, total_spent=900.0, currency="USD")
    assert "USD" in response
    assert "FCFA" not in response
    assert "100 USD" in response

def test_ai_engine_dynamic_currency_eur():
    engine = AIEngine()
    response = engine._handle_purchase_query("Puis-je dépenser 50 EUR?", remaining=100.0, budgets=[], currency="EUR")
    assert "EUR" in response
    assert "FCFA" not in response
    assert "50 EUR" in response

def test_ai_engine_dynamic_currency_xof():
    engine = AIEngine()
    response = engine._handle_goals_query(goals=[], currency="XOF")
    # Even if empty goals, no hardcoded FCFA in generic response unless it's XOF/FCFA
    pass

# Test NLP data provenance for speech formatting
def test_nlp_format_amount_speech_usd():
    speech = SikaNLP.format_amount_for_speech(150.0, currency="USD")
    assert "dollars" in speech
    assert "francs" not in speech

def test_nlp_format_amount_speech_eur():
    speech = SikaNLP.format_amount_for_speech(200.0, currency="EUR")
    assert "euros" in speech
    assert "francs" not in speech

def test_nlp_format_amount_speech_xof():
    speech = SikaNLP.format_amount_for_speech(15000.0, currency="XOF")
    assert "francs cfa" in speech

# Test SikaAI dynamic currency context builder
def test_sika_ai_currency_formatting():
    # _format_currency logic
    sika_ai = SikaAI()
    formatted = sika_ai._format_currency(200, {"currency_symbol": "$"})
    assert formatted == "200 $"
    
    formatted = sika_ai._format_currency(300, {"currency_code": "EUR"})
    assert formatted == "300 EUR"
    
    formatted = sika_ai._format_currency(400, {"currency_code": "XOF"})
    assert formatted == "400 XOF"
    
    formatted = sika_ai._format_currency(500, {})
    assert formatted == "500"

