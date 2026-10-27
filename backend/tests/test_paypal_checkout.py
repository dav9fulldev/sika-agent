"""
SIKA Pay — Tests de la machine à états PayPal (Orders v2, sandbox).

Le client PayPal est remplacé par FakePayPalAPI (tests/paypal_fakes.py) : aucun appel réseau.
Les tests prouvent que :
- le montant vient du catalogue serveur, jamais du client ou du modèle ;
- aucune commande n'est créée sans confirmation liée aux détails affichés ;
- aucune capture n'a lieu sans approbation vérifiée côté serveur auprès de PayPal ;
- les répétitions ne provoquent jamais de double capture ;
- les erreurs réseau produisent un statut UNKNOWN_RESULT et non un faux succès.
"""

from datetime import datetime, timezone, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.config import settings
from app.database import engine, Base
from app.models.user import UserModel
from app.models.paypal_checkout import PayPalCheckoutModel
from app.models.sika_action_event import SikaActionEventModel
from app.services.auth_service import oauth2_auth_service
from app.services.paypal_checkout_service import paypal_checkout_service, CheckoutError
from app.services.wallet_integrations.paypal_api_service import PayPalAPIError

from paypal_fakes import FakePayPalAPI, NETWORK_ERROR

client = TestClient(app)


@pytest.fixture(autouse=True)
def setup_db_and_fake(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"paypal{uid}@sika.test", full_name=f"User {uid}"))
        db.commit()
    fake = FakePayPalAPI()
    monkeypatch.setattr(paypal_checkout_service, "api", fake)
    yield fake


def _auth(uid=1):
    token = oauth2_auth_service.create_access_token({"user_id": uid, "email": f"paypal{uid}@sika.test"})
    return {"Authorization": f"Bearer {token}"}


def _prepare(uid=1, sku="SIKA-COURSE-EXCEL", qty=1, budget=None):
    return paypal_checkout_service.prepare_checkout(uid, sku, qty, budget)


def _status(checkout_id):
    with Session(engine) as db:
        return db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.checkout_id == checkout_id).first().status


# ---------------------------------------------------------------------------
# Préparation
# ---------------------------------------------------------------------------

def test_prepare_uses_server_side_catalog_price_and_calls_no_paypal(setup_db_and_fake):
    chk = _prepare(qty=2, budget="100")
    assert chk["status"] == "AWAITING_USER_CONFIRMATION"
    assert chk["unit_amount"] == "49.00" and chk["total_amount"] == "98.00" and chk["currency"] == "USD"
    assert chk["budget"]["within_budget"] is True and chk["budget"]["remaining_after_purchase"] == "2.00"
    assert chk["environment"] == "sandbox" and chk["merchant"]["is_demo"] is True
    assert len(chk["details_hash"]) == 64
    assert chk["paypal"]["order_id"] is None
    assert setup_db_and_fake.calls == []


@pytest.mark.parametrize("qty", [0, 11, 1.5, True, "abc", -1])
def test_prepare_rejects_invalid_quantity(qty):
    with pytest.raises(CheckoutError) as e:
        _prepare(qty=qty)
    assert e.value.code == "INVALID_QUANTITY"


def test_prepare_rejects_unknown_sku():
    with pytest.raises(CheckoutError) as e:
        _prepare(sku="FAKE-SKU-999")
    assert e.value.code == "UNKNOWN_PRODUCT"


def test_prepare_over_budget_returns_alternatives():
    with pytest.raises(CheckoutError) as e:
        _prepare(sku="SIKA-COURSE-MARKETING", budget="50")
    assert e.value.code == "OVER_BUDGET"
    alts = e.value.data["alternatives_within_budget"]
    assert alts and all(float(p["unit_price"]) <= 50 for p in alts)


def test_prepare_refuses_currency_conversion():
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.prepare_checkout(1, "SIKA-COURSE-EXCEL", 1, "30000", "XOF")
    assert e.value.code == "BUDGET_CURRENCY_MISMATCH"


def test_prepare_enforces_max_amount(monkeypatch):
    monkeypatch.setattr(settings, "PAYPAL_MAX_ORDER_AMOUNT", 100.0)
    with pytest.raises(CheckoutError) as e:
        _prepare(sku="SIKA-PHOTO-PRO", qty=2)  # 109.98
    assert e.value.code == "AMOUNT_ABOVE_LIMIT"


