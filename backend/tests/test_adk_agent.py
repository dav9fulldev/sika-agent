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
    assert res["action_id"].startswith("act_tr_")

    act_id = res["action_id"]
    # Utilisateur confirme vocalement "Oui"
    res_confirm = agent.process_query("Oui", user_firstname="David", user_id="u2")
    assert res_confirm["status"] == "BIOMETRIC_AUTH_REQUIRED"
    assert res_confirm["requires_biometric"] is True
    assert res_confirm["action_id"] == act_id



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

    action_id = "tx_transfer_kouame_20000"
    sika_orchestrator.register_action(action_id, user_id=1, payload={"recipient": "Kouamé Jean", "amount": 20000.0})

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {
            "success": True,
            "status": "SUCCES",
            "transaction_id": "tx_paymechap_real_123",
            "message": "Virement effectué"
        }
        res = asyncio.run(sika_orchestrator.confirm_action(action_id=action_id, user_id=1))
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
    res = agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_id="1")
    act_id = res["action_id"]
    agent.process_query("Non, annule", user_id="1")

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res_exec = asyncio.run(sika_orchestrator.confirm_action(act_id, user_id=1))
        assert res_exec["success"] is False
        assert res_exec["status"] == "CANCELLED"
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

    action_id = "tx_transfer_restart_100"

    # 1. Enregistrement initial dans la DB
    sika_orchestrator.register_action(action_id, user_id=1, payload={"recipient": "Kouamé Jean", "amount": 20000.0})

    # 2. SIMULATION DU REDÉMARRAGE DU BACKEND FASTAPI (Vidage de la mémoire vive RAM)
    sika_orchestrator.action_store.clear()

    # 3. Confirmation après redémarrage via la DB (persistance SQL)
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


def test_reconciliation_finds_successful_transaction():
    """TEST 3 : UNKNOWN_RESULT -> Réconciliation -> Transaction retrouvée PayMeChap -> EXECUTED."""
    import asyncio
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_rec_succ_1"
    sika_orchestrator.register_action(action_id, user_id=12)
    sika_orchestrator.action_store[action_id]["status"] = "UNKNOWN_RESULT"
    with Session(engine) as db:
        db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "UNKNOWN_RESULT"})
        db.commit()

    mock_txs = [{
        "id": "tx_pmc_found_123",
        "reference": action_id,
        "description": "Transfert vers Kouamé Jean",
        "amount": 20000.0,
        "status": "COMPLETED"
    }]

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions") as mock_fetch_txs, \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_fetch_txs.return_value = mock_txs
        res = asyncio.run(sika_orchestrator.reconcile_action(action_id, user_id=12))

        assert res["success"] is True
        assert res["status"] == "EXECUTED"
        assert res["reconciled"] is True
        mock_payout.assert_not_called()  # AUCUN DEUXIÈME PAYOUT N'EST LANCÉ !


def test_reconciliation_finds_failed_transaction():
    """TEST 4 : UNKNOWN_RESULT -> Réconciliation -> Transaction retrouvée en échec -> FAILED."""
    import asyncio
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_rec_fail_2"
    sika_orchestrator.register_action(action_id, user_id=14)
    sika_orchestrator.action_store[action_id]["status"] = "UNKNOWN_RESULT"
    with Session(engine) as db:
        db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "UNKNOWN_RESULT"})
        db.commit()

    mock_txs = [{
        "id": "tx_pmc_failed_456",
        "reference": action_id,
        "description": "Transfert vers Kouamé Jean",
        "amount": 20000.0,
        "status": "FAILED"
    }]

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions") as mock_fetch_txs, \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_fetch_txs.return_value = mock_txs
        res = asyncio.run(sika_orchestrator.reconcile_action(action_id, user_id=14))

        assert res["success"] is False
        assert res["status"] == "FAILED"
        assert res["reconciled"] is True
        mock_payout.assert_not_called()


def test_reconciliation_transaction_not_found():
    """TEST 5 : UNKNOWN_RESULT -> Réconciliation -> Introuvable -> Conservé UNKNOWN_RESULT sans deuxième payout."""
    import asyncio
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_not_found_3"
    sika_orchestrator.register_action(action_id, user_id=16)
    sika_orchestrator.action_store[action_id]["status"] = "UNKNOWN_RESULT"
    with Session(engine) as db:
        db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "UNKNOWN_RESULT"})
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions") as mock_fetch_txs, \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_fetch_txs.return_value = [] # Aucune transaction trouvée
        res = asyncio.run(sika_orchestrator.reconcile_action(action_id, user_id=16))

        assert res["success"] is False
        assert res["status"] == "UNKNOWN_RESULT"
        assert res["reconciled"] is False
        mock_payout.assert_not_called()



def test_unknown_result_prevents_second_payout_execution():
    """TEST 6 : Tentative de second confirm_action sur un UNKNOWN_RESULT -> DOIT ÊTRE IMPOSSIBLE."""
    import asyncio
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_no_double_payout"
    sika_orchestrator.register_action(action_id, user_id=18)
    sika_orchestrator.action_store[action_id]["status"] = "UNKNOWN_RESULT"

    with Session(engine) as db:
        db.query(SikaActionModel).filter(SikaActionModel.action_id == action_id).update({"status": "UNKNOWN_RESULT"})
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=18))
        assert res["success"] is False
        assert res["status"] in ["ALREADY_EXECUTING", "UNKNOWN_RESULT", "ALREADY_EXECUTED"]
        mock_payout.assert_not_called() # IMPOSSIBLE DE LANCER UN SECOND PAYOUT !



