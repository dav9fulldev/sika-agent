import pytest
from app.services.sika_ai import SikaAIService

@pytest.fixture
def sika_service():
    return SikaAIService()

def test_chat_basic_english_fallback(sika_service):
    res = sika_service._chat_basic(
        user_message="Random unknown text",
        financial_context={},
        user_firstname="Alice",
        is_english=True
    )
    assert "Sorry Alice" in res["response"]
    assert "How much money do I have in total?" in res["suggestions"]
    assert "Quel est mon solde total ?" not in res["suggestions"]

def test_chat_basic_french_fallback(sika_service):
    res = sika_service._chat_basic(
        user_message="Texte inconnu aléatoire",
        financial_context={},
        user_firstname="Alice",
        is_english=False
    )
    assert "Pardon Alice" in res["response"]
    assert "Quel est mon solde total ?" in res["suggestions"]
    assert "How much money do I have in total?" not in res["suggestions"]

def test_chat_basic_english_balance_no_wallets(sika_service):
    res = sika_service._chat_basic(
        user_message="What is my balance?",
        financial_context={"wallets": []},
        user_firstname="Bob",
        is_english=True
    )
    assert "Hi Bob!" in res["response"]
    assert "You don't have any connected wallets yet" in res["response"]
    assert "Connect a wallet" in res["suggestions"]

def test_chat_basic_french_balance_no_wallets(sika_service):
    res = sika_service._chat_basic(
        user_message="Quel est mon solde ?",
        financial_context={"wallets": []},
        user_firstname="Bob",
        is_english=False
    )
    assert "Salut Bob !" in res["response"]
    assert "Tu n'as encore aucun portefeuille connecté" in res["response"]
    assert "Connecter un compte" in res["suggestions"]

def test_format_response_language_suggestions(sika_service):
    res_en = sika_service._format_response(
        sika_response="Here is your balance.",
        user_message="What is my balance?",
        financial_context={},
        is_english=True
    )
    assert "How much money do I have in total?" in res_en["suggestions"]

    res_fr = sika_service._format_response(
        sika_response="Voici ton solde.",
        user_message="Quel est mon solde ?",
        financial_context={},
        is_english=False
    )
    assert "Quel est mon solde total ?" in res_fr["suggestions"]

@pytest.mark.asyncio
async def test_pure_greeting_hello_returns_greeting_not_transfer(sika_service):
    # Even if previous history contained a transfer query, hello should not prepare a transfer
    history = [
        {"role": "user", "content": "Transfère 1000 XOF à 0779996927 sur Moov"},
        {"role": "model", "content": "J'ai préparé le transfert."}
    ]
    res = await sika_service.chat(
        user_message="hello",
        financial_context={"wallets": []},
        conversation_history=history,
        user_firstname="David",
        user_id="1"
    )
    assert res["action"] is None
    assert res["action_id"] is None
    assert res["requires_confirmation"] is False
    assert "Hello David!" in res["response"]
    assert "How much money do I have in total?" in res["suggestions"]

@pytest.mark.asyncio
async def test_pure_greeting_bonjour_returns_french_greeting(sika_service):
    res = await sika_service.chat(
        user_message="bonjour",
        financial_context={"wallets": []},
        conversation_history=[],
        user_firstname="David",
        user_id="1"
    )
    assert res["action"] is None
    assert res["action_id"] is None
    assert res["requires_confirmation"] is False
    assert "Bonjour David !" in res["response"]
    assert "Quel est mon solde total ?" in res["suggestions"]

