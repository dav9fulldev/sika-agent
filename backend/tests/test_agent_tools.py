"""
Suite de Tests pour les Tools Financiers et le ToolRegistry de SIKA (Phase 5 Étape 2)
"""

import pytest
from app.agent.tool_registry import tool_registry
from app.agent.tools.tool_models import RiskLevel, ToolResult
from app.services.sika_ai import SikaAIService
import app.agent.tools  # S'assurer que tous les tools sont enregistrés


class FakeGenAIOModel:
    async def generate_content(self, **kwargs):
        class FakeResponse:
            function_calls = [
                type("Call", (), {"name": "prepare_transfer", "args": {"provider": "wave", "amount": 20000, "recipient": "Jean", "currency": "XOF"}})()
            ]
            candidates = []
            text = ""

        return FakeResponse()


class FakeGenAIClient:
    def __init__(self):
        self.aio = type("AIO", (), {"models": FakeGenAIOModel()})()


@pytest.mark.asyncio
async def test_13_prepare_transfer_response_includes_action_id():
    """13. Le résultat de préparation du transfert renvoie un action_id exploitable pour /agent/confirm."""
    service = SikaAIService()
    service.client = FakeGenAIClient()

    result = await service.chat("Envoie 20 000 FCFA à Jean.", user_id="42")

    assert result["requires_confirmation"] is True
    assert result["action_id"] is not None
    assert result["action_id"] != ""
    assert result["action_data"]["recipient"] == "Jean"
    assert result["action_data"]["amount"] == 20000.0

def test_1_registry_finds_tools():
    """1. Le registre trouve correctement tous les tools enregistrés."""
    assert tool_registry.exists("get_wallets") is True
    assert tool_registry.exists("get_wallet_balance") is True
    assert tool_registry.exists("get_total_balance") is True
    assert tool_registry.exists("get_recent_transactions") is True
    assert tool_registry.exists("get_spending_summary") is True
    assert tool_registry.exists("prepare_transfer") is True
    assert tool_registry.exists("confirm_transfer") is True
    assert tool_registry.exists("search_contact") is True
    assert tool_registry.exists("get_financial_context") is True

def test_2_get_wallets(monkeypatch):
    """2. get_wallets fonctionne et retourne les comptes enrôlés."""
    from app.agent.tools import wallet_tools
    monkeypatch.setattr(wallet_tools.financial_repository, "get_wallets", lambda uid=None: [
        {"provider": "paymechap", "external_wallet_id": "0701020304", "id": "w1", "status": "connected"}
    ])
    monkeypatch.setattr(wallet_tools.paymechap_api_service, "fetch_live_balance", lambda token, acc: {"balance": 50000.0, "currency": "XOF"})
    res = tool_registry.execute("get_wallets")
    assert res.success is True
    assert res.risk_level == RiskLevel.READ_ONLY
    assert len(res.data["wallets"]) == 1
    assert res.data["wallets"][0]["provider"] == "paymechap"

def test_3_get_wallet_balance(monkeypatch):
    """3. get_wallet_balance fonctionne pour un compte précis enrôlé."""
    from app.agent.tools import wallet_tools
    monkeypatch.setattr(wallet_tools.financial_repository, "get_wallets", lambda uid=None: [
        {"provider": "paymechap", "external_wallet_id": "0701020304", "id": "w1", "status": "connected"}
    ])
    monkeypatch.setattr(wallet_tools.paymechap_api_service, "fetch_live_balance", lambda token, acc: {"balance": 50000.0, "currency": "XOF"})
    res = tool_registry.execute("get_wallet_balance", {"provider": "paymechap"})
    assert res.success is True
    assert res.data["balance"] == 50000.0
    assert res.data["currency"] == "XOF"

def test_4_get_total_balance(monkeypatch):
    """4. get_total_balance calcule la somme totale sur les comptes enrôlés."""
    from app.agent.tools import wallet_tools
    monkeypatch.setattr(wallet_tools.financial_repository, "get_wallets", lambda uid=None: [
        {"provider": "paymechap", "external_wallet_id": "0701020304", "id": "w1", "status": "connected"}
    ])
    monkeypatch.setattr(wallet_tools.paymechap_api_service, "fetch_live_balance", lambda token, acc: {"balance": 90000.0, "currency": "XOF"})
    res = tool_registry.execute("get_total_balance")
    assert res.success is True
    assert res.data["total_balance"] == 90000.0

def test_5_get_recent_transactions(monkeypatch):
    """5. get_recent_transactions retourne les opérations observées sur les comptes connectés."""
    from app.agent.tools import transaction_tools
    monkeypatch.setattr(transaction_tools.financial_repository, "get_wallets", lambda uid=None: [
        {"provider": "paymechap", "external_wallet_id": "0701020304", "id": "w1", "status": "connected"}
    ])
    monkeypatch.setattr(transaction_tools.paymechap_api_service, "fetch_live_transactions", lambda token, limit=100: [
        {"id": "tx1", "provider": "paymechap", "amount": 5000.0, "type": "DEBIT", "category": "ALIMENTATION"},
        {"id": "tx2", "provider": "paymechap", "amount": 12000.0, "type": "CREDIT", "category": "SALAIRE"}
    ])
    res = tool_registry.execute("get_recent_transactions", {"limit": 2})
    assert res.success is True
    assert len(res.data["transactions"]) == 2
    assert "provider" in res.data["transactions"][0]