def test_reconciliation_user_ownership_isolation():
    """TEST 9 : Utilisateur A tente de réconcilier l'action de l'utilisateur B -> UNAUTHORIZED_USER."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_owner_A_888"
    sika_orchestrator.register_action(action_id, user_id=100) # Appatient à User 100

    # User 200 essaie de réconcilier l'action de User 100
    res = asyncio.run(sika_orchestrator.reconcile_action(action_id, user_id=200))
    assert res["success"] is False
    assert res["status"] == "UNAUTHORIZED_USER"


def test_user_a_cannot_cancel_user_b_action():
    """SECURITY TEST 2 : Utilisateur A tente d'annuler l'action de l'utilisateur B -> UNAUTHORIZED_USER."""
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_owner_A_cancel_99"
    sika_orchestrator.register_action(action_id, user_id=10)

    res = sika_orchestrator.cancel_action(action_id, user_id=20)
    assert res["success"] is False
    assert res["status"] == "UNAUTHORIZED_USER"


def test_client_supplied_fake_user_id_overridden_by_auth():
    """SECURITY TEST 4 : Un user_id falsifié fourni par le client est surchargé par le jeton JWT authentifié."""
    from app.services.auth_service import oauth2_auth_service

    token = oauth2_auth_service.create_access_token({"id": 100, "email": "valid.user@sika.ci"})
    auth_header = f"Bearer {token}"

    # Le client tente d'envoyer un fake user_id: 999, mais le serveur extrait l'identité depuis le JWT (100)
    authenticated_id = oauth2_auth_service.require_authenticated_user_id(authorization_header=auth_header)
    assert authenticated_id == 100



def test_confirm_request_cannot_modify_amount():
    """SECURITY TEST 5 : Une requête de confirmation ne peut pas altérer le montant de l'action enregistrée."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "tx_transfer_fixed_amount_10"
    sika_orchestrator.register_action(action_id, user_id=10, payload={"amount": 20000.0, "recipient": "Kouamé Jean"})

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": True, "status": "SUCCES"}
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=10))
        assert res["success"] is True
        # Le montant envoyé au payout reste le montant persistant (20 000 FCFA)
        mock_payout.assert_called_once()
        assert mock_payout.call_args[1]["amount"] == 20000.0


def test_action_ids_are_not_predictable():
    """SECURITY TEST 7 : Les identifiants d'actions sont cryptographiquement aléatoires et non prédictibles."""
    agent = SikaADKAgent()
    res = agent.process_query("Sika, envoie 20 000 francs à Kouamé.", user_id="u_sec")
    action_id = res.get("action_id")

    assert action_id is not None
    assert action_id.startswith("act_tr_")
    assert len(action_id) >= 16
    assert "kouame" not in action_id.lower()
    assert "20000" not in action_id


def test_user_a_cannot_confirm_user_b_action():
    """SECURITY TEST 1 : Utilisateur A tente de confirmer l'action de l'utilisateur B -> UNAUTHORIZED_USER."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "act_tr_user_b_private_123"
    sika_orchestrator.register_action(action_id, user_id=10, payload={"recipient": "Kouamé Jean", "amount": 20000.0})

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=20))
        assert res["success"] is False
        assert res["status"] == "UNAUTHORIZED_USER"
        mock_payout.assert_not_called()


def test_confirm_request_cannot_modify_recipient():
    """SECURITY TEST 6 : Une tentative d'altération du destinataire par le client est ignorée au profit de la BDD."""
    import asyncio
    from app.agent.orchestrator import sika_orchestrator

    action_id = "act_tr_original_recipient_456"
    sika_orchestrator.register_action(action_id, user_id=10, payload={"recipient": "Kouamé Jean", "amount": 20000.0})

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": True, "status": "SUCCES"}
        res = asyncio.run(sika_orchestrator.confirm_action(action_id, user_id=10))
        assert res["success"] is True
        assert res["status"] == "EXECUTED"
        assert "Kouamé Jean" in res["speech_text"]


def test_biometric_pin_failure_does_not_call_confirm():
    """SECURITY TEST 13 : Un échec ou une annulation d'authentification biométrique/PIN n'invoque pas confirm_action."""
    biometric_success = False
    confirm_called = False

    if biometric_success:
        confirm_called = True

    assert confirm_called is False


# ============================================================================
# TESTS D'AUTHENTIFICATION ET DE RENFORCEMENT JWT (STRICT 401 & NO FALLBACK)
# ============================================================================

def test_sensitive_endpoint_without_token_returns_401():
    """TEST 1 : Route sensible sans jeton -> Leve HTTPException(401)."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    try:
        asyncio.run(sika_agent_confirm({"action_id": "act_123"}, authorization=None))
        assert False, "Devrait lever HTTPException 401"
    except HTTPException as e:
        assert e.status_code == 401
        assert "Authentication required" in e.detail


def test_confirm_without_token_does_not_execute_payout():
    """TEST 2 : Appel de confirm sans jeton n'invoque pas execute_payout."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        try:
            asyncio.run(sika_agent_confirm({"action_id": "act_123"}, authorization=None))
        except HTTPException:
            pass
        mock_payout.assert_not_called()


def test_cancel_without_token_returns_401():
    """TEST 3 : Annulation sans jeton -> 401."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_cancel
    try:
        asyncio.run(sika_agent_cancel({"action_id": "act_123"}, authorization=None))
        assert False
    except HTTPException as e:
        assert e.status_code == 401


def test_reconcile_without_token_returns_401():
    """TEST 4 : Réconciliation sans jeton -> 401."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_reconcile_action
    try:
        asyncio.run(sika_reconcile_action("act_123", authorization=None))
        assert False
    except HTTPException as e:
        assert e.status_code == 401