def test_new_preparation_invalidates_previous_confirmation(setup_db_and_fake):
    first = _prepare()
    second = _prepare(sku="SIKA-EBOOK-SMALLBIZ")
    assert _status(first["checkout_id"]) == "CANCELLED"
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, first["checkout_id"], first["details_hash"])
    assert e.value.code == "INVALID_STATE"
    assert _status(second["checkout_id"]) == "AWAITING_USER_CONFIRMATION"
    assert setup_db_and_fake.calls == []


# ---------------------------------------------------------------------------
# Confirmation -> création de commande
# ---------------------------------------------------------------------------

def test_confirm_requires_matching_details_hash(setup_db_and_fake):
    chk = _prepare()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], "0" * 64)
    assert e.value.code == "DETAILS_CHANGED"
    assert setup_db_and_fake.calls == []


def test_confirm_detects_tampered_amount_in_database(setup_db_and_fake):
    chk = _prepare()
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.checkout_id == chk["checkout_id"]).update({"total_amount": "1.00"})
        db.commit()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "DETAILS_CHANGED"
    assert setup_db_and_fake.calls == []


def test_confirm_rejects_other_user(setup_db_and_fake):
    chk = _prepare(uid=1)
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(2, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "FORBIDDEN" and e.value.http_status == 403
    assert setup_db_and_fake.calls == []


def test_confirm_expired_checkout(setup_db_and_fake):
    chk = _prepare()
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.checkout_id == chk["checkout_id"]).update(
            {"expires_at": datetime.now(timezone.utc) - timedelta(seconds=1)})
        db.commit()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "CHECKOUT_EXPIRED"
    assert _status(chk["checkout_id"]) == "EXPIRED"
    assert setup_db_and_fake.calls == []


def test_confirm_creates_order_once_and_is_idempotent(setup_db_and_fake):
    fake = setup_db_and_fake
    chk = _prepare()
    res = paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert res["status"] == "AWAITING_PAYPAL_APPROVAL"
    assert res["paypal"]["order_status"] == "PAYER_ACTION_REQUIRED"
    assert res["paypal"]["approve_url"].startswith("https://www.sandbox.paypal.com/")
    again = paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert again["paypal"]["order_id"] == res["paypal"]["order_id"]
    assert [c[0] for c in fake.calls] == ["create"]


def test_confirm_without_credentials(setup_db_and_fake):
    setup_db_and_fake.configured = False
    chk = _prepare()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "PAYPAL_NOT_CONFIGURED"
    assert _status(chk["checkout_id"]) == "AWAITING_USER_CONFIRMATION"


def test_create_network_error_is_retryable_with_same_request_id(setup_db_and_fake):
    fake = setup_db_and_fake
    fake.create_failure = NETWORK_ERROR
    chk = _prepare()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "PAYPAL_UNREACHABLE"
    assert _status(chk["checkout_id"]) == "AWAITING_USER_CONFIRMATION"
    res = paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert res["status"] == "AWAITING_PAYPAL_APPROVAL"
    request_ids = [c[1] for c in fake.calls if c[0] == "create"]
    assert len(request_ids) == 2 and request_ids[0] == request_ids[1]


def test_create_rejected_by_paypal_marks_failed(setup_db_and_fake):
    setup_db_and_fake.create_failure = PayPalAPIError(422, name="UNPROCESSABLE_ENTITY", issue="CURRENCY_NOT_SUPPORTED", debug_id="dbg1")
    chk = _prepare()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "CURRENCY_NOT_SUPPORTED"
    assert "does not support this currency" in e.value.message and "No payment was made" in e.value.message
    assert _status(chk["checkout_id"]) == "FAILED"


def test_create_amount_mismatch_from_paypal_is_refused(setup_db_and_fake):
    setup_db_and_fake.order_amount_override = "1.00"
    chk = _prepare()
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert e.value.code == "AMOUNT_MISMATCH"
    assert _status(chk["checkout_id"]) == "FAILED"


# ---------------------------------------------------------------------------
# Approbation -> capture
# ---------------------------------------------------------------------------

def _created(fake):
    chk = _prepare()
    res = paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    return res["checkout_id"], res["paypal"]["order_id"]