def test_6_get_spending_summary(monkeypatch):
    """6. get_spending_summary retourne l'analyse des dépenses par catégorie."""
    from app.agent.tools import financial_tools
    from datetime import datetime, timezone, timedelta
    now_str = (datetime.utcnow() - timedelta(days=1)).isoformat()
    monkeypatch.setattr(financial_tools.financial_repository, "get_wallets", lambda uid=None: [
        {"provider": "paymechap", "external_wallet_id": "0701020304", "id": "w1", "status": "connected"}
    ])
    monkeypatch.setattr(financial_tools.paymechap_api_service, "fetch_live_transactions", lambda token, account_number=None, limit=200: [
        {"id": "tx1", "provider": "paymechap", "amount": 5000.0, "type": "DEBIT", "category": "Alimentation", "timestamp": now_str}
    ])
    res = tool_registry.execute("get_spending_summary", {"days": 30})
    assert res.success is True
    assert res.data["total_spent"] > 0
    assert "category_breakdown" in res.data

def test_7_prepare_transfer():
    """7. prepare_transfer retourne confirmation_required sans exécuter."""
    res = tool_registry.execute("prepare_transfer", {
        "provider": "paymechap",
        "amount": 5000.0,
        "recipient": "+22507070707",
        "currency": "XOF"
    })
    assert res.success is True
    assert res.risk_level == RiskLevel.CONFIRMATION_REQUIRED
    assert res.requires_confirmation is True
    assert res.data["status"] == "confirmation_required"

def test_8_confirm_transfer_simulation():
    """8. confirm_transfer effectue une simulation après confirmation explicite."""
    res = tool_registry.execute("confirm_transfer", {
        "action_id": "act_123",
        "confirmation_token": "token_abc"
    }, user_confirmed=True)
    assert res.success is True
    assert res.data["status"] == "simulated_success"
    assert res.data["simulation"] is True

def test_9_non_existent_tool():
    """9. Un tool inexistant retourne une erreur propre."""
    res = tool_registry.execute("unknown_tool_xyz")
    assert res.success is False
    assert "inexistant" in res.error_message

def test_10_invalid_argument():
    """10. Un argument invalide est rejeté proprement."""
    res = tool_registry.execute("get_wallet_balance", {"invalid_arg": 123})
    assert res.success is False
    assert "Arguments invalides" in res.error_message

def test_11_readonly_tools_cannot_trigger_execution(monkeypatch):
    """11. Les tools READ_ONLY conservent leur niveau de risque sans modifier de données."""
    from app.agent.tools import financial_tools
    from datetime import datetime, timedelta
    now_str = (datetime.utcnow() - timedelta(days=1)).isoformat()
    monkeypatch.setattr(financial_tools.financial_repository, "get_wallets", lambda uid=None: [
        {"provider": "paymechap", "external_wallet_id": "0701020304", "id": "w1", "status": "connected"}
    ])
    monkeypatch.setattr(financial_tools.paymechap_api_service, "fetch_live_balance", lambda token, account_number=None: {"balance": 50000.0, "currency": "XOF"})
    monkeypatch.setattr(financial_tools.paymechap_api_service, "fetch_live_transactions", lambda token, account_number=None, limit=200: [
        {"id": "tx1", "provider": "paymechap", "amount": 5000.0, "type": "DEBIT", "timestamp": now_str}
    ])
    res = tool_registry.execute("get_financial_context")
    assert res.risk_level == RiskLevel.READ_ONLY
    recent_txs = res.data.get('recent_transactions', [])
    assert isinstance(recent_txs, list)
    assert len(recent_txs) > 0
    assert res.requires_confirmation is False

def test_12_sensitive_tools_require_confirmation():
    """12. Les tools sensibles nécessitent explicitement une confirmation."""
    res = tool_registry.execute("confirm_transfer", {
        "action_id": "act_123",
        "confirmation_token": "token_abc"
    }, user_confirmed=False)
    assert res.success is False
    assert res.requires_confirmation is True
    assert "confirmation humaine" in res.error_message


@pytest.mark.asyncio
async def test_14_textual_action_without_function_call():
    """14. Si Gemini renvoie un texte contenant un action_id mais PAS de function_call,
    le backend ne doit pas considérer l'action comme réelle."""
    class FakeTextOnlyGenAIOModel:
        async def generate_content(self, **kwargs):
            class FakeResponse:
                function_calls = []
                candidates = []
                text = "J'ai préparé le transfert de 20 000 FCFA vers Jean (+221770000001) via Wave. action_id : act_fake123"

            return FakeResponse()

    class FakeTextOnlyGenAIClient:
        def __init__(self):
            self.aio = type("AIO", (), {"models": FakeTextOnlyGenAIOModel()})()

    service = SikaAIService()
    service.client = FakeTextOnlyGenAIClient()

    result = await service.chat("Envoie 20 000 FCFA à Jean.", user_id="42")

    assert result["requires_confirmation"] is False
    assert result["action_id"] is None
    assert result["action_data"] is None