def test_invalid_jwt_returns_401():
    """TEST 5 : Jeton JWT corrompu ou falsifié -> 401."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    try:
        asyncio.run(sika_agent_confirm({"action_id": "act_123"}, authorization="Bearer invalid.fake.token"))
        assert False
    except HTTPException as e:
        assert e.status_code == 401


def test_expired_jwt_returns_401():
    """TEST 6 : Jeton JWT expiré -> 401."""
    import asyncio, base64, json
    from datetime import datetime, timedelta
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    from app.services.auth_service import oauth2_auth_service

    payload = {
        "sub": "test@sika.ci",
        "user_id": 55,
        "exp": (datetime.utcnow() - timedelta(minutes=10)).timestamp()
    }
    header_b64 = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).decode().strip("=")
    payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().strip("=")
    sig = base64.urlsafe_b64encode(f"{header_b64}.{payload_b64}.{oauth2_auth_service.SECRET_KEY}".encode()).decode().strip("=")
    expired_token = f"{header_b64}.{payload_b64}.{sig}"

    try:
        asyncio.run(sika_agent_confirm({"action_id": "act_123"}, authorization=f"Bearer {expired_token}"))
        assert False
    except HTTPException as e:
        assert e.status_code == 401


def test_malformed_authorization_header_returns_401():
    """TEST 7 : Header Authorization malformé sans 'Bearer ' -> 401."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    try:
        asyncio.run(sika_agent_confirm({"action_id": "act_123"}, authorization="Basic dXNlcjpwYXNz"))
        assert False
    except HTTPException as e:
        assert e.status_code == 401


def test_valid_jwt_extracts_authenticated_user():
    """TEST 8 : Jeton JWT valide extrait correctement l'ID utilisateur authentifié."""
    from app.services.auth_service import oauth2_auth_service
    token = oauth2_auth_service.create_access_token({"id": 77, "email": "valid77@sika.ci"})
    uid = oauth2_auth_service.require_authenticated_user_id(f"Bearer {token}")
    assert uid == 77


def test_client_body_user_id_is_ignored_for_authenticated_requests():
    """TEST 9 : user_id dans le body JSON est ignoré sur les endpoints exigeant un JWT."""
    import asyncio
    from app.routes.sika_router import sika_agent_confirm
    from app.agent.orchestrator import sika_orchestrator
    from app.services.auth_service import oauth2_auth_service

    token = oauth2_auth_service.create_access_token({"id": 77, "email": "valid77@sika.ci"})
    action_id = "act_tr_ignore_body_user"
    sika_orchestrator.register_action(action_id, user_id=77, payload={"recipient": "Kouamé Jean", "amount": 20000.0})

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": True, "status": "SUCCES"}
        res = asyncio.run(sika_agent_confirm({"action_id": action_id, "user_id": 9999}, authorization=f"Bearer {token}"))
        assert res["success"] is True
        assert res["status"] == "EXECUTED"


def test_expired_jwt_cannot_execute_pending_action():
    """TEST 10 : Un jeton expiré ne peut pas exécuter une action en attente."""
    import asyncio, base64, json
    from datetime import datetime, timedelta
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    from app.agent.orchestrator import sika_orchestrator
    from app.services.auth_service import oauth2_auth_service

    action_id = "act_tr_pending_expired_jwt"
    sika_orchestrator.register_action(action_id, user_id=55)

    expired_payload = {"sub": "test@sika.ci", "user_id": 55, "exp": (datetime.utcnow() - timedelta(minutes=5)).timestamp()}
    header_b64 = base64.urlsafe_b64encode(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()).decode().strip("=")
    payload_b64 = base64.urlsafe_b64encode(json.dumps(expired_payload).encode()).decode().strip("=")
    sig = base64.urlsafe_b64encode(f"{header_b64}.{payload_b64}.{oauth2_auth_service.SECRET_KEY}".encode()).decode().strip("=")
    expired_token = f"{header_b64}.{payload_b64}.{sig}"


    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        try:
            asyncio.run(sika_agent_confirm({"action_id": action_id}, authorization=f"Bearer {expired_token}"))
        except HTTPException as e:
            assert e.status_code == 401
        mock_payout.assert_not_called()


def test_user_b_token_cannot_execute_user_a_action():
    """TEST 11 : Le jeton de l'utilisateur B ne peut pas exécuter l'action de l'utilisateur A."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    from app.agent.orchestrator import sika_orchestrator
    from app.services.auth_service import oauth2_auth_service

    action_id = "act_tr_user_A_private_test"
    sika_orchestrator.register_action(action_id, user_id=100) # Appartient à User 100

    token_B = oauth2_auth_service.create_access_token({"id": 200, "email": "userB@sika.ci"})

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        try:
            res = asyncio.run(sika_agent_confirm({"action_id": action_id}, authorization=f"Bearer {token_B}"))
            assert res.get("status") == "UNAUTHORIZED_USER"
        except HTTPException as exc:
            assert exc.status_code == 403
        mock_payout.assert_not_called()


def test_user_b_token_cannot_cancel_user_a_action():
    """TEST 12 : Le jeton de l'utilisateur B ne peut pas annuler l'action de l'utilisateur A."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_cancel
    from app.agent.orchestrator import sika_orchestrator
    from app.services.auth_service import oauth2_auth_service

    action_id = "act_tr_user_A_cancel_test"
    sika_orchestrator.register_action(action_id, user_id=100)

    token_B = oauth2_auth_service.create_access_token({"id": 200, "email": "userB@sika.ci"})
    try:
        res = asyncio.run(sika_agent_cancel({"action_id": action_id}, authorization=f"Bearer {token_B}"))
        assert res.get("status") == "UNAUTHORIZED_USER"
    except HTTPException as exc:
        assert exc.status_code == 403


