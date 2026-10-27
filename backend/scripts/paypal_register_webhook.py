"""
Enregistre (une fois) le webhook PayPal sandbox de SIKA Pay.

Usage :
    python scripts/paypal_register_webhook.py https://<cloud-run-url>

Crée le webhook <url>/api/v1/paypal/webhook pour les événements traités par SIKA Pay, ou indique
qu'il existe déjà. Le backend retrouve ensuite son ID tout seul (ou via PAYPAL_WEBHOOK_ID).
Aucun secret n'est affiché.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from app.services.paypal_checkout_service import PayPalCheckoutService  # noqa: E402
from app.services.wallet_integrations.paypal_api_service import paypal_api_service, PayPalAPIError  # noqa: E402


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].startswith("https://"):
        print("Usage: python scripts/paypal_register_webhook.py https://<public-backend-url>")
        return 2
    url = sys.argv[1].rstrip("/") + "/api/v1/paypal/webhook"
    existing = next((w for w in paypal_api_service.list_webhooks() if w.get("url") == url), None)
    if existing:
        print(f"Webhook already registered: {existing['id']} -> {url}")
        return 0
    try:
        created = paypal_api_service.create_webhook(url, list(PayPalCheckoutService.WEBHOOK_EVENTS))
    except PayPalAPIError as e:
        print(f"PayPal refused the webhook: {e.name}/{e.issue} {e.message} (debug_id={e.debug_id})")
        return 1
    events = ", ".join(t["name"] for t in created.get("event_types", []))
    print(f"Webhook created: {created['id']} -> {url}\nEvents: {events}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