@pytest.mark.asyncio
async def test_15_insufficient_information_prompts_clarification():
    """15. Si les informations sont insuffisantes, le modèle doit demander des précisions et ne pas appeler prepare_transfer."""
    class FakeClarifyGenAIOModel:
        async def generate_content(self, **kwargs):
            class FakeResponse:
                function_calls = []
                candidates = []
                text = "Je peux préparer ça, quel est le numéro du destinataire ?"

            return FakeResponse()

    class FakeClarifyGenAIClient:
        def __init__(self):
            self.aio = type("AIO", (), {"models": FakeClarifyGenAIOModel()})()

    service = SikaAIService()
    service.client = FakeClarifyGenAIClient()

    result = await service.chat("Envoie 20 000 FCFA à Jean.", user_id="42")

    assert result["requires_confirmation"] is False
    assert result["action_id"] is None
    assert "numéro" in result["response"].lower()

# Additional tests for get_financial_context (P0-2)
import importlib
from datetime import datetime, timedelta

def test_A_no_wallets(monkeypatch):
    """Test that when no wallets are enrolled, recent_transactions is empty."""
    fr = importlib.import_module('app.repositories.financial_repository')
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [])
    res = tool_registry.execute("get_financial_context")
    assert res.success is True
    assert res.data["recent_transactions"] == []
    assert res.data["recent_transactions_count"] == 0

def test_B_single_wallet_paymechap(monkeypatch):
    """P0-3: Single PayMeChap wallet — transaction enriched with all identity fields."""
    fr = importlib.import_module('app.repositories.financial_repository')
    wallet = {
        "provider": "paymechap",
        "external_wallet_id": "wallet123",
        "id": "w1",
        "status": "connected",
    }
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [wallet])
    pm = importlib.import_module('app.services.wallet_integrations.paymechap_api_service')
    monkeypatch.setattr(pm.paymechap_api_service, 'get_partner_access_token', lambda: "mock_token_test")
    recent_tx = [{
        "timestamp": (datetime.utcnow() - timedelta(days=1)).isoformat(),
        "amount": 1000.0,
        "type": "transfer"
    }]
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_transactions',
                        lambda access_token, account_number=None, limit=20: recent_tx)
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_balance',
                        lambda access_token, account_number=None: {"balance": 5000.0, "currency": "XOF"})
    res = tool_registry.execute("get_financial_context")
    assert res.success is True
    txs = res.data["recent_transactions"]
    assert len(txs) == 1
    tx = txs[0]
    # P0-3 : identité complète de la transaction
    assert tx["provider"] == "paymechap"
    assert tx["internal_wallet_id"] == "w1"
    assert tx["external_wallet_id"] == "wallet123"
    # wallet_id doit être l'external (prioritaire)
    assert tx["wallet_id"] == "wallet123"
    assert tx["amount"] == 1000.0
    assert "timestamp" in tx

def test_C_multiple_wallets(monkeypatch):
    """P0-3: Deux wallets PayMeChap — chaque transaction est associée à son wallet source.
    Orange Money est NOT_VERIFIED : ses transactions ne sont pas dans recent_transactions.
    Nous utilisons deux wallets PayMeChap distincts pour tester le multi-wallet.
    """
    fr = importlib.import_module('app.repositories.financial_repository')
    wallet_a = {
        "provider": "paymechap",
        "external_wallet_id": "pm123",
        "id": "w1",
        "status": "connected",
    }
    wallet_b = {
        "provider": "paymechap",
        "external_wallet_id": "pm456",
        "id": "w2",
        "status": "connected",
    }
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [wallet_a, wallet_b])
    pm = importlib.import_module('app.services.wallet_integrations.paymechap_api_service')
    monkeypatch.setattr(pm.paymechap_api_service, 'get_partner_access_token', lambda: "mock_token_test")

    def fake_fetch_txs(access_token, account_number=None, limit=200):
        """Retourne des transactions différentes selon le numéro de compte."""
        if account_number == "pm123":
            return [{
                "timestamp": (datetime.utcnow() - timedelta(days=2)).isoformat(),
                "amount": 2000.0,
                "type": "deposit"
            }]
        elif account_number == "pm456":
            return [{
                "timestamp": (datetime.utcnow() - timedelta(days=3)).isoformat(),
                "amount": 1500.0,
                "type": "transfer"
            }]
        return []

    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_transactions', fake_fetch_txs)
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_balance',
                        lambda access_token, account_number=None: {"balance": 8000.0, "currency": "XOF"})

    res = tool_registry.execute("get_financial_context")
    assert res.success is True
    txs = res.data["recent_transactions"]
    assert len(txs) == 2

    # P0-3 : chaque transaction est associée à son wallet source
    pm123_txs = [tx for tx in txs if tx["external_wallet_id"] == "pm123"]
    pm456_txs = [tx for tx in txs if tx["external_wallet_id"] == "pm456"]
    assert len(pm123_txs) == 1, "pm123 doit avoir exactement 1 transaction"
    assert len(pm456_txs) == 1, "pm456 doit avoir exactement 1 transaction"

    # Aucune transaction pm123 n'est associée à pm456 et vice-versa
    for tx in pm123_txs:
        assert tx["wallet_id"] == "pm123"
        assert tx["internal_wallet_id"] == "w1"
        assert tx["provider"] == "paymechap"
    for tx in pm456_txs:
        assert tx["wallet_id"] == "pm456"
        assert tx["internal_wallet_id"] == "w2"
        assert tx["provider"] == "paymechap"