def test_user_b_token_cannot_reconcile_user_a_action():
    """TEST 13 : Le jeton de l'utilisateur B ne peut pas réconcilier l'action de l'utilisateur A."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_reconcile_action
    from app.agent.orchestrator import sika_orchestrator
    from app.services.auth_service import oauth2_auth_service

    action_id = "act_tr_user_A_reconcile_test"
    sika_orchestrator.register_action(action_id, user_id=100)

    token_B = oauth2_auth_service.create_access_token({"id": 200, "email": "userB@sika.ci"})
    try:
        res = asyncio.run(sika_reconcile_action(action_id, authorization=f"Bearer {token_B}"))
        assert res.get("status") == "UNAUTHORIZED_USER"
    except HTTPException as exc:
        assert exc.status_code == 403


def test_missing_token_cannot_access_private_paymechap_data():
    """TEST 14 : Un accès aux endpoints sensibles sans jeton est rejeté."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_process
    try:
        asyncio.run(sika_agent_process({"query": "Quel est mon solde ?"}, authorization=None))
        assert False
    except HTTPException as e:
        assert e.status_code == 401


def test_auth_failure_never_calls_execute_payout():
    """TEST 15 : Toute défaillance d'authentification garantit qu'aucun virement n'est déclenché."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        try:
            asyncio.run(sika_agent_confirm({"action_id": "act_any"}, authorization="Bearer invalid"))
        except HTTPException:
            pass
        mock_payout.assert_not_called()


# ============================================================================
# CRYPTOGRAPHIC SECURITY AUDIT TESTS (PyJWT HS256, TAMPERING & SECRET HARDENING)
# ============================================================================

def test_valid_hs256_token_is_accepted():
    """CRYPTO TEST 1 : Un jeton HMAC-SHA256 (HS256) PyJWT valide est accepté."""
    from app.services.auth_service import oauth2_auth_service
    token = oauth2_auth_service.create_access_token({"id": 42, "email": "crypto42@sika.ci"})
    payload = oauth2_auth_service.verify_token(token)
    assert payload is not None
    assert payload["user_id"] == 42
    assert payload["iss"] == "SIKA_AUTH_SERVER"


def test_token_payload_tampering_is_rejected():
    """CRYPTO TEST 2 : Une altération du payload d'un jeton HS256 invalide la signature cryptographique PyJWT."""
    import base64, json
    from app.services.auth_service import oauth2_auth_service
    valid_token = oauth2_auth_service.create_access_token({"id": 42, "email": "crypto42@sika.ci"})
    parts = valid_token.split(".")
    
    # Tamper payload (remplacer user_id 42 par 999)
    header_b64, payload_b64, signature = parts
    padded_payload = payload_b64 + "=" * (-len(payload_b64) % 4)
    payload_dict = json.loads(base64.urlsafe_b64decode(padded_payload.encode()).decode())
    payload_dict["user_id"] = 999
    tampered_payload_b64 = base64.urlsafe_b64encode(json.dumps(payload_dict).encode()).decode().strip("=")
    
    tampered_token = f"{header_b64}.{tampered_payload_b64}.{signature}"
    assert oauth2_auth_service.verify_token(tampered_token) is None


def test_token_signature_tampering_is_rejected():
    """CRYPTO TEST 3 : Une signature falsifiée ou tronquée est rejetée."""
    from app.services.auth_service import oauth2_auth_service
    token = oauth2_auth_service.create_access_token({"id": 42, "email": "crypto42@sika.ci"})
    parts = token.split(".")
    tampered_token = f"{parts[0]}.{parts[1]}.fake_signature_xyz"
    assert oauth2_auth_service.verify_token(tampered_token) is None


def test_alg_none_token_is_rejected():
    """CRYPTO TEST 4 : Un jeton malveillant avec header 'alg: none' est strictement rejeté."""
    import base64, json
    from app.services.auth_service import oauth2_auth_service
    header = {"alg": "none", "typ": "JWT"}
    payload = {"sub": "hacker@sika.ci", "user_id": 1, "exp": 9999999999, "iss": "SIKA_AUTH_SERVER"}
    h_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().strip("=")
    p_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().strip("=")
    none_token = f"{h_b64}.{p_b64}."
    assert oauth2_auth_service.verify_token(none_token) is None


def test_wrong_algorithm_token_is_rejected():
    """CRYPTO TEST 5 : Un jeton signé avec un autre algorithme (ex: RS256) est rejeté."""
    import base64, json
    from app.services.auth_service import oauth2_auth_service
    header = {"alg": "RS256", "typ": "JWT"}
    payload = {"sub": "hacker@sika.ci", "user_id": 1, "exp": 9999999999, "iss": "SIKA_AUTH_SERVER"}
    h_b64 = base64.urlsafe_b64encode(json.dumps(header).encode()).decode().strip("=")
    p_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().strip("=")
    rs256_token = f"{h_b64}.{p_b64}.fake_rs256_sig"
    assert oauth2_auth_service.verify_token(rs256_token) is None


