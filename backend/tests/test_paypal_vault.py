"""
SIKA Pay — Compte PayPal enregistré (Vault) : libre choix de l'utilisateur.

- Relier le compte exige l'approbation du payeur sur PayPal ; le délier supprime le jeton chez PayPal.
- Le compte relié n'est utilisé que pour un achat confirmé par l'agent sous une autorisation active, dans ses limites.
- Une confirmation faite par l'utilisateur garde l'approbation PayPal, même avec un compte relié.
- Seule une capture COMPLETED au bon montant vaut paiement ; une erreur réseau donne UNKNOWN_RESULT, puis est
  réconciliée sans double paiement.
"""

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.main import app
from app.database import engine, Base
from app.models.user import UserModel
from app.models.paypal_checkout import PayPalCheckoutModel
from app.models.agent_mandate import AgentMandateModel
from app.models.paypal_vault import PayPalVaultModel
from app.routes import paypal_router
from app.services.auth_service import oauth2_auth_service
from app.services.agent_mandate_service import agent_mandate_service
from app.services.paypal_checkout_service import paypal_checkout_service, CheckoutError
from app.services.paypal_vault_service import paypal_vault_service

from paypal_fakes import FakePayPalAPI, NETWORK_ERROR

client = TestClient(app)


@pytest.fixture(autouse=True)
def fake(monkeypatch):
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).delete()
        db.query(AgentMandateModel).delete()
        db.query(PayPalVaultModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"vault{uid}@sika.test", full_name=f"User {uid}"))
        db.commit()
    api = FakePayPalAPI()
    monkeypatch.setattr(paypal_checkout_service, "api", api)
    monkeypatch.setattr(paypal_vault_service, "api", api)
    monkeypatch.setattr(paypal_router.settings, "PUBLIC_BASE_URL", "http://localhost:8001")
    # La limite anti-spam (5 liaisons par minute) est testée à part : ici, chaque test relie un compte
    monkeypatch.setattr(paypal_router.security_rate_limiter, "check_ai_rate_limit", lambda *a, **k: None)
    yield api


def _auth(uid=1):
    return {"Authorization": "Bearer " + oauth2_auth_service.create_access_token({"user_id": uid, "email": f"vault{uid}@sika.test"})}


def _link(api, uid=1):
    """Relie le compte : lien d'approbation, approbation simulée sur PayPal, puis page de retour."""
    res = client.post("/api/v1/paypal/vault", headers=_auth(uid))
    assert res.status_code == 200 and res.json()["approve_url"].startswith("https://www.sandbox.paypal.com/")
    setup_id = next(iter(k for k in api.setup_tokens if not api.setup_tokens[k]["approved"]))
    api.approve_setup_token(setup_id)
    page = client.get(f"/api/v1/paypal/vault-return?approval_token_id={setup_id}")
    assert "PayPal account linked" in page.text
    return setup_id


def _agent_buy(uid=1, sku="SIKA-COURSE-EXCEL"):
    chk = paypal_checkout_service.prepare_checkout(uid, sku, 1, None)
    return paypal_checkout_service.confirm_by_agent(uid, chk["checkout_id"])


def test_linking_requires_paypal_approval(fake):
    res = client.post("/api/v1/paypal/vault", headers=_auth())
    setup_id = next(iter(fake.setup_tokens))
    # Retour sans approbation réelle sur PayPal : rien n'est enregistré
    page = client.get(f"/api/v1/paypal/vault-return?approval_token_id={setup_id}")
    assert "Account not linked" in page.text
    assert client.get("/api/v1/paypal/vault", headers=_auth()).json() == {"linked": False}
    assert res.status_code == 200


def test_link_status_and_unlink(fake):
    assert client.get("/api/v1/paypal/vault").status_code == 401
    _link(fake)
    status = client.get("/api/v1/paypal/vault", headers=_auth()).json()
    assert status["linked"] is True and status["payer_email"] == "bu***@example.com"
    # Un autre utilisateur ne voit pas ce compte
    assert client.get("/api/v1/paypal/vault", headers=_auth(2)).json() == {"linked": False}
    assert client.delete("/api/v1/paypal/vault", headers=_auth()).json() == {"linked": False}
    assert any(c[0] == "vault_delete" for c in fake.calls) and not fake.payment_tokens


