import os
import pytest
from unittest.mock import MagicMock, patch
from app.agents import sika_adk_agent, SikaADKAgent
from app.agents.tools import get_total_balance, get_savings_status


def test_google_adk_import():
    """Vérifie que le package Google ADK est installé et importable."""
    import google.adk
    assert google.adk is not None


def test_adk_balance_tool():
    """Vérifie le fonctionnement de l'outil get_total_balance."""
    res = get_total_balance()
    assert res["success"] is True
    assert "total_balance" in res
    assert res["currency"] == "XOF"
    assert "wallets" in res


def test_adk_savings_tool():
    """Vérifie le fonctionnement de l'outil get_savings_status."""
    res = get_savings_status()
    assert res["success"] is True
    assert "coffre_name" in res
    assert "current_amount" in res
    assert "target_amount" in res


def test_scenario_1_balance_query():
    """SCÉNARIO 1 : Consultation du solde."""
    agent = SikaADKAgent()
    res = agent.process_query("Sika, quel est mon solde ?", user_firstname="David", user_id="u1")
    assert res["success"] is True
    assert res["tool_used"] == "get_total_balance"
    assert res["should_speak"] is True
    assert res["requires_confirmation"] is False


def test_scenario_2_and_3_transfer_and_voice_confirmation():
    """SCÉNARIOS 2 & 3 : Transfert urgent + Confirmation vocale 'Oui'."""
    agent = SikaADKAgent()
    res = agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_firstname="David", user_id="u2")
    assert res["status"] == "WAITING_VOICE_CONFIRMATION"
    assert res["requires_confirmation"] is True
    assert res["action_id"] == "tx_transfer_kouame_20000"

    # Utilisateur confirme vocalement "Oui"
    res_confirm = agent.process_query("Oui", user_firstname="David", user_id="u2")
    assert res_confirm["status"] == "BIOMETRIC_AUTH_REQUIRED"
    assert res_confirm["requires_biometric"] is True
    assert res_confirm["action_id"] == "tx_transfer_kouame_20000"


def test_scenario_5_cancellation():
    """SCÉNARIO 5 : Annulation vocale 'Non'."""
    agent = SikaADKAgent()
    agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_firstname="David", user_id="u5")
    res_cancel = agent.process_query("Non, annule", user_firstname="David", user_id="u5")
    assert res_cancel["status"] == "CANCELLED"
    assert res_cancel["requires_confirmation"] is False


def test_scenario_6_and_7_ambiguity_resolution():
    """SCÉNARIOS 6 & 7 : Gestion d'ambiguïté 'Jean' et sélection 'Jean Kouamé'."""
    agent = SikaADKAgent()
    res_amb = agent.process_query("Envoie 10 000 à Jean", user_firstname="David", user_id="u6")
    assert res_amb["status"] == "AMBIGUITY_ASKED"
    assert "Jean Kouamé" in res_amb["response"]

    # Reprise du contexte avec "Jean Kouamé"
    res_selected = agent.process_query("Jean Kouamé", user_firstname="David", user_id="u6")
    assert res_selected["status"] == "WAITING_VOICE_CONFIRMATION"
    assert "Jean Kouamé" in res_selected["response"]
    assert res_selected["requires_confirmation"] is True


def test_scenario_8_savings_deposit():
    """SCÉNARIO 8 : Épargne par commande vocale."""
    agent = SikaADKAgent()
    res = agent.process_query("Sika, mets 10 000 francs dans mon coffre.", user_firstname="David", user_id="u8")
    assert res["status"] == "WAITING_VOICE_CONFIRMATION"
    assert res["requires_confirmation"] is True
    assert "10 000" in res["response"] or "10 000" in res["speech_text"]


def test_scenario_9_financial_advisor():
    """SCÉNARIO 9 : Conseiller financier et analyse de dépenses."""
    agent = SikaADKAgent()
    res = agent.process_query("Sika, analyse mes dépenses et dis-moi comment économiser.", user_firstname="David", user_id="u9")
    assert res["tool_used"] == "get_spending_summary"
    assert res["status"] == "EXECUTED"
    assert "Restauration" in res["response"] or "retraits" in res["response"] or "dépensé" in res["response"]


def test_scenario_10_multi_user_isolation():
    """SCÉNARIO 10 : Isolation des sessions multi-utilisateurs."""
    agent = SikaADKAgent()
    # Utilisateur A prépare un transfert
    agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_id="user_A")
    # Utilisateur B consulte son solde
    res_b = agent.process_query("Sika, quel est mon solde ?", user_id="user_B")

    session_a = agent.get_user_session("user_A")
    session_b = agent.get_user_session("user_B")

    assert session_a["state"] == "WAITING_VOICE_CONFIRMATION"
    assert session_b["state"] == "EXECUTED"
    assert res_b["tool_used"] == "get_total_balance"