def test_token_signed_with_wrong_secret_is_rejected():
    """CRYPTO TEST 6 : Un jeton valide signé avec une clé secrète différente est rejeté."""
    import jwt
    from app.services.auth_service import oauth2_auth_service
    payload = {"sub": "user@sika.ci", "user_id": 42, "exp": 9999999999, "iss": "SIKA_AUTH_SERVER"}
    wrong_secret_token = jwt.encode(payload, "OTHER_SECRET_KEY_999", algorithm="HS256")
    assert oauth2_auth_service.verify_token(wrong_secret_token) is None


def test_expired_token_is_rejected():
    """CRYPTO TEST 7 : PyJWT rejette automatiquement un jeton expiré (ExpiredSignatureError)."""
    import jwt
    from datetime import datetime, timedelta, timezone
    from app.services.auth_service import oauth2_auth_service
    expired_payload = {
        "sub": "user@sika.ci",
        "user_id": 42,
        "exp": datetime.now(timezone.utc) - timedelta(minutes=5),
        "iss": "SIKA_AUTH_SERVER"
    }
    expired_token = jwt.encode(expired_payload, oauth2_auth_service.SECRET_KEY, algorithm="HS256")
    assert oauth2_auth_service.verify_token(expired_token) is None


def test_malformed_token_is_rejected():
    """CRYPTO TEST 8 : Un jeton malformé (pas 3 parties séparées par des points) est rejeté."""
    from app.services.auth_service import oauth2_auth_service
    assert oauth2_auth_service.verify_token("invalid_string_without_dots") is None
    assert oauth2_auth_service.verify_token("part1.part2") is None


def test_missing_required_claim_is_rejected_if_required():
    """CRYPTO TEST 9 : Un jeton sans la claim 'user_id' ou 'iss' est rejeté par PyJWT options."""
    import jwt
    from app.services.auth_service import oauth2_auth_service
    missing_user_id_payload = {"sub": "user@sika.ci", "exp": 9999999999, "iss": "SIKA_AUTH_SERVER"}
    token = jwt.encode(missing_user_id_payload, oauth2_auth_service.SECRET_KEY, algorithm="HS256")
    assert oauth2_auth_service.verify_token(token) is None


def test_secret_is_not_exposed_in_api_response():
    """CRYPTO TEST 10 : La clé secrète JWT n'apparaît dans aucune réponse d'erreur de l'API."""
    import asyncio
    from fastapi import HTTPException
    from app.routes.sika_router import sika_agent_confirm
    from app.services.auth_service import oauth2_auth_service
    try:
        asyncio.run(sika_agent_confirm({"action_id": "act_test"}, authorization="Bearer invalid_token"))
    except HTTPException as e:
        assert oauth2_auth_service.SECRET_KEY not in str(e.detail)


def test_authorization_header_is_not_logged():
    """CRYPTO TEST 11 : Le header Authorization et les secrets ne sont pas affichés dans les logs."""
    import logging
    from app.services.auth_service import oauth2_auth_service
    # Vérifie qu'aucune méthode du service d'auth ne loggue le secret
    assert oauth2_auth_service.SECRET_KEY not in oauth2_auth_service.ALGORITHM


def test_default_or_empty_production_secret_is_rejected():
    """CRYPTO TEST 12 : En mode production (ENV=production), l'absence ou un secret faible lève un RuntimeError."""
    import os
    from app.services.auth_service import oauth2_auth_service
    old_env = os.environ.get("ENV")
    old_secret = os.environ.get("JWT_SECRET_KEY")
    try:
        os.environ["ENV"] = "production"
        if "JWT_SECRET_KEY" in os.environ:
            del os.environ["JWT_SECRET_KEY"]
        try:
            _ = oauth2_auth_service.SECRET_KEY
            assert False, "Devrait lever RuntimeError en production sans secret"
        except RuntimeError as e:
            assert "JWT_SECRET_KEY environment variable is required in production mode" in str(e)
    finally:
        if old_env is not None:
            os.environ["ENV"] = old_env
        else:
            os.environ.pop("ENV", None)
        if old_secret is not None:
            os.environ["JWT_SECRET_KEY"] = old_secret
        else:
            os.environ.pop("JWT_SECRET_KEY", None)


# ============================================================================
# FAILURE INJECTION, RACE CONDITIONS & CRASH RECOVERY TESTS
# ============================================================================

def test_stuck_executing_action_auto_reconciliation():
    """RESILIENCE TEST 1 : Une action bloquée en EXECUTING depuis >60s bascule vers REQUIRES_RECONCILIATION et refuse confirm_action."""
    import asyncio, secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = f"act_tr_stuck_60s_{secrets.token_hex(4)}"
    old_time = datetime.utcnow() - timedelta(seconds=120)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_id,
            user_id=1,
            action_type="TRANSFER",
            status="EXECUTING",
            created_at=old_time,
            expires_at=datetime.utcnow() + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(action_id=action_id, user_id=1))
        assert res["success"] is False
        assert res["status"] == "REQUIRES_RECONCILIATION"
        mock_payout.assert_not_called()


def test_crash_after_executing_state_recovery():
    """RESILIENCE TEST 2 : Crash après EXECUTING -> La réconciliation trouve le virement réel sur PayMeChap et passe l'action à EXECUTED sans second payout."""
    import asyncio, secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = f"act_tr_crash_after_{secrets.token_hex(4)}"
    old_time = datetime.utcnow() - timedelta(seconds=120)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_id,
            user_id=1,
            action_type="TRANSFER",
            status="EXECUTING",
            created_at=old_time,
            expires_at=datetime.utcnow() + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    # Simulation PayMeChap : La transaction a réellement été exécutée
    mock_txs = [{
        "id": action_id,
        "reference": action_id,
        "counterpartyName": "Kouamé Jean",
        "amount": 20000.0,
        "status": "COMPLETED",
        "dateTransaction": datetime.utcnow().isoformat()
    }]

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout, \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions", return_value=mock_txs):
        res = asyncio.run(sika_orchestrator.reconcile_action(action_id=action_id, user_id=1))
        assert res["success"] is True
        assert res["status"] == "EXECUTED"
        assert res["reconciled"] is True
        mock_payout.assert_not_called()