def test_capture_refused_until_paypal_reports_approved(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, _ = _created(fake)
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.capture(1, cid)
    assert e.value.code == "ORDER_NOT_APPROVED"
    assert fake.capture_count() == 0
    assert _status(cid) == "AWAITING_PAYPAL_APPROVAL"


def test_full_flow_completes_and_never_double_captures(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    fake.approve(order_id)
    # Après l'approbation PayPal, la vérification capture automatiquement (pas de 4e confirmation)
    done = paypal_checkout_service.sync_with_paypal(1, cid)
    assert done["status"] == "COMPLETED"
    assert done["paypal"]["capture_status"] == "COMPLETED"
    assert done["paypal"]["captured_amount"] == "49.00" and done["paypal"]["captured_currency"] == "USD"

    again = paypal_checkout_service.capture(1, cid)
    assert again["already_completed"] is True
    assert fake.capture_count() == 1

    events = paypal_checkout_service.get_checkout(1, cid)["events"]
    types_ = [e["event_type"] for e in events]
    assert types_[0] == "CHECKOUT_PREPARED" and "USER_CONFIRMED" in types_ and "PAYPAL_ORDER_CREATED" in types_
    assert "PAYPAL_APPROVED_SYNC" in types_ and "CAPTURE_STARTED" in types_
    assert types_[-1] == "PAYPAL_CAPTURE_COMPLETED_CAPTURE_SYNC"


def test_capture_network_error_gives_unknown_result_then_safe_retry(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    fake.approve(order_id)
    fake.capture_failure = NETWORK_ERROR
    res = paypal_checkout_service.capture(1, cid)
    assert res["status"] == "UNKNOWN_RESULT"
    assert res["status"] != "COMPLETED"

    final = paypal_checkout_service.capture(1, cid)
    assert final["status"] == "COMPLETED"
    capture_ids = [c[1] for c in fake.calls if c[0] == "capture"]
    assert len(capture_ids) == 2 and capture_ids[0] == capture_ids[1]  # même PayPal-Request-Id


def test_unknown_result_resolved_by_sync_when_paypal_already_captured(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    fake.approve(order_id)
    paypal_checkout_service.capture(1, cid)
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).filter(PayPalCheckoutModel.checkout_id == cid).update({"status": "UNKNOWN_RESULT"})
        db.commit()
    res = paypal_checkout_service.capture(1, cid)
    assert res["status"] == "COMPLETED"
    assert fake.capture_count() == 1


def test_instrument_declined_sends_payer_back_to_paypal(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    fake.approve(order_id)
    fake.capture_failure = PayPalAPIError(422, name="UNPROCESSABLE_ENTITY", issue="INSTRUMENT_DECLINED")
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.capture(1, cid)
    assert e.value.code == "INSTRUMENT_DECLINED"
    assert _status(cid) == "AWAITING_PAYPAL_APPROVAL"


def test_declined_capture_is_reported_as_declined(setup_db_and_fake):
    fake = setup_db_and_fake
    fake.capture_status = "DECLINED"
    cid, order_id = _created(fake)
    fake.approve(order_id)
    res = paypal_checkout_service.capture(1, cid)
    assert res["status"] == "DECLINED"


def test_pending_capture_is_not_reported_as_success(setup_db_and_fake):
    fake = setup_db_and_fake
    fake.capture_status = "PENDING"
    cid, order_id = _created(fake)
    fake.approve(order_id)
    res = paypal_checkout_service.capture(1, cid)
    assert res["status"] == "PENDING" and res["next_action"] == "VERIFY"


def test_captured_amount_mismatch_requires_review(setup_db_and_fake):
    fake = setup_db_and_fake
    fake.captured_value_override = "48.00"
    cid, order_id = _created(fake)
    fake.approve(order_id)
    res = paypal_checkout_service.capture(1, cid)
    assert res["status"] == "UNKNOWN_RESULT"
    assert res["last_error"]["code"] == "AMOUNT_MISMATCH"


def test_cancel_then_capture_is_refused(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    res = paypal_checkout_service.cancel(1, cid)
    assert res["status"] == "CANCELLED"
    fake.approve(order_id)
    with pytest.raises(CheckoutError) as e:
        paypal_checkout_service.capture(1, cid)
    assert e.value.code == "INVALID_STATE"
    assert fake.capture_count() == 0


def test_payer_cancel_and_return_handlers(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    fake.approve(order_id)
    assert paypal_checkout_service.handle_payer_return(order_id) == "COMPLETED"
    assert fake.capture_count() == 1
    cid2, order2 = _created(fake)
    assert paypal_checkout_service.handle_payer_cancel(order2) == "CANCELLED"
    assert paypal_checkout_service.handle_payer_return("UNKNOWNORDER123") is None


def test_expired_paypal_order_is_marked_expired(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    del fake.orders[order_id]
    res = paypal_checkout_service.sync_with_paypal(1, cid)
    assert res["status"] == "EXPIRED"


# ---------------------------------------------------------------------------
# Endpoints HTTP
# ---------------------------------------------------------------------------

def test_endpoints_require_authentication():
    assert client.post("/api/v1/paypal/checkouts", json={"sku": "SIKA-COURSE-EXCEL"}).status_code == 401
    assert client.get("/api/v1/paypal/checkouts").status_code == 401
    assert client.post("/api/v1/paypal/checkouts/chk_" + "a" * 24 + "/capture").status_code == 401


def test_status_endpoint_exposes_no_secret():
    res = client.get("/api/v1/paypal/status").json()
    assert res["environment"] == "sandbox"
    assert "secret" not in str(res).lower() and settings.PAYPAL_CLIENT_SECRET not in str(res)


def test_http_happy_path_and_cross_user_isolation(setup_db_and_fake):
    fake = setup_db_and_fake
    h1, h2 = _auth(1), _auth(2)
    prep = client.post("/api/v1/paypal/checkouts", json={"sku": "SIKA-CLOUD-200GB", "quantity": 1, "budget_limit": "40"}, headers=h1)
    assert prep.status_code == 200, prep.text
    chk = prep.json()
    cid = chk["checkout_id"]

    assert client.get(f"/api/v1/paypal/checkouts/{cid}", headers=h2).status_code == 403
    assert client.post(f"/api/v1/paypal/checkouts/{cid}/confirm", json={"details_hash": chk["details_hash"]}, headers=h2).status_code == 403

    conf = client.post(f"/api/v1/paypal/checkouts/{cid}/confirm", json={"details_hash": chk["details_hash"]}, headers=h1)
    assert conf.status_code == 200, conf.text
    order_id = conf.json()["paypal"]["order_id"]

    early = client.post(f"/api/v1/paypal/checkouts/{cid}/capture", headers=h1)
    assert early.status_code == 409 and early.json()["detail"]["error_code"] == "ORDER_NOT_APPROVED"

    fake.approve(order_id)
    page = client.get(f"/api/v1/paypal/return?token={order_id}")
    assert page.status_code == 200 and "Payment completed" in page.text and "SANDBOX" in page.text

    # Capture déjà faite au retour : la capture manuelle ne recapture pas
    cap = client.post(f"/api/v1/paypal/checkouts/{cid}/capture", headers=h1)
    assert cap.status_code == 200 and cap.json()["status"] == "COMPLETED" and cap.json()["already_completed"] is True
    assert fake.capture_count() == 1

    history = client.get("/api/v1/paypal/checkouts", headers=h1).json()["checkouts"]
    assert history[0]["checkout_id"] == cid and history[0]["status"] == "COMPLETED"
    assert client.get("/api/v1/paypal/checkouts", headers=h2).json()["checkouts"] == []


def test_http_rejects_client_supplied_amount_fields(setup_db_and_fake):
    res = client.post("/api/v1/paypal/checkouts",
                      json={"sku": "SIKA-COURSE-EXCEL", "quantity": 1, "amount": "0.01", "unit_amount": "0.01"},
                      headers=_auth(1))
    assert res.status_code == 200
    assert res.json()["total_amount"] == "49.00"  # champs inconnus ignorés : le prix vient du serveur


def test_http_invalid_checkout_id_format():
    assert client.get("/api/v1/paypal/checkouts/../../etc", headers=_auth(1)).status_code == 404
    assert client.get("/api/v1/paypal/checkouts/chk_XYZ", headers=_auth(1)).status_code == 404


def test_audit_events_are_written_for_each_transition(setup_db_and_fake):
    fake = setup_db_and_fake
    cid, order_id = _created(fake)
    with Session(engine) as db:
        rows = db.query(SikaActionEventModel).filter(SikaActionEventModel.action_id == cid).all()
        assert {r.new_status for r in rows} >= {"AWAITING_USER_CONFIRMATION", "CREATING_ORDER", "AWAITING_PAYPAL_APPROVAL"}