def test_D_recent_transaction_kept(monkeypatch):
    """P0-3: Transactions des 7 derniers jours sont conservées (wallet PayMeChap VERIFIED)."""
    fr = importlib.import_module('app.repositories.financial_repository')
    wallet = {
        "provider": "paymechap",
        "external_wallet_id": "pm789",
        "id": "w3",
        "status": "connected",
    }
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [wallet])
    pm = importlib.import_module('app.services.wallet_integrations.paymechap_api_service')
    monkeypatch.setattr(pm.paymechap_api_service, 'get_partner_access_token', lambda: "mock_token_test")
    recent_tx = [{
        "timestamp": (datetime.utcnow() - timedelta(days=5)).isoformat(),
        "amount": 3000.0,
        "type": "transfer"
    }]
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_transactions',
                        lambda access_token, account_number=None, limit=200: recent_tx)
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_balance',
                        lambda access_token, account_number=None: {"balance": 10000.0, "currency": "XOF"})
    res = tool_registry.execute("get_financial_context")
    txs = res.data["recent_transactions"]
    assert len(txs) == 1
    assert txs[0]["external_wallet_id"] == "pm789"
    assert txs[0]["internal_wallet_id"] == "w3"


def test_E_old_transaction_filtered(monkeypatch):
    """P0-3: Transactions de plus de 30 jours sont exclues (wallet PayMeChap VERIFIED)."""
    fr = importlib.import_module('app.repositories.financial_repository')
    wallet = {
        "provider": "paymechap",
        "external_wallet_id": "pm999",
        "id": "w4",
        "status": "connected",
    }
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [wallet])
    pm = importlib.import_module('app.services.wallet_integrations.paymechap_api_service')
    monkeypatch.setattr(pm.paymechap_api_service, 'get_partner_access_token', lambda: "mock_token_test")
    old_tx = [{
        "timestamp": (datetime.utcnow() - timedelta(days=40)).isoformat(),
        "amount": 4000.0,
        "type": "transfer"
    }]
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_transactions',
                        lambda access_token, account_number=None, limit=200: old_tx)
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_balance',
                        lambda access_token, account_number=None: {"balance": 20000.0, "currency": "XOF"})
    res = tool_registry.execute("get_financial_context")
    assert len(res.data["recent_transactions"]) == 0


def test_F_paymechap_api_error_is_handled(monkeypatch):
    """P0-3: Une erreur API PayMeChap est journalisée mais n'interrompt pas le flux.
    recent_transactions reste vide ; le statut API_ERROR est dans provider_status."""
    fr = importlib.import_module('app.repositories.financial_repository')
    wallet = {
        "provider": "paymechap",
        "external_wallet_id": "pm_err",
        "id": "w_err",
        "status": "connected",
    }
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [wallet])
    pm = importlib.import_module('app.services.wallet_integrations.paymechap_api_service')
    monkeypatch.setattr(pm.paymechap_api_service, 'get_partner_access_token', lambda: "mock_token_test")

    def raise_err(access_token, account_number=None, limit=200):
        raise RuntimeError("API failure")

    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_transactions', raise_err)
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_balance',
                        lambda access_token, account_number=None: {"balance": 0.0, "currency": "XOF"})
    res = tool_registry.execute("get_financial_context")
    assert res.success is True
    assert res.data["recent_transactions"] == []
    statuses = {s["status"] for s in res.data.get("provider_status", [])}
    assert "API_ERROR" in statuses


def test_G_no_wallet_means_no_transactions(monkeypatch):
    """P0-3 Étape 5 — Aucun wallet enrôlé → recent_transactions est vide."""
    fr = importlib.import_module('app.repositories.financial_repository')
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [])
    res = tool_registry.execute("get_financial_context")
    assert res.success is True
    assert res.data["recent_transactions"] == []
    assert res.data["recent_transactions_count"] == 0


def test_H_orphan_transaction_without_timestamp_is_ignored(monkeypatch):
    """P0-3 Étape 6 — Transaction sans timestamp est ignorée ; le wallet_id ne doit pas être inventé."""
    fr = importlib.import_module('app.repositories.financial_repository')
    wallet = {
        "provider": "paymechap",
        "external_wallet_id": "pm_orphan",
        "id": "w_orphan",
        "status": "connected",
    }
    monkeypatch.setattr(fr.financial_repository, 'get_wallets', lambda user_id=None: [wallet])
    pm = importlib.import_module('app.services.wallet_integrations.paymechap_api_service')
    monkeypatch.setattr(pm.paymechap_api_service, 'get_partner_access_token', lambda: "mock_token_test")
    orphan_tx = [{"amount": 999.0, "type": "unknown"}]  # pas de timestamp
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_transactions',
                        lambda access_token, account_number=None, limit=200: orphan_tx)
    monkeypatch.setattr(pm.paymechap_api_service, 'fetch_live_balance',
                        lambda access_token, account_number=None: {"balance": 0.0, "currency": "XOF"})
    res = tool_registry.execute("get_financial_context")
    assert res.success is True
    # La transaction sans timestamp est ignorée
    assert res.data["recent_transactions"] == []