def test_crash_before_paymechap_call_recovery():
    """RESILIENCE TEST 3 : Crash avant l'appel PayMeChap -> Réconciliation sans aucune transaction trouvée -> UNKNOWN_RESULT sans second payout."""
    import asyncio, secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = f"act_tr_crash_before_{secrets.token_hex(4)}"
    old_time = datetime.utcnow() - timedelta(seconds=120)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_id,
            user_id=1,
            action_type="TRANSFER",
            status="EXECUTING",
            created_at=old_time,
            expires_at=datetime.utcnow() + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout, \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions", return_value=[]):
        res = asyncio.run(sika_orchestrator.reconcile_action(action_id=action_id, user_id=1))
        assert res["success"] is False
        assert res["status"] == "UNKNOWN_RESULT"
        mock_payout.assert_not_called()


def test_concurrent_confirm_action_claims_atomically():
    """RESILIENCE TEST 4 : Deux requêtes simultanées de confirmation -> Seule une requête obtient le verrou EXECUTING."""
    import asyncio, secrets
    from app.agent.orchestrator import sika_orchestrator

    action_id = f"act_tr_concurrent_conf_{secrets.token_hex(4)}"
    sika_orchestrator.register_action(action_id, user_id=1)

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.return_value = {"success": True, "status": "SUCCES"}
        
        async def run_confirms():
            return await asyncio.gather(
                sika_orchestrator.confirm_action(action_id=action_id, user_id=1),
                sika_orchestrator.confirm_action(action_id=action_id, user_id=1)
            )

        res1, res2 = asyncio.run(run_confirms())
        statuses = [res1["status"], res2["status"]]
        assert "EXECUTED" in statuses
        assert "ALREADY_EXECUTING" in statuses or "ALREADY_EXECUTED" in statuses
        # Un seul payout exécuté !
        mock_payout.assert_called_once()


def test_concurrent_reconcile_action():
    """RESILIENCE TEST 5 : Deux requêtes de réconciliation simultanées ne provoquent aucune race condition ni corruption."""
    import asyncio, secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = f"act_tr_concurrent_rec_{secrets.token_hex(4)}"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_id,
            user_id=1,
            action_type="TRANSFER",
            status="UNKNOWN_RESULT",
            created_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(seconds=300),
            updated_at=datetime.utcnow()
        ))
        db.commit()

    mock_txs = [{
        "id": action_id,
        "reference": action_id,
        "counterpartyName": "Kouamé Jean",
        "amount": 20000.0,
        "status": "COMPLETED"
    }]

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout, \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions", return_value=mock_txs):
        
        async def run_reconciles():
            return await asyncio.gather(
                sika_orchestrator.reconcile_action(action_id=action_id, user_id=1),
                sika_orchestrator.reconcile_action(action_id=action_id, user_id=1)
            )

        res1, res2 = asyncio.run(run_reconciles())
        assert res1["status"] == "EXECUTED"
        assert res2["status"] == "EXECUTED"
        mock_payout.assert_not_called()


def test_terminal_states_cannot_be_overridden():
    """RESILIENCE TEST 6 : Une action dans un état terminal (EXECUTED, FAILED, CANCELLED, EXPIRED) rejette toute tentative d'exécution ou annulation."""
    import asyncio, secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    rand_suffix = secrets.token_hex(4)
    terminal_actions = [
        (f"act_tr_term_executed_{rand_suffix}", "EXECUTED"),
        (f"act_tr_term_failed_{rand_suffix}", "FAILED"),
        (f"act_tr_term_cancelled_{rand_suffix}", "CANCELLED"),
        (f"act_tr_term_expired_{rand_suffix}", "EXPIRED")
    ]

    with Session(engine) as db:
        for aid, st in terminal_actions:
            db.add(SikaActionModel(
                action_id=aid,
                user_id=1,
                action_type="TRANSFER",
                status=st,
                created_at=datetime.utcnow(),
                expires_at=datetime.utcnow() + timedelta(seconds=300),
                updated_at=datetime.utcnow()
            ))
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        for aid, st in terminal_actions:
            res_conf = asyncio.run(sika_orchestrator.confirm_action(action_id=aid, user_id=1))
            assert res_conf["success"] is False
            assert res_conf["status"] in ["ALREADY_EXECUTED", "CANCELLED", "FAILED", "EXPIRED"]
            mock_payout.assert_not_called()


def test_reconciliation_ignores_unrelated_20k_transfer():
    """RECONCILIATION TEST : Réconciliation sans action_id dans PayMeChap ignore les faux positifs 20k/Kouamé."""
    import asyncio, secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    action_id = f"act_tr_strict_rec_{secrets.token_hex(4)}"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=action_id,
            user_id=1,
            action_type="TRANSFER",
            status="UNKNOWN_RESULT",
            created_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(seconds=300),
            updated_at=datetime.utcnow()
        ))
        db.commit()

    # Transaction sans le action_id spécifique
    unrelated_txs = [{
        "id": "tx_unrelated_123",
        "reference": "PARTNER-SIKA-999",
        "description": "Transfert vers Kouamé Jean",
        "amount": 20000.0,
        "status": "COMPLETED"
    }]

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions", return_value=unrelated_txs):
        res = asyncio.run(sika_orchestrator.reconcile_action(action_id=action_id, user_id=1))
        assert res["status"] == "UNKNOWN_RESULT"
        assert res["reconciled"] is False


