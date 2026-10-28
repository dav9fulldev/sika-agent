"""
Résumé des dépenses : uniquement les paiements capturés de l'utilisateur, recoupés avec PayPal via le toolkit.

Le relevé PayPal contient les transactions de tous les clients du marchand : seules les captures de l'utilisateur
peuvent apparaître dans le résultat. Aucun appel réseau : le toolkit est remplacé par un double.
"""

from datetime import datetime, timezone

import pytest
from sqlalchemy.orm import Session

from app.database import engine, Base
from app.models.user import UserModel
from app.models.paypal_checkout import PayPalCheckoutModel
from app.agent.tool_registry import tool_registry
from app.services.spending_service import SpendingService, spending_service
from app.services.wallet_integrations.paypal_agent_toolkit import ToolkitUnavailable
from app.services.sika_ai import SikaAIService


class FakeToolkit:
    def __init__(self, ids=None, fail=False):
        self.ids, self.fail, self.calls = ids or [], fail, 0

    def list_transaction_ids(self, start, end):
        self.calls += 1
        if self.fail:
            raise ToolkitUnavailable("PayPal transaction reports could not be read.")
        return list(self.ids)


def _checkout(uid, n, status="COMPLETED", sku="SIKA-COURSE-EXCEL", amount="49.00", by="USER"):
    return PayPalCheckoutModel(
        checkout_id=f"chk_{uid:02d}{n:022d}", user_id=uid, status=status, sku=sku, item_name=f"Item {n}",
        quantity=1, unit_amount=amount, total_amount=amount, currency="USD", merchant_name="SIKA Demo Store",
        details_hash="x" * 64, create_request_id=f"c{uid}{n}", capture_request_id=f"p{uid}{n}", confirmed_by=by,
        capture_id=f"CAP{uid}{n}" if status == "COMPLETED" else None, capture_status="COMPLETED" if status == "COMPLETED" else None,
        captured_amount=amount if status == "COMPLETED" else None, captured_currency="USD" if status == "COMPLETED" else None,
        expires_at=datetime.now(timezone.utc).replace(tzinfo=None), created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        updated_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )


@pytest.fixture(autouse=True)
def data():
    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).delete()
        for uid in (1, 2):
            if not db.query(UserModel).filter(UserModel.id == uid).first():
                db.add(UserModel(id=uid, email=f"spend{uid}@sika.test", full_name=f"User {uid}"))
        db.add_all([
            _checkout(1, 1, by="USER"),
            _checkout(1, 2, sku="SIKA-EBOOK-SMALLBIZ", amount="12.50", by="AGENT"),
            _checkout(1, 3, status="CANCELLED"),          # jamais compté : rien n'a été payé
            _checkout(2, 1, amount="64.00"),              # autre utilisateur
        ])
        db.commit()


def test_summary_counts_only_the_users_captured_payments():
    s = SpendingService(toolkit=FakeToolkit(ids=["CAP11", "CAP12", "CAP21"])).summary(1, 30)
    assert s["purchases_count"] == 2 and s["total_spent"] == {"USD": "61.50"}
    assert s["by_category"] == {"education": "49.00", "books": "12.50"}
    assert s["confirmed_by_sika"] == 1
    assert s["paypal_ledger"] == {"status": "CHECKED", "tool": "PayPal Agent Toolkit (list_transactions)",
                                  "found_in_paypal_reports": 2, "total_payments": 2, "note": None}
    # Le relevé du marchand contient la capture d'un autre client : elle n'apparaît nulle part
    assert "CAP21" not in str(s) and "64.00" not in str(s)


def test_ledger_delay_is_reported_honestly():
    s = SpendingService(toolkit=FakeToolkit(ids=["CAP11"])).summary(1, 30)
    assert s["paypal_ledger"]["found_in_paypal_reports"] == 1 and "few hours" in s["paypal_ledger"]["note"]


def test_toolkit_failure_does_not_break_the_summary():
    s = SpendingService(toolkit=FakeToolkit(fail=True)).summary(1, 30)
    assert s["total_spent"] == {"USD": "61.50"} and s["paypal_ledger"]["status"] == "UNAVAILABLE"


def test_no_payment_means_no_paypal_call():
    toolkit = FakeToolkit()
    with Session(engine) as db:
        db.query(PayPalCheckoutModel).delete()
        db.commit()
    s = SpendingService(toolkit=toolkit).summary(1, 30)
    assert s["purchases_count"] == 0 and s["paypal_ledger"] == {"status": "NOTHING_TO_CHECK"} and toolkit.calls == 0


def test_agent_tool_uses_the_authenticated_user(monkeypatch):
    monkeypatch.setattr(spending_service, "toolkit", FakeToolkit(ids=["CAP21"]))
    res, status = SikaAIService.run_agent_tool("get_spending_summary", {"days": 30, "user_id": "1"},
                                               set(tool_registry.agent_tool_names()), "2", "how much did I spend?")
    assert status == "completed" and res["data"]["total_spent"] == {"USD": "64.00"}
    # Le modèle ne voit jamais le paramètre user_id
    declared = {f.name: f for t in tool_registry.get_gemini_tools() for f in getattr(t, "function_declarations", []) or []}
    assert "user_id" not in str(declared["get_spending_summary"].parameters)