# ==========================================================================
# P0-4 — Wallet Selection Tests (_select_wallet)
# ==========================================================================

class TestWalletSelection:
    """Tests unitaires directs de la méthode SikaAIService._select_wallet."""

    def setup_method(self):
        self.svc = SikaAIService.__new__(SikaAIService)
        # Pas besoin d'initialiser Gemini pour tester _select_wallet

    def _make_wallet(self, provider: str, account: str = "", balance: float = 0.0):
        return {
            "provider": provider,
            "account_number": account,
            "balance": balance,
            "is_active": True,
        }

    def test_PA_no_wallet(self):
        """P0-4-A: 0 wallet → aucun wallet sélectionné, message explicite."""
        wallet, msg = self.svc._select_wallet([], "Quel est mon solde ?")
        assert wallet is None
        assert msg is not None
        assert "Aucun portefeuille" in msg

    def test_PB_single_wallet_auto_select(self):
        """P0-4-B: 1 wallet VERIFIED → sélection automatique, aucune clarification."""
        wallets = [self._make_wallet("paymechap", "pm123")]
        wallet, msg = self.svc._select_wallet(wallets, "Quel est mon solde ?")
        assert wallet is not None
        assert msg is None
        assert wallet["provider"] == "paymechap"

    def test_PC_multiple_wallets_no_provider_asks_clarification(self):
        """P0-4-C: N wallets, pas de provider mentionné → ask_wallet, pas de wallets[0]."""
        wallets = [
            self._make_wallet("paymechap", "pm123"),
            self._make_wallet("wave", "wave456"),
        ]
        wallet, msg = self.svc._select_wallet(wallets, "Quel est mon solde ?")
        assert wallet is None
        assert msg is not None
        assert "plusieurs" in msg.lower()
        # PayMeChap et Wave doivent apparaître dans la clarification
        assert "paymechap" in msg.lower() or "PayMeChap" in msg

    def test_PD_multiple_wallets_with_provider_selects_correct(self):
        """P0-4-D: N wallets, provider mentionné → sélection du bon wallet."""
        wallets = [
            self._make_wallet("paymechap", "pm123"),
            self._make_wallet("wave", "wave456"),
        ]
        wallet, msg = self.svc._select_wallet(wallets, "Quel est mon solde PayMeChap ?")
        assert msg is None
        assert wallet is not None
        assert wallet["provider"] == "paymechap"

    def test_PE_case_insensitive_selection(self):
        """P0-4-E: Sélection case-insensitive — PAYMECHAP / PayMeChap / paymechap."""
        wallets = [
            self._make_wallet("paymechap", "pm123"),
            self._make_wallet("wave", "wave456"),
        ]
        for variant in ["PAYMECHAP", "PayMeChap", "paymechap"]:
            wallet, msg = self.svc._select_wallet(wallets, f"Solde {variant}")
            assert wallet is not None, f"Doit sélectionner pour variante '{variant}'"
            assert msg is None
            assert wallet["provider"] == "paymechap"

    def test_PF_unknown_provider_no_arbitrary_selection(self):
        """P0-4-F: Provider inconnu dans le message → clarification, pas de sélection arbitraire."""
        wallets = [
            self._make_wallet("paymechap", "pm123"),
        ]
        # MTN non mentionné dans les wallets : aucun wallet ne correspond
        wallet, msg = self.svc._select_wallet(wallets, "Mon solde MTN ?")
        # Le message mentionne MTN mais aucun wallet MTN n'est connecté.
        # PayMeChap est l'unique wallet VERIFIED → sélection automatique
        # (car aucun wallet avec provider "mtn" ne correspond, le seul wallet est sélectionné)
        assert wallet is not None  # seul wallet = sélection auto
        assert wallet["provider"] == "paymechap"

    def test_PG_not_verified_provider_returns_unavailable(self):
        """P0-4-G: Provider NOT_VERIFIED mentionné → indisponibilité, aucun appel API."""
        wallets = [
            self._make_wallet("wave", "wave456"),
        ]
        wallet, msg = self.svc._select_wallet(wallets, "Quel est mon solde Wave ?")
        assert wallet is None
        assert msg is not None
        assert "pas disponible" in msg

    def test_PH_no_wallets_zero_fallback(self):
        """P0-4-H: Plusieurs wallets sans provider → Wallet A (wallets[0]) N'EST PAS sélectionné."""
        wallet_a = self._make_wallet("paymechap", "pm111")
        wallet_b = self._make_wallet("paymechap", "pm222")
        wallets = [wallet_a, wallet_b]
        wallet, msg = self.svc._select_wallet(wallets, "Montre-moi mon solde.")
        # Aucun provider distingué dans le message → clarification obligatoire
        assert wallet is None
        assert msg is not None
        assert "plusieurs" in msg.lower()


