import pytest
import json
import requests
import uuid
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
from unittest.mock import patch, MagicMock

from app.agent.orchestrator import sika_orchestrator
from app.models.sika_action import SikaActionModel
from app.database import engine
from app.services.wallet_integrations.paymechap_api_service import paymechap_api_service

@pytest.fixture
def db_session():
    paymechap_api_service._cached_token = None
    paymechap_api_service._token_expires_at = None
    with Session(engine) as session:
        yield session

def create_mock_action(db_session, action_id, user_id=1, status="WAITING_CONFIRMATION", payload=None):
    action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    if not action:
        if not payload:
            payload = {"amount": 1000, "recipient_phone": "0102030405"}
        action = SikaActionModel(
            action_id=action_id,
            user_id=user_id,
            status=status,
            action_type="transfer",
            payload_json=json.dumps(payload),
            created_at=datetime.now(timezone.utc),
            updated_at=datetime.now(timezone.utc),
            expires_at=datetime.now(timezone.utc) + timedelta(minutes=10)
        )
        db_session.add(action)
        db_session.commit()
    else:
        action.status = status
        action.expires_at = datetime.now(timezone.utc) + timedelta(minutes=10)
        db_session.commit()
    return action

@pytest.mark.asyncio
async def test_1_success_normal(db_session):
    action_id = f"transfer_resilience_success_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"access_token": "mock_token"}
        
        payout_resp = MagicMock()
        payout_resp.status_code = 200
        payout_resp.json.return_value = {"success": True, "data": {"status": "COMPLETED"}}
        
        mock_post.side_effect = [auth_resp, payout_resp]

        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

    assert result["success"] is True
    assert result["status"] == "EXECUTED"

    action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    assert action.status == "EXECUTED"


@pytest.mark.asyncio
async def test_2_echec_metier_deterministe(db_session):
    action_id = f"transfer_resilience_fail_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"access_token": "mock_token"}
        
        fail_resp = MagicMock()
        fail_resp.status_code = 400
        fail_resp.text = "Solde insuffisant"
        
        mock_post.side_effect = [auth_resp, fail_resp]

        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

    assert result["success"] is False
    assert result["status"] == "FAILED"

    action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    assert action.status == "FAILED"


@pytest.mark.asyncio
async def test_3_read_timeout(db_session):
    action_id = f"transfer_resilience_timeout_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"access_token": "mock_token"}

        mock_post.side_effect = [auth_resp, requests.exceptions.ReadTimeout("Timeout from PayMeChap")]

        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

    assert result["success"] is False
    assert result["status"] == "UNKNOWN_RESULT"

    action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    assert action.status == "UNKNOWN_RESULT"


@pytest.mark.asyncio
async def test_4_connection_error(db_session):
    action_id = f"transfer_resilience_conn_err_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"access_token": "mock_token"}

        mock_post.side_effect = [auth_resp, requests.exceptions.ConnectionError("Connection closed")]

        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

    assert result["success"] is False
    assert result["status"] == "UNKNOWN_RESULT"

    action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    assert action.status == "UNKNOWN_RESULT"


@pytest.mark.asyncio
async def test_5_http_500(db_session):
    action_id = f"transfer_resilience_500_{uuid.uuid4()}"
    create_mock_action(db_session, action_id)

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"access_token": "mock_token"}

        fail_resp = MagicMock()
        fail_resp.status_code = 502
        fail_resp.raise_for_status.side_effect = requests.exceptions.HTTPError("502 Bad Gateway")
        
        mock_post.side_effect = [auth_resp, fail_resp]

        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

    assert result["success"] is False
    assert result["status"] == "UNKNOWN_RESULT"

    action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
    assert action.status == "UNKNOWN_RESULT"


@pytest.mark.asyncio
async def test_7_idempotence_depot(db_session):
    action_id = f"deposit_resilience_deposit_{uuid.uuid4()}"
    create_mock_action(db_session, action_id, payload={"amount": 500, "coffre_id": 123})

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        auth_resp = MagicMock()
        auth_resp.status_code = 200
        auth_resp.json.return_value = {"access_token": "mock_token"}

        deposit_resp = MagicMock()
        deposit_resp.status_code = 200
        deposit_resp.json.return_value = {"success": True}
        
        mock_post.side_effect = [auth_resp, deposit_resp]

        action = db_session.query(SikaActionModel).filter_by(action_id=action_id).first()
        action.action_type = "deposit"
        db_session.commit()

        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

        assert mock_post.called
        args, kwargs = mock_post.call_args
        assert "X-Idempotency-Key" in kwargs["headers"]
        assert kwargs["headers"]["X-Idempotency-Key"] == action_id


@pytest.mark.asyncio
async def test_8_unknown_result_non_rejouable(db_session):
    action_id = f"transfer_resilience_no_replay_{uuid.uuid4()}"
    create_mock_action(db_session, action_id, status="UNKNOWN_RESULT")

    with patch('app.services.wallet_integrations.paymechap_api_service.requests.post') as mock_post:
        result = await sika_orchestrator.confirm_action(action_id=action_id, user_id=1)

        # Il ne doit pas y avoir d'appel POST
        assert not mock_post.called

    assert result["success"] is False
    assert result["status"] == "UNKNOWN_RESULT"
    assert "incertain" in result["message"] or "aucune nouvelle tentative" in result["message"].lower()

