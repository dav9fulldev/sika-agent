"""
Crée (une fois) les produits et plans d'abonnement du SIKA Demo Store dans le sandbox PayPal,
via le serveur MCP officiel de PayPal (outils create_product et create_subscription_plan).

Usage :
    python scripts/paypal_seed_subscription_plans.py

Idempotent : un plan dont la description commence par « sika-plan:<clé> » n'est pas recréé.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from app.services.demo_subscriptions import SUBSCRIPTION_CATALOG, PLAN_TAG, CURRENCY, INTERVAL  # noqa: E402
from app.services.wallet_integrations.paypal_mcp_client import paypal_mcp_client as mcp  # noqa: E402


def existing_keys() -> set:
    keys, page = set(), 1
    while True:
        res = mcp.call_tool("list_subscription_plans", {"page_size": 20, "page": page, "total_required": True})
        for plan in res.get("plans") or []:
            desc = plan.get("description") or ""
            if desc.startswith(PLAN_TAG):
                keys.add(desc[len(PLAN_TAG):].split(" ", 1)[0])
        if page >= int(res.get("total_pages") or 1):
            return keys
        page += 1


def main() -> int:
    done = existing_keys()
    for p in SUBSCRIPTION_CATALOG:
        if p["key"] in done:
            print(f"= {p['name']}: already exists")
            continue
        product = mcp.call_tool("create_product", {"name": p["name"], "type": "SERVICE",
                                                   "description": p["description"], "category": "SOFTWARE"})
        plan = mcp.call_tool("create_subscription_plan", {
            "product_id": product["id"],
            "name": f"{p['name']} (monthly)",
            "description": f"{PLAN_TAG}{p['key']} {p['description']}"[:127],
            "billing_cycles": [{
                "frequency": {"interval_unit": INTERVAL, "interval_count": 1},
                "tenure_type": "REGULAR", "sequence": 1, "total_cycles": 0,
                "pricing_scheme": {"fixed_price": {"currency_code": CURRENCY, "value": p["price"]}},
            }],
            "payment_preferences": {"auto_bill_outstanding": True, "payment_failure_threshold": 1},
        })
        print(f"+ {p['name']}: product {product['id']}, plan {plan.get('id')} ({plan.get('status')})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