def test_paymechap_real_execution_via_confirm_action():
    """Vérifie l'exécution réelle via PayMeChap lors de la confirmation d'action par l'orchestrateur."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {
            "success": True,
            "status": "SUCCES",
            "transaction_id": "tx_paymechap_real_123",
            "message": "Virement effectué"
        }
        res = asyncio.run(sika_orchestrator.confirm_action(action_id="tx_transfer_kouame_20000", user_id=1))
        assert res["success"] is True
        assert res["status"] == "EXECUTED"
        assert "Kouamé Jean" in res["speech_text"]
        assert res["should_speak"] is True
        mock_payout.assert_called_once()


def test_new_request_while_action_pending():
    """Vérifie qu'une nouvelle requête annule la transaction en attente précédente."""
    agent = SikaADKAgent()
    agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_id="u_pending")
    session = agent.get_user_session("u_pending")
    assert session["state"] == "WAITING_VOICE_CONFIRMATION"

    # L'utilisateur change d'avis et pose une nouvelle question
    res_new = agent.process_query("Quel est mon solde ?", user_id="u_pending")
    assert res_new["tool_used"] == "get_total_balance"
    assert session["state"] == "EXECUTED"


def test_cancelled_action_cannot_execute():
    """Vérifie qu'une action annulée ne peut pas être exécutée sur PayMeChap."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    agent = SikaADKAgent()
    agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_id="u_cancel")
    agent.process_query("Non, annule", user_id="u_cancel")

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action("tx_transfer_kouame_20000", user_id=1))
        assert res["success"] is False
        assert res["status"] == "CANCELLED"
        mock_payout.assert_not_called()


def test_idempotency_prevents_duplicate_execution():
    """Vérifie qu'un même action_id ne peut pas être exécuté deux fois (Idempotence)."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_idem_20000"
    sika_orchestrator.register_action(action_id, user_id=99)

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": True, "transaction_id": "tx_first_call"}
        res1 = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=99))
        assert res1["success"] is True

        # Deuxième tentative avec le même action_id
        res2 = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=99))
        assert res2["success"] is False
        assert res2["status"] == "ALREADY_EXECUTED"
        assert mock_payout.call_count == 1  # L'API PayMeChap n'est appelée qu'une seule fois !


def test_expired_action_cannot_execute():
    """Vérifie qu'une action expirée (> TTL 300s) est rejetée."""
    import asyncio, time
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_expired_100"
    sika_orchestrator.register_action(action_id, user_id=77, ttl_seconds=300)
    sika_orchestrator.action_store[action_id]["created_at"] = time.time() - 360

    with Session(engine) as db:
        db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({
            "expires_at": datetime.utcnow() - timedelta(seconds=60)
        })
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=77))
        assert res["success"] is False
        assert res["status"] == "EXPIRED"
        mock_payout.assert_not_called()



def test_paymechap_failure_produces_failed_status():
    """Vérifie qu'un échec de l'API PayMeChap produit le statut FAILED sans solde fictif."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_fail_55"
    sika_orchestrator.register_action(action_id, user_id=55)

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": False, "message": "PayMeChap inaccessible"}
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=55))
        assert res["success"] is False
        assert res["status"] == "FAILED"
        assert "PayMeChap" in res["speech_text"]


def test_backend_restart_simulation_persists_action_and_session():
    """Simule un crash / redémarrage de FastAPI et vérifie que la DB réhydrate l'action et la session."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    agent = SikaADKAgent()
    user_id = "restart_user_100"
    action_id = "tx_transfer_restart_100"

    # 1. Création initiale et persistance DB
    agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_id=user_id)

    # 2. SIMULATION DU REDÉMARRAGE DU BACKEND FASTAPI (Vidage de la mémoire vive)
    sika_orchestrator.action_store.clear()
    agent.user_sessions.clear()

    # 3. Vérification de la restauration DB de la session
    restored_session = agent.get_user_session(user_id)
    assert restored_session["state"] == "WAITING_VOICE_CONFIRMATION"

    # 4. Confirmation après redémarrage via la DB
    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": True, "transaction_id": "tx_restart_pass"}
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=1))
        assert res["success"] is True
        assert res["status"] == "EXECUTED"


def test_user_ownership_isolation():
    """Vérifie qu'un utilisateur A ne peut JAMAIS confirmer une action créée par un utilisateur B."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_user_A_999"
    sika_orchestrator.register_action(action_id, user_id=10) # Créé par user_id 10

    # User B (user_id 20) essaie d'exécuter l'action de User A
    res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=20))
    assert res["success"] is False
    assert res["status"] == "UNAUTHORIZED_USER"


def test_uncertain_paymechap_result_sets_unknown_status():
    """Vérifie qu'une coupure réseau lors du payout met le statut à UNKNOWN_RESULT sans retenter."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_timeout_777"
    sika_orchestrator.register_action(action_id, user_id=77)

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.side_effect = TimeoutError("Délai d'attente réseau dépassé sur PayMeChap API")
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=77))
        assert res["success"] is False
        assert res["status"] == "UNKNOWN_RESULT"
        assert "incertain" in res["speech_text"].lower()