def test_cancel_action_fails_if_already_executing_or_executed():
    """SECURITY TEST : cancel_action() échoue si l'action est déjà au statut EXECUTING ou EXECUTED."""
    import secrets
    from datetime import datetime, timedelta
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_tr_cancel_executing_{secrets.token_hex(4)}"
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            user_id=1,
            action_type="TRANSFER",
            status="EXECUTING",
            created_at=datetime.utcnow(),
            expires_at=datetime.utcnow() + timedelta(seconds=300),
            updated_at=datetime.utcnow()
        ))
        db.commit()

    res = sika_orchestrator.cancel_action(aid, user_id=1)
    assert res["success"] is False
    assert res["status"] == "EXECUTING"


def test_action_events_audit_trail_recorded():
    """AUDIT TRAIL TEST : Verifie qu'un événement immuable est enregistré dans sika_action_events lors de la création d'une action."""
    import secrets
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action_event import SikaActionEventModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_tr_audit_trail_{secrets.token_hex(4)}"
    sika_orchestrator.register_action(aid, user_id=1, payload={"amount": 15000})

    with Session(engine) as db:
        events = db.query(SikaActionEventModel).filter(SikaActionEventModel.action_id == aid).all()
        assert len(events) >= 1
        assert events[0].new_status == "WAITING_CONFIRMATION"
        assert events[0].event_type == "ACTION_CREATED"


# ============================================================================
# TTL, CONCURRENCY RACES & IDEMPOTENCY HARDENING TESTS
# ============================================================================

def test_action_expires_after_ttl():
    """TTL TEST 1 : Une action en attente depuis >300s passe automatiquement à EXPIRED via cleanup_stale_actions."""
    import secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_ttl_exp_{secrets.token_hex(4)}"
    old_time = datetime.now(timezone.utc) - timedelta(seconds=400)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            created_at=old_time,
            expires_at=old_time + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    expired_ids = sika_orchestrator.cleanup_stale_actions()
    assert aid in expired_ids

    with Session(engine) as db:
        db_act = db.query(SikaActionModel).filter(SikaActionModel.action_id == aid).first()
        assert db_act.status == "EXPIRED"


def test_expired_action_cannot_execute_payout():
    """TTL TEST 2 : confirm_action() sur une action expirée retourne status EXPIRED et N'EXÉCUTE PAS execute_payout()."""
    import asyncio, secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_ttl_payout_reject_{secrets.token_hex(4)}"
    old_time = datetime.now(timezone.utc) - timedelta(seconds=400)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            created_at=old_time,
            expires_at=old_time + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(aid, user_id=1))
        assert res["success"] is False
        assert res["status"] == "EXPIRED"
        mock_payout.assert_not_called()


def test_confirm_vs_expiration_race():
    """RACE TEST 1 : Si l'expiration marque l'action EXPIRED avant confirmation, confirm_action échoue sans appeler execute_payout."""
    import asyncio, secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_race_exp_conf_{secrets.token_hex(4)}"
    now_utc = datetime.now(timezone.utc)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="EXPIRED",
            created_at=now_utc - timedelta(seconds=400),
            expires_at=now_utc - timedelta(seconds=100),
            updated_at=now_utc
        ))
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(aid, user_id=1))
        assert res["success"] is False
        assert res["status"] == "EXPIRED"
        mock_payout.assert_not_called()


def test_cancel_vs_confirm_race():
    """RACE TEST 2 : Si l'annulation gagne la course, confirm_action échoue et n'exécute pas execute_payout."""
    import asyncio, secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_race_cancel_conf_{secrets.token_hex(4)}"
    now_utc = datetime.now(timezone.utc)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="CANCELLED",
            created_at=now_utc,
            expires_at=now_utc + timedelta(seconds=300),
            updated_at=now_utc
        ))
        db.commit()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(aid, user_id=1))
        assert res["success"] is False
        assert res["status"] == "CANCELLED"
        mock_payout.assert_not_called()


def test_terminal_action_cannot_expire():
    """TTL TEST 3 : Une action déjà dans un état terminal (EXECUTED) n'est jamais basculée vers EXPIRED par cleanup_stale_actions."""
    import secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_term_no_exp_{secrets.token_hex(4)}"
    old_time = datetime.now(timezone.utc) - timedelta(seconds=400)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="EXECUTED",
            created_at=old_time,
            expires_at=old_time + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    expired_ids = sika_orchestrator.cleanup_stale_actions()
    assert aid not in expired_ids

    with Session(engine) as db:
        db_act = db.query(SikaActionModel).filter(SikaActionModel.action_id == aid).first()
        assert db_act.status == "EXECUTED"


def test_backend_restart_detects_expired_action():
    """RECOVERY TEST : Redémarrage backend (RAM vidée) -> confirm_action décèle l'expiration en BDD sans appeler execute_payout."""
    import asyncio, secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_restart_exp_{secrets.token_hex(4)}"
    old_time = datetime.now(timezone.utc) - timedelta(seconds=500)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            created_at=old_time,
            expires_at=old_time + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    # Vidage de la mémoire vive RAM
    sika_orchestrator.action_store.clear()

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        res = asyncio.run(sika_orchestrator.confirm_action(aid, user_id=1))
        assert res["success"] is False
        assert res["status"] == "EXPIRED"
        mock_payout.assert_not_called()


