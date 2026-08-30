import pytest
import asyncio
import uuid
import json
import requests
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock

from app.agent.orchestrator import sika_orchestrator
from app.models.sika_action import SikaActionModel
from app.models.user import UserModel
from app.database import engine, Base
from sqlalchemy.orm import Session
from sqlalchemy.exc import OperationalError

@pytest.fixture(autouse=True)
def setup_teardown_db():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        user = db.query(UserModel).filter(UserModel.id == 1).first()
        if not user:
            user = UserModel(id=1, email="test@sika.com", phone="0102030405", full_name="Test")
            db.add(user)
            db.commit()
    yield


def create_mock_action(db_session, action_id, status="UNKNOWN_RESULT", started_at=None):
    action = SikaActionModel(
        action_id=action_id,
        user_id=1,
        status=status,
        action_type="transfer",
        payload_json=json.dumps({"amount": 1000, "recipient_phone": "0701020304"}),
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=10),
        reconciliation_started_at=started_at
    )
    db_session.add(action)
    db_session.commit()
    return action

@pytest.fixture
def db_session():
    with Session(engine) as session:
        yield session

# TEST 13 is critical and applies to all tests, so we autouse a fixture to mock and assert execute_payout is never called
@pytest.fixture(autouse=True)
def prevent_financial_execution():
    with patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.execute_payout') as mock_payout, \
         patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.deposit_to_coffre') as mock_deposit:
        
        mock_payout.side_effect = Exception("SECURITY-5 CRITICAL FAILURE: execute_payout MUST NEVER BE CALLED DURING RECONCILIATION")
        mock_deposit.side_effect = Exception("SECURITY-5 CRITICAL FAILURE: deposit_to_coffre MUST NEVER BE CALLED DURING RECONCILIATION")
        
        yield mock_payout, mock_deposit
        
        # Test 13: Strict assertion that financial functions were NEVER called
        assert mock_payout.call_count == 0, "execute_payout a été appelé !"
        assert mock_deposit.call_count == 0, "deposit_to_coffre a été appelé !"

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_1_reconciliation_success(mock_fetch, db_session):
    action_id = f"recon_succ_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.return_value = [{"id": action_id, "status": "SUCCESS"}]
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    
    assert res["status"] == "EXECUTED"
    assert res["success"] is True
    
    db_action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    assert db_action.status == "EXECUTED"

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_2_reconciliation_completed(mock_fetch, db_session):
    action_id = f"recon_comp_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.return_value = [{"reference": action_id, "status": "COMPLETED"}]
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    
    assert res["status"] == "EXECUTED"

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_3_reconciliation_failed(mock_fetch, db_session):
    action_id = f"recon_fail_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.return_value = [{"idempotency_key": action_id, "status": "FAILED"}]
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    
    assert res["status"] == "FAILED"
    assert res["success"] is False

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_4_reconciliation_pending(mock_fetch, db_session):
    action_id = f"recon_pend_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.return_value = [{"id": action_id, "status": "PENDING"}]
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    
    assert res["status"] == "UNKNOWN_RESULT"

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_5_reconciliation_not_found(mock_fetch, db_session):
    action_id = f"recon_not_found_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.return_value = [{"id": "another_tx", "status": "SUCCESS"}]
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    
    assert res["status"] == "UNKNOWN_RESULT"

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_6_reconciliation_read_timeout(mock_fetch, db_session):
    action_id = f"recon_timeout_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.side_effect = requests.exceptions.ReadTimeout("Timeout")
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    assert res["status"] == "UNKNOWN_RESULT"

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_7_reconciliation_conn_error(mock_fetch, db_session):
    action_id = f"recon_conn_err_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    mock_fetch.side_effect = requests.exceptions.ConnectionError("Connection closed")
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    assert res["status"] == "UNKNOWN_RESULT"

@pytest.mark.asyncio
async def test_8_reconciliation_on_executed_refused(db_session):
    action_id = f"recon_exec_{uuid.uuid4()}"
    create_mock_action(db_session, action_id, status="EXECUTED")
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    assert res["status"] == "EXECUTED"
    assert "Action déjà EXECUTED" in res["message"]

@pytest.mark.asyncio
async def test_9_reconciliation_on_failed_refused(db_session):
    action_id = f"recon_failed_refused_{uuid.uuid4()}"
    create_mock_action(db_session, action_id, status="FAILED")
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    assert res["status"] == "FAILED"
    assert "Action déjà FAILED" in res["message"]

@pytest.mark.asyncio
async def test_10_concurrent_reconciliation(db_session):
    action_id = f"recon_concurrent_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)
    
    with patch('sqlalchemy.orm.query.Query.with_for_update') as mock_lock:
        mock_lock.side_effect = OperationalError("Lock not available", params={}, orig=Exception())
        
        res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
        assert res["status"] == "RECONCILIATION_IN_PROGRESS"
        assert "verrouillé" in res["message"] or "En cours" in res["message"]

@pytest.mark.asyncio
async def test_11_reconciliation_in_progress_recent(db_session):
    action_id = f"recon_recent_{uuid.uuid4()}"
    started_at = datetime.now(timezone.utc) - timedelta(minutes=2)
    create_mock_action(db_session, action_id, status="RECONCILIATION_IN_PROGRESS", started_at=started_at)
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    assert res["status"] == "RECONCILIATION_IN_PROGRESS"
    assert res["success"] is False

@pytest.mark.asyncio
@patch('app.services.wallet_integrations.paymechap_api_service.PayMeChapAPIService.fetch_live_transactions')
async def test_12_reconciliation_in_progress_expired(mock_fetch, db_session):
    action_id = f"recon_expired_{uuid.uuid4()}"
    started_at = datetime.now(timezone.utc) - timedelta(minutes=10)
    create_mock_action(db_session, action_id, status="RECONCILIATION_IN_PROGRESS", started_at=started_at)
    
    mock_fetch.return_value = [{"id": action_id, "status": "COMPLETED"}]
    
    res = await sika_orchestrator.reconcile_action(action_id, user_id=1)
    assert res["status"] == "EXECUTED"

