"""
Abonnements de démonstration du marchand « SIKA Demo Store » (services fictifs, aucune marque tierce).

Chaque plan est créé dans le sandbox PayPal via le serveur MCP de PayPal
(scripts/paypal_seed_subscription_plans.py). Le prix affiché est revérifié auprès de PayPal
(show_subscription_plan_details) avant toute souscription : ni le modèle ni l'app ne fixent le prix.
"""

from typing import Dict, List, Optional

PLAN_TAG = "sika-plan:"  # préfixe de la description PayPal, pour retrouver nos plans

SUBSCRIPTION_CATALOG: List[Dict[str, str]] = [
    {"key": "streambox-basic", "name": "StreamBox Basic", "category": "video streaming",
     "description": "HD video streaming on one screen.", "price": "7.99"},
    {"key": "streambox-premium", "name": "StreamBox Premium", "category": "video streaming",
     "description": "4K video streaming on four screens.", "price": "13.99"},
    {"key": "tunewave-music", "name": "TuneWave Music", "category": "music streaming",
     "description": "Ad-free music streaming and offline listening.", "price": "9.99"},
    {"key": "cloudvault-200", "name": "CloudVault 200 GB", "category": "cloud storage",
     "description": "200 GB of encrypted cloud storage.", "price": "2.99"},
    {"key": "fitpulse-coach", "name": "FitPulse Coach", "category": "fitness",
     "description": "Guided workouts and a weekly training plan.", "price": "14.99"},
]

CURRENCY = "USD"
INTERVAL = "MONTH"


def get_plan(key: str) -> Optional[Dict[str, str]]:
    return next((p for p in SUBSCRIPTION_CATALOG if p["key"] == key), None)


def search_plans(query: str = "", max_price=None) -> List[Dict[str, str]]:
    from decimal import Decimal
    words = [w.rstrip("s") for w in (query or "").lower().split() if len(w) > 2]

    def hits(p):
        haystack = f"{p['name']} {p['category']} {p['description']}".lower()
        return sum(1 for w in words if w in haystack)

    affordable = [p for p in SUBSCRIPTION_CATALOG
                  if max_price is None or Decimal(p["price"]) <= Decimal(str(max_price))]
    if words:
        # Tous les mots d'abord (« video streaming » ≠ « music streaming »), sinon au moins un
        best = [p for p in affordable if hits(p) == len(words)] or [p for p in affordable if hits(p) > 0]
    else:
        best = affordable
    return sorted(best, key=lambda p: Decimal(p["price"]))
