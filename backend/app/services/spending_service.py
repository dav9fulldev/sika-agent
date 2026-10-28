"""
Résumé des dépenses de l'utilisateur dans SIKA Pay.

Les montants viennent uniquement des paiements de l'utilisateur dont la capture a été vérifiée auprès de PayPal
(statut COMPLETED, montant contrôlé). Le PayPal Agent Toolkit sert à recouper ces paiements avec le relevé de
transactions PayPal : on ne garde que les identifiants de capture de l'utilisateur, jamais ceux des autres clients.
"""

import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, Dict

from sqlalchemy.orm import Session

from ..database import engine
from ..models.paypal_checkout import PayPalCheckoutModel
from ..models.paypal_subscription import PayPalSubscriptionModel
from . import demo_catalog
from .wallet_integrations.paypal_agent_toolkit import paypal_agent_toolkit, ToolkitUnavailable

logger = logging.getLogger("SikaSpending")

MAX_DAYS = 366


def _utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


class SpendingService:
    def __init__(self, toolkit=None):
        self.toolkit = toolkit or paypal_agent_toolkit

    def summary(self, user_id: int, days: int = 30) -> Dict[str, Any]:
        days = max(1, min(int(days or 30), MAX_DAYS))
        end = datetime.now(timezone.utc)
        start = end - timedelta(days=days)

        with Session(engine) as db:
            rows = db.query(PayPalCheckoutModel).filter(
                PayPalCheckoutModel.user_id == user_id,
                PayPalCheckoutModel.status == "COMPLETED",
                PayPalCheckoutModel.created_at >= start.replace(tzinfo=None),
            ).order_by(PayPalCheckoutModel.created_at.desc()).all()
            subs = db.query(PayPalSubscriptionModel).filter(
                PayPalSubscriptionModel.user_id == user_id,
                PayPalSubscriptionModel.status == "ACTIVE",
            ).all()

            by_currency: Dict[str, Decimal] = defaultdict(Decimal)
            by_category: Dict[str, Decimal] = defaultdict(Decimal)
            confirmed_by_sika = 0
            purchases = []
            captures = []
            for r in rows:
                amount = Decimal(r.captured_amount or r.total_amount)
                currency = r.captured_currency or r.currency
                by_currency[currency] += amount
                product = demo_catalog.get_product(r.sku) or {}
                by_category[product.get("category") or "other"] += amount
                if r.confirmed_by == "AGENT":
                    confirmed_by_sika += 1
                if r.capture_id:
                    captures.append(r.capture_id)
                purchases.append({"item": r.item_name, "amount": f"{amount:.2f}", "currency": currency,
                                  "date": _utc(r.created_at).date().isoformat(),
                                  "confirmed_by": "SIKA" if r.confirmed_by == "AGENT" else "you"})
            monthly_subscriptions = sum((Decimal(s.price) for s in subs), Decimal("0"))
            active_subscriptions = [{"name": s.name, "price": s.price, "currency": s.currency} for s in subs]

        return {
            "period_days": days,
            "from": start.date().isoformat(),
            "to": end.date().isoformat(),
            "purchases_count": len(purchases),
            "total_spent": {c: f"{v:.2f}" for c, v in by_currency.items()},
            "by_category": {c: f"{v:.2f}" for c, v in sorted(by_category.items(), key=lambda x: -x[1])},
            "confirmed_by_sika": confirmed_by_sika,
            "recent_purchases": purchases[:5],
            "active_subscriptions": active_subscriptions,
            "monthly_subscriptions_total": f"{monthly_subscriptions:.2f}",
            "paypal_ledger": self._ledger_check(captures, start, end),
            "source": "Your PayPal payments captured through SIKA Pay (verified with PayPal at capture time).",
        }

    def _ledger_check(self, captures, start: datetime, end: datetime) -> Dict[str, Any]:
        """Recoupe les captures de l'utilisateur avec le relevé de transactions PayPal (via le toolkit)."""
        if not captures:
            return {"status": "NOTHING_TO_CHECK"}
        try:
            ledger = set(self.toolkit.list_transaction_ids(start, end + timedelta(minutes=5)))
        except ToolkitUnavailable as e:
            return {"status": "UNAVAILABLE", "note": str(e)}
        found = sum(1 for c in captures if c in ledger)
        return {
            "status": "CHECKED",
            "tool": "PayPal Agent Toolkit (list_transactions)",
            "found_in_paypal_reports": found,
            "total_payments": len(captures),
            "note": None if found == len(captures) else
            "PayPal transaction reports can take a few hours to include the latest payments.",
        }


spending_service = SpendingService()