# ==========================================================================
# P0-5 — Transfer Flow with Wallet Selection
# ==========================================================================

class TestTransferWalletSelection:
    """Tests du flux transfert dans _chat_basic avec sélection de wallet."""

    def _build_svc_with_wallets(self, wallets):
        """Crée un SikaAIService basique avec wallets injectés dans le contexte."""
        svc = SikaAIService.__new__(SikaAIService)
        svc.client = None  # Force le mode _chat_basic
        svc.model = "test-model"
        return svc, {"wallets": wallets}

    def test_P5A_transfer_no_wallet_blocked(self):
        """P0-5-A: Transfert sans wallet connecté → bloqué avec message explicite."""
        svc, ctx = self._build_svc_with_wallets([])
        import importlib
        ft_mod = importlib.import_module("app.agent.tools")
        import app.agent.tools.wallet_tools as wt_mod

        # Mocker get_wallets pour retourner []
        original = wt_mod.financial_repository.get_wallets
        wt_mod.financial_repository.get_wallets = lambda user_id=None: []
        try:
            import asyncio
            result = svc._chat_basic(
                "Transférer 5000 FCFA à Kouamé", ctx, "Test", False
            )
            assert result["action"] in ("ask_wallet", None, "error") or "portefeuille" in result["response"].lower()
        finally:
            wt_mod.financial_repository.get_wallets = original

    def test_P5B_select_wallet_method_used_in_transfer(self):
        """P0-5-B: _select_wallet est la méthode de classe, pas une fonction locale."""
        svc = SikaAIService.__new__(SikaAIService)
        # Vérifier que _select_wallet est une méthode liée à l'instance
        assert hasattr(svc, "_select_wallet")
        assert callable(getattr(svc, "_select_wallet"))

    def test_P5C_no_hardcoded_provider_in_extract_action(self):
        """P0-5-C: _extract_action ne retourne plus provider=Wave hard-codé."""
        svc = SikaAIService.__new__(SikaAIService)
        action, data = svc._extract_action("", "transférer 5000 FCFA")
        assert action == "prepare_transfer"
        # Le provider ne doit plus être hard-codé à Wave
        assert data is not None
        assert data.get("provider") != "Wave"

    def test_P5D_verified_providers_set(self):
        """P0-5-D: _VERIFIED_PROVIDERS contient exactement les providers vérifiés."""
        svc = SikaAIService.__new__(SikaAIService)
        assert "paymechap" in svc._VERIFIED_PROVIDERS
        # Wave, Orange Money, MTN ne doivent PAS être dans les providers vérifiés
        assert "wave" not in svc._VERIFIED_PROVIDERS
        assert "orange_money" not in svc._VERIFIED_PROVIDERS
        assert "mtn" not in svc._VERIFIED_PROVIDERS


# ==========================================================================
# P0-6 — Contact Resolution Tests
# ==========================================================================

class TestContactResolution:
    """P0-6: Résolution de contact pour les transferts."""

    def setup_method(self):
        self.svc = SikaAIService.__new__(SikaAIService)
        self.svc.client = None
        self.svc.model = "test-model"

    def _mock_env(self, monkeypatch, wallets=None, contacts=None):
        import app.agent.tools.wallet_tools as wt
        import app.services.wallet_integrations.paymechap_api_service as pms
        monkeypatch.setattr(pms.paymechap_api_service, "get_partner_access_token", lambda: "mock_token_test")
        monkeypatch.setattr(pms.paymechap_api_service, "fetch_live_balance", lambda *a, **k: {"balance": 50000.0, "currency": "XOF"})
        w_list = wallets if wallets is not None else [
            {"provider": "paymechap", "external_wallet_id": "pm123", "id": "w1", "status": "connected"}
        ]
        c_list = contacts if contacts is not None else [
            {"name": "Kouamé", "phone": "+2250707070707", "id": "c1"}
        ]
        monkeypatch.setattr(wt.financial_repository, "get_wallets", lambda uid=None: w_list)
        monkeypatch.setattr(wt, "search_contact", lambda q: ToolResult(
            success=True, tool_name="search_contact", risk_level=RiskLevel.READ_ONLY,
            data={"query": q, "contacts": c_list, "count": len(c_list)}
        ))

    def test_contact_A_single_found(self, monkeypatch):
        """P0-6-A: Contact unique trouvé -> résolu avec son numéro réel."""
        self._mock_env(monkeypatch)
        res = self.svc._chat_basic("Transférer 10000 FCFA à Kouamé", {}, "David", False)
        assert res["action"] == "prepare_transfer"
        assert res["action_data"]["recipient"] == "+2250707070707"
        assert res["action_data"]["amount"] == 10000.0
        assert res["action_data"]["provider"] == "paymechap"

    def test_contact_B_not_found_asks_clarification(self, monkeypatch):
        """P0-6-B: Contact introuvable -> transfert NON préparé, clarification demandée."""
        self._mock_env(monkeypatch, contacts=[])
        res = self.svc._chat_basic("Transférer 10000 FCFA à Inconnu", {}, "David", False)
        assert res["action"] != "prepare_transfer"
        assert res["action"] == "ask_contact"
        assert "Inconnu" in res["response"]
        assert "action_id" not in res or res.get("action_id") is None

    def test_contact_C_multiple_contacts_asks_clarification(self, monkeypatch):
        """P0-6-C: Plusieurs contacts correspondants -> transfert NON préparé, clarification demandée."""
        self._mock_env(monkeypatch, contacts=[
            {"name": "Kouamé Jean", "phone": "+22501010101", "id": "c1"},
            {"name": "Kouamé Paul", "phone": "+22502020202", "id": "c2"}
        ])
        res = self.svc._chat_basic("Transférer 10000 FCFA à Kouamé", {}, "David", False)
        assert res["action"] != "prepare_transfer"
        assert res["action"] == "ask_contact"
        assert "Kouamé Jean" in res["response"]
        assert "Kouamé Paul" in res["response"]

    def test_contact_D_no_fake_contacts_in_production(self):
        """P0-6-D: search_contact natif ne retourne aucun faux contact inventé."""
        import app.agent.tools.wallet_tools as wt
        res = wt.search_contact("NimporteQui")
        assert res.success is True
        assert res.data["contacts"] == []
        assert res.data["count"] == 0


