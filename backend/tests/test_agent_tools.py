"""
Suite de Tests pour les Tools Financiers et le ToolRegistry de SIKA (Phase 5 Étape 2)
"""

import pytest
from app.agent.tool_registry import tool_registry
from app.agent.tools.tool_models import RiskLevel, ToolResult
import app.agent.tools  # S'assurer que tous les tools sont enregistrés

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

def test_2_get_wallets():
    """2. get_wallets fonctionne et retourne les comptes connus."""
    res = tool_registry.execute("get_wallets")
    assert res.success is True
    assert res.risk_level == RiskLevel.READ_ONLY
    assert len(res.data["wallets"]) == 3
    assert res.data["wallets"][0]["provider"] == "wave"

def test_3_get_wallet_balance():
    """3. get_wallet_balance fonctionne pour un compte précis."""
    res = tool_registry.execute("get_wallet_balance", {"provider": "wave"})
    assert res.success is True
    assert res.data["balance"] == 50000.0
    assert res.data["currency"] == "XOF"

    res_om = tool_registry.execute("get_wallet_balance", {"provider": "orange_money"})
    assert res_om.success is True
    assert res_om.data["balance"] == 25000.0

def test_4_get_total_balance():
    """4. get_total_balance calcule la somme totale (50k + 25k + 15k = 90k XOF)."""
    res = tool_registry.execute("get_total_balance")
    assert res.success is True
    assert res.data["total_balance"] == 90000.0

def test_5_get_recent_transactions():
    """5. get_recent_transactions retourne les opérations observées."""
    res = tool_registry.execute("get_recent_transactions", {"limit": 2})
    assert res.success is True
    assert len(res.data["transactions"]) == 2
    assert "provider" in res.data["transactions"][0]

def test_6_get_spending_summary():
    """6. get_spending_summary retourne l'analyse des dépenses par catégorie."""
    res = tool_registry.execute("get_spending_summary", {"days": 30})
    assert res.success is True
    assert res.data["total_spent"] > 0
    assert "category_breakdown" in res.data

def test_7_prepare_transfer():
    """7. prepare_transfer retourne confirmation_required sans exécuter."""
    res = tool_registry.execute("prepare_transfer", {
        "provider": "wave",
        "amount": 5000.0,
        "recipient": "Kouamé"
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

def test_11_readonly_tools_cannot_trigger_execution():
    """11. Les tools READ_ONLY conservent leur niveau de risque sans modifier de données."""
    res = tool_registry.execute("get_financial_context")
    assert res.risk_level == RiskLevel.READ_ONLY
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