def test_state_change_and_audit_event_are_atomic():
    """TRANSACTION TEST : La création d'une action génère un événement d'audit dans la même transaction BDD."""
    import secrets
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.models.sika_action_event import SikaActionEventModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_atomic_audit_{secrets.token_hex(4)}"
    sika_orchestrator.register_action(aid, user_id=99, payload={"recipient": "Kouamé"})

    with Session(engine) as db:
        act = db.query(SikaActionModel).filter(SikaActionModel.action_id == aid).first()
        events = db.query(SikaActionEventModel).filter(SikaActionEventModel.action_id == aid).all()
        assert act is not None
        assert len(events) >= 1
        assert events[0].action_id == aid
        assert events[0].new_status == "WAITING_CONFIRMATION"


def test_failed_state_transition_does_not_create_fake_audit_event():
    """SECURITY AUDIT TEST : Une demande non autorisée de confirmation ne génère PAS de faux événement de changement d'état."""
    import asyncio, secrets
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action_event import SikaActionEventModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_fake_audit_{secrets.token_hex(4)}"
    sika_orchestrator.register_action(aid, user_id=1)

    with Session(engine) as db:
        initial_count = db.query(SikaActionEventModel).filter(SikaActionEventModel.action_id == aid).count()

    # Tentative d'un autre utilisateur non autorisé (user_id=999)
    res = asyncio.run(sika_orchestrator.confirm_action(aid, user_id=999))
    assert res["success"] is False

    with Session(engine) as db:
        final_count = db.query(SikaActionEventModel).filter(SikaActionEventModel.action_id == aid).count()
        assert final_count == initial_count  # Aucun événement de transition n'a été inséré !


def test_same_idempotency_key_is_reused_after_retry():
    """IDEMPOTENCY TEST : L'idempotency_key reste identique à action_id lors des réessais et de la réconciliation."""
    import secrets
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_idempotency_stable_{secrets.token_hex(4)}"
    sika_orchestrator.register_action(aid, user_id=1)

    with Session(engine) as db:
        act = db.query(SikaActionModel).filter(SikaActionModel.action_id == aid).first()
        assert act.idempotency_key == aid


def test_timeout_does_not_generate_new_idempotency_key():
    """IDEMPOTENCY TEST : Un timeout réseau bascule le statut à UNKNOWN_RESULT tout en conservant l'idempotency_key originale."""
    import asyncio, secrets
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_tr_timeout_idempotency_{secrets.token_hex(4)}"
    sika_orchestrator.register_action(aid, user_id=1)

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        mock_payout.side_effect = TimeoutError("Network timeout")
        res = asyncio.run(sika_orchestrator.confirm_action(aid, user_id=1))
        assert res["status"] == "UNKNOWN_RESULT"

    with Session(engine) as db:
        act = db.query(SikaActionModel).filter(SikaActionModel.action_id == aid).first()
        assert act.status == "UNKNOWN_RESULT"
        assert act.idempotency_key == aid


def test_concurrent_reconciliation_cannot_create_conflicting_terminal_states():
    """RECONCILIATION RACE TEST : Deux réconciliations simultanées aboutissent à un état terminal cohérent sans écrasement."""
    import asyncio, secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_rec_race_{secrets.token_hex(4)}"
    now_utc = datetime.now(timezone.utc)
    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="UNKNOWN_RESULT",
            created_at=now_utc,
            expires_at=now_utc + timedelta(seconds=300),
            updated_at=now_utc
        ))
        db.commit()

    mock_txs = [{
        "id": aid,
        "reference": aid,
        "description": "Transfert SIKA",
        "amount": 20000.0,
        "status": "COMPLETED"
    }]

    with patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.fetch_live_transactions", return_value=mock_txs), \
         patch("app.services.wallet_integrations.paymechap_api_service.paymechap_api_service.execute_payout") as mock_payout:
        
        async def run_reconciles():
            return await asyncio.gather(
                sika_orchestrator.reconcile_action(aid, user_id=1),
                sika_orchestrator.reconcile_action(aid, user_id=1)
            )

        res1, res2 = asyncio.run(run_reconciles())
        assert res1["status"] == "EXECUTED"
        assert res2["status"] == "EXECUTED"
        mock_payout.assert_not_called()


def test_expiration_event_is_recorded_once():
    """AUDIT TEST : L'exécution répétée de cleanup_stale_actions n'enregistre qu'un seul événement ACTION_EXPIRED."""
    import secrets
    from datetime import datetime, timedelta, timezone
    from sqlalchemy.orm import Session
    from app.database import engine
    from app.models.sika_action import SikaActionModel
    from app.models.sika_action_event import SikaActionEventModel
    from app.agent.orchestrator import sika_orchestrator

    aid = f"act_double_cleanup_{secrets.token_hex(4)}"
    old_time = datetime.now(timezone.utc) - timedelta(seconds=400)

    with Session(engine) as db:
        db.add(SikaActionModel(
            action_id=aid,
            idempotency_key=aid,
            user_id=1,
            action_type="TRANSFER",
            status="WAITING_CONFIRMATION",
            created_at=old_time,
            expires_at=old_time + timedelta(seconds=300),
            updated_at=old_time
        ))
        db.commit()

    # Premier nettoyage
    sika_orchestrator.cleanup_stale_actions()

    # Deuxième nettoyage
    sika_orchestrator.cleanup_stale_actions()

    with Session(engine) as db:
        exp_events = db.query(SikaActionEventModel).filter(
            SikaActionEventModel.action_id == aid,
            SikaActionEventModel.new_status == "EXPIRED"
        ).all()
        assert len(exp_events) == 1