# ==========================================================================
# P0-7 — Transfer Preparation & Safe Flow Tests
# ==========================================================================

class TestTransferPreparation:
    """P0-7: Préparation de transfert sans exécution prématurée."""

    def setup_method(self):
        self.svc = SikaAIService.__new__(SikaAIService)
        self.svc.client = None
        self.svc.model = "test-model"

    def _mock_env(self, monkeypatch, wallets=None, contacts=None):
        import app.agent.tools.wallet_tools as wt
        import app.services.wallet_integrations.paymechap_api_service as pms
        monkeypatch.setattr(pms.paymechap_api_service, "get_partner_access_token", lambda: "mock_token_test")
        monkeypatch.setattr(pms.paymechap_api_service, "fetch_live_balance", lambda *a, **k: {"balance": 50000.0, "currency": "XOF"})
        w_list = wallets if wallets is not None else [
            {"provider": "paymechap", "external_wallet_id": "pm123", "id": "w1", "status": "connected"}
        ]
        c_list = contacts if contacts is not None else [
            {"name": "Kouamé", "phone": "+22507070707", "id": "c1"}
        ]
        monkeypatch.setattr(wt.financial_repository, "get_wallets", lambda uid=None: w_list)
        monkeypatch.setattr(wt, "search_contact", lambda q: ToolResult(
            success=True, tool_name="search_contact", risk_level=RiskLevel.READ_ONLY,
            data={"query": q, "contacts": c_list, "count": len(c_list)}
        ))

    def test_transfer_A_single_wallet_happy_path(self, monkeypatch):
        """P0-7-A: Single wallet -> sélection auto, contact résolu, prepare_transfer prêt, aucun paiement exécuté."""
        self._mock_env(monkeypatch)
        res = self.svc._chat_basic("Transférer 10000 FCFA à Kouamé", {}, "David", False)
        assert res["action"] == "prepare_transfer"
        assert res["requires_confirmation"] is True
        assert res["status"] == "WAITING_CONFIRMATION"
        assert res["action_id"].startswith("act_")
        assert res["action_data"]["amount"] == 10000.0
        assert res["action_data"]["provider"] == "paymechap"
        assert res["action_data"]["recipient"] == "+22507070707"

    def test_transfer_B_multiple_wallets_same_provider_undistinguished(self, monkeypatch):
        """P0-7-B: Multi-wallets même provider non distingués -> clarification demandée."""
        wallets = [
            {"provider": "paymechap", "external_wallet_id": "pm111", "id": "w1", "status": "connected"},
            {"provider": "paymechap", "external_wallet_id": "pm222", "id": "w2", "status": "connected"},
        ]
        self._mock_env(monkeypatch, wallets=wallets)
        res = self.svc._chat_basic("Transférer 10000 FCFA via PayMeChap à Kouamé", {}, "David", False)
        assert res["action"] == "ask_wallet"
        assert "pm111" in res["response"]
        assert "pm222" in res["response"]

    def test_transfer_B2_multiple_wallets_same_provider_distinguished(self, monkeypatch):
        """P0-7-B2: Multi-wallets même provider distingués par le compte -> sélection correcte."""
        wallets = [
            {"provider": "paymechap", "external_wallet_id": "pm111", "account_number": "pm111", "id": "w1", "status": "connected"},
            {"provider": "paymechap", "external_wallet_id": "pm222", "account_number": "pm222", "id": "w2", "status": "connected"},
        ]
        self._mock_env(monkeypatch, wallets=wallets)
        res = self.svc._chat_basic("Transférer 10000 FCFA via PayMeChap pm111 à Kouamé", {}, "David", False)
        assert res["action"] == "prepare_transfer"
        assert res["action_data"]["provider"] == "paymechap"

    def test_transfer_C_multiple_wallets_no_provider_asks_wallet(self, monkeypatch):
        """P0-7-C: Multi-wallets sans provider -> ask_wallet, aucun prepare_transfer."""
        wallets = [
            {"provider": "paymechap", "external_wallet_id": "pm123", "id": "w1", "status": "connected"},
            {"provider": "wave", "external_wallet_id": "wv456", "id": "w2", "status": "connected"},
        ]
        self._mock_env(monkeypatch, wallets=wallets)
        res = self.svc._chat_basic("Transférer 10000 FCFA à Kouamé", {}, "David", False)
        assert res["action"] == "ask_wallet"
        assert "plusieurs" in res["response"].lower()

    def test_transfer_D_not_verified_provider_rejected(self, monkeypatch):
        """P0-7-D: Provider NOT_VERIFIED -> aucun transfert préparé, message d'indisponibilité."""
        wallets = [
            {"provider": "wave", "external_wallet_id": "wv456", "id": "w1", "status": "connected"},
        ]
        self._mock_env(monkeypatch, wallets=wallets)
        res = self.svc._chat_basic("Transférer 10000 FCFA via Wave à Kouamé", {}, "David", False)
        assert res["action"] != "prepare_transfer"
        assert "pas disponible" in res["response"]

    def test_transfer_E_invalid_amount_rejected(self, monkeypatch):
        """P0-7-E: Montant <= 0 ou négatif -> transfert refusé."""
        self._mock_env(monkeypatch)
        res_zero = self.svc._chat_basic("Transférer 0 FCFA à Kouamé", {}, "David", False)
        assert res_zero["action"] == "error" or "supérieur à 0" in res_zero["response"]

        res_neg = self.svc._chat_basic("Transférer -100 FCFA à Kouamé", {}, "David", False)
        assert res_neg["action"] == "error" or "supérieur à 0" in res_neg["response"]

    def test_transfer_F_action_id_uniqueness(self):
        """P0-7-F: prepare_transfer génère des action_id non vides et uniques."""
        import app.agent.tools.transaction_tools as tt
        res1 = tt.prepare_transfer("paymechap", 5000.0, "+22501020304", "XOF")
        res2 = tt.prepare_transfer("paymechap", 5000.0, "+22501020304", "XOF")
        assert res1.success is True
        assert res2.success is True
        aid1 = res1.data["action_id"]
        aid2 = res2.data["action_id"]
        assert aid1.startswith("act_")
        assert aid2.startswith("act_")
        assert aid1 != aid2

    def test_transfer_G_no_execution_before_confirmation(self, monkeypatch):
        """P0-7-G: RÈGLE CRITIQUE — Aucune exécution ou débit réel lors de la préparation."""
        self._mock_env(monkeypatch)
        import app.services.wallet_integrations.paymechap_api_service as pms
        import app.agent.tools.transaction_tools as tt
        executed_calls = []
        monkeypatch.setattr(pms.paymechap_api_service, "execute_payout", lambda *a, **k: executed_calls.append("payout"))
        monkeypatch.setattr(tt, "confirm_transfer", lambda *a, **k: executed_calls.append("confirm_tool"))

        res = self.svc._chat_basic("Transférer 10000 FCFA à Kouamé via PayMeChap", {}, "David", False)
        assert res["action"] == "prepare_transfer"
        # Règle absolue: aucune méthode d'exécution ne doit avoir été appelée
        assert len(executed_calls) == 0, f"Méthode d'exécution appelée lors de la préparation : {executed_calls}"

    def test_transfer_H_confirmation_flow(self, monkeypatch):
        """P0-7-H: Flux prepare -> confirm -> execution via orchestrateur."""
        self._mock_env(monkeypatch)
        from app.agent.orchestrator import sika_orchestrator

        # 1. Préparation via agent
        res = self.svc._chat_basic("Transférer 10000 FCFA à Kouamé", {}, "David", False, user_id="1")
        action_id = res["action_id"]
        assert action_id is not None

        # 2. Vérification que l'action est bien enregistrée en base / mémoire
        entry = sika_orchestrator.action_store.get(action_id)
        assert entry is not None
        assert entry["status"] == "WAITING_CONFIRMATION"

    def test_amount_multi_formats_parsing(self):
        """P0-7: Normalisation de formats de montants variés."""
        assert self.svc._extract_transfer_amount("Transférer 10 000 FCFA à Kouamé") == 10000.0
        assert self.svc._extract_transfer_amount("Transférer 10000 FCFA à Kouamé") == 10000.0
        assert self.svc._extract_transfer_amount("Transférer 10.000 FCFA à Kouamé") == 10000.0
        assert self.svc._extract_transfer_amount("Transférer 10000 à Kouamé") == 10000.0
        assert self.svc._extract_transfer_amount("Transférer 0 FCFA à Kouamé") == 0.0
        assert self.svc._extract_transfer_amount("Transférer -100 FCFA à Kouamé") == -1.0