def test_agent_pays_with_saved_account_within_limits(fake):
    _link(fake)
    agent_mandate_service.grant(1, "50", "100", 24)
    res = _agent_buy()
    assert res["status"] == "COMPLETED" and res["payment_method"] == "SAVED_PAYPAL"
    assert res["paypal"]["capture_status"] == "COMPLETED" and res["paypal"]["captured_amount"] == res["total_amount"]
    assert res["confirmed_by"] == "AGENT" and res["paypal"]["approve_url"] is None
    assert [c[0] for c in fake.calls].count("create_vault") == 1


def test_saved_account_never_bypasses_the_limits(fake):
    _link(fake)
    agent_mandate_service.grant(1, "50", "100", 24)
    with pytest.raises(CheckoutError) as e:
        _agent_buy(sku="SIKA-COURSE-MARKETING")  # 64 USD > 50 USD par achat
    assert e.value.code == "ABOVE_AUTHORIZED_AMOUNT"
    assert not any(c[0] == "create_vault" for c in fake.calls)


def test_saved_account_is_not_used_without_authorization(fake):
    _link(fake)
    with pytest.raises(CheckoutError):
        _agent_buy()
    assert not any(c[0].startswith("create") for c in fake.calls)


def test_user_confirmation_keeps_paypal_approval_even_with_saved_account(fake):
    _link(fake)
    chk = paypal_checkout_service.prepare_checkout(1, "SIKA-COURSE-EXCEL", 1, None)
    res = paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    assert res["status"] == "AWAITING_PAYPAL_APPROVAL" and res["payment_method"] == "PAYPAL_APPROVAL"
    assert res["paypal"]["approve_url"] and not any(c[0] == "create_vault" for c in fake.calls)


def test_without_saved_account_agent_confirmation_still_needs_paypal_approval(fake):
    agent_mandate_service.grant(1, "50", "100", 24)
    res = _agent_buy()
    assert res["status"] == "AWAITING_PAYPAL_APPROVAL" and res["payment_method"] == "PAYPAL_APPROVAL"


def test_network_error_is_unknown_then_reconciled_without_double_charge(fake):
    _link(fake)
    agent_mandate_service.grant(1, "50", "100", 24)
    fake.create_failure, fake.vault_failure_after_charge = NETWORK_ERROR, True
    res = _agent_buy()
    assert res["status"] == "UNKNOWN_RESULT"  # jamais « rien n'a été payé »
    synced = paypal_checkout_service.sync_with_paypal(1, res["checkout_id"])
    assert synced["status"] == "COMPLETED"
    # Même PayPal-Request-Id : une seule commande existe chez PayPal
    assert len(fake.orders) == 1


def test_amount_mismatch_on_saved_account_is_not_shown_as_paid(fake):
    _link(fake)
    agent_mandate_service.grant(1, "50", "100", 24)
    fake.captured_value_override = "1.00"
    res = _agent_buy()
    assert res["status"] == "UNKNOWN_RESULT" and res["last_error"]["code"] == "AMOUNT_MISMATCH"


def test_unlinked_account_is_no_longer_used(fake):
    _link(fake)
    client.delete("/api/v1/paypal/vault", headers=_auth())
    agent_mandate_service.grant(1, "50", "100", 24)
    res = _agent_buy()
    assert res["payment_method"] == "PAYPAL_APPROVAL" and res["status"] == "AWAITING_PAYPAL_APPROVAL"


def test_linking_is_rate_limited(fake, monkeypatch):
    from app.services.security_rate_limiter import SecurityRateLimiter
    monkeypatch.setattr(paypal_router.security_rate_limiter, "check_ai_rate_limit",
                        SecurityRateLimiter.check_ai_rate_limit.__get__(paypal_router.security_rate_limiter))
    codes = [client.post("/api/v1/paypal/vault", headers=_auth(2)).status_code for _ in range(6)]
    assert codes[:5] == [200] * 5 and codes[5] == 429
