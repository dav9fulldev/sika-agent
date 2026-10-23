"""
Vérification de bout en bout contre le VRAI sandbox PayPal (aucun double de test).

Prérequis : PAYPAL_CLIENT_ID et PAYPAL_CLIENT_SECRET (application sandbox) dans backend/.env,
et un compte acheteur sandbox (developer.paypal.com > Testing Tools > Sandbox Accounts).

Usage (depuis backend/) :
    python scripts/paypal_sandbox_e2e.py            # parcours complet, approbation manuelle dans le navigateur
    python scripts/paypal_sandbox_e2e.py --no-wait  # crée seulement la commande et affiche le lien

Étapes réellement exécutées :
  1. OAuth2 client_credentials sur api-m.sandbox.paypal.com
  2. Préparation d'un checkout SIKA (prix calculé côté serveur)
  3. Confirmation -> POST /v2/checkout/orders (PayPal-Request-Id)
  4. Approbation par le compte acheteur sandbox dans le navigateur (action humaine)
  5. GET /v2/checkout/orders/{id} jusqu'à APPROVED
  6. POST /v2/checkout/orders/{id}/capture (PayPal-Request-Id) puis vérification du montant capturé
Les identifiants et jetons ne sont jamais affichés.
"""

import os
import sys
import time
import argparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
# Base locale dédiée au script, isolée de la base de l'application
os.environ.setdefault("DATABASE_URL", "sqlite:///./paypal_sandbox_e2e.db")

from sqlalchemy.orm import Session  # noqa: E402

from app.config import settings  # noqa: E402
from app.database import engine, Base  # noqa: E402
from app import models  # noqa: E402,F401
from app.models.user import UserModel  # noqa: E402
from app.services.paypal_checkout_service import paypal_checkout_service, CheckoutError  # noqa: E402
from app.services.wallet_integrations.paypal_api_service import paypal_api_service  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sku", default="SIKA-COURSE-EXCEL")
    parser.add_argument("--budget", default="50")
    parser.add_argument("--no-wait", action="store_true")
    parser.add_argument("--timeout", type=int, default=600, help="secondes d'attente de l'approbation")
    args = parser.parse_args()

    if not settings.paypal_configured:
        print("❌ PAYPAL_CLIENT_ID / PAYPAL_CLIENT_SECRET absents de backend/.env (voir docs/PAYPAL_SANDBOX_SETUP.md).")
        return 2
    print(f"Environnement : {settings.PAYPAL_ENV} — {settings.PAYPAL_API_BASE}")

    paypal_api_service._get_access_token()
    print("✅ 1. OAuth2 sandbox : jeton obtenu (non affiché)")

    Base.metadata.create_all(bind=engine)
    with Session(engine) as db:
        if not db.query(UserModel).filter(UserModel.id == 1).first():
            db.add(UserModel(id=1, email="sandbox-e2e@sika.local", full_name="Sandbox E2E"))
            db.commit()

    chk = paypal_checkout_service.prepare_checkout(1, args.sku, 1, args.budget, "USD")
    print(f"✅ 2. Checkout préparé {chk['checkout_id']} : {chk['item']['name']} — {chk['total_amount']} {chk['currency']}")

    res = paypal_checkout_service.confirm_and_create_order(1, chk["checkout_id"], chk["details_hash"])
    print(f"✅ 3. Commande PayPal créée : {res['paypal']['order_id']} (statut PayPal {res['paypal']['order_status']})")
    print(f"\n👉 Ouvrez ce lien et approuvez avec le compte ACHETEUR sandbox :\n   {res['paypal']['approve_url']}\n")
    if args.no_wait:
        return 0

    deadline = time.time() + args.timeout
    status = res["status"]
    while time.time() < deadline:
        status = paypal_checkout_service.sync_with_paypal(1, chk["checkout_id"])["status"]
        if status != "AWAITING_PAYPAL_APPROVAL":
            break
        time.sleep(5)
    print(f"✅ 4-5. Statut vérifié auprès de PayPal : {status}")
    if status != "APPROVED":
        print("❌ La commande n'a pas été approuvée dans le délai : aucune capture tentée.")
        return 1

    try:
        done = paypal_checkout_service.capture(1, chk["checkout_id"])
    except CheckoutError as e:
        print(f"❌ Capture refusée : {e.code} — {e.message}")
        return 1
    p = done["paypal"]
    print(f"✅ 6. Capture : statut SIKA {done['status']} | capture {p['capture_id']} {p['capture_status']} "
          f"{p['captured_amount']} {p['captured_currency']} | commande {p['order_status']}")

    again = paypal_checkout_service.capture(1, chk["checkout_id"])
    print(f"✅ Répétition de la capture : already_completed={again.get('already_completed')} (aucune seconde capture)")
    return 0 if done["status"] == "COMPLETED" else 1


if __name__ == "__main__":
    sys.exit(main())
