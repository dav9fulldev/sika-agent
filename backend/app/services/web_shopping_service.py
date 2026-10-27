"""
SIKA Pay — Recherche de produits chez de vrais marchands en ligne (Channel3, lecture seule).

Channel3 (sponsor du hackathon) renvoie, pour chaque produit, les offres de plusieurs marchands
(site, prix, disponibilité, état, lien d'achat). SIKA :
1. filtre par budget et disponibilité, compare les offres et désigne la moins chère ;
2. ne paie jamais sur ces sites : il n'existe pas d'API permettant à SIKA de passer commande chez
   un marchand tiers. L'utilisateur ouvre la page du marchand et y paie lui-même (avec PayPal si le
   marchand le propose). Les achats payés dans l'app passent par les boutiques partenaires (demo_catalog).

La clé API reste côté serveur (variable CHANNEL3_API_KEY ou Secret Manager) et n'est jamais journalisée.
"""

import logging
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

import requests

from ..config import settings

logger = logging.getLogger("SikaWebShopping")

CENT = Decimal("0.01")
SOURCE = "Channel3 (real merchant listings)"


class WebShoppingError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        self.message = message
        super().__init__(f"{code}: {message}")


def _money(value: Any) -> Optional[Decimal]:
    try:
        dec = Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return None
    return dec.quantize(CENT, rounding=ROUND_HALF_UP) if dec.is_finite() and dec >= 0 else None


def _https(url: Any) -> Optional[str]:
    if isinstance(url, str) and urlparse(url).scheme == "https" and urlparse(url).hostname:
        return url
    return None


def _offer(raw: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    price = raw.get("price") or {}
    # Le prix est documenté sous « price.price » (référence) et « price.amount » (exemples) : on accepte les deux
    amount = _money(price.get("price", price.get("amount")))
    url = _https(raw.get("url"))
    domain = str(raw.get("domain") or "").strip().lower()
    if amount is None or not url or not domain:
        return None
    compare = _money(price.get("compare_at_price"))
    return {
        "merchant": domain,
        "price": str(amount),
        "compare_at_price": str(compare) if compare and compare > amount else None,
        "currency": str(price.get("currency") or "USD").upper(),
        "availability": raw.get("availability") or "Unknown",
        "condition": raw.get("condition"),
        "url": url,
    }


def _image(raw: Dict[str, Any]) -> Optional[str]:
    images = raw.get("images") or []
    main = next((i for i in images if i.get("is_main_image")), images[0] if images else None)
    if not main:
        return None
    return _https(main.get("cleaned_url")) or _https(main.get("url"))


def normalize_product(raw: Dict[str, Any], max_price: Optional[Decimal] = None) -> Optional[Dict[str, Any]]:
    """Produit Channel3 → vue SIKA : offres triées par prix, meilleure offre neuve, en stock et dans le budget."""
    offers = [o for o in (_offer(x) for x in raw.get("offers") or []) if o]
    if not offers or not raw.get("title"):
        return None
    offers.sort(key=lambda o: Decimal(o["price"]))
    eligible = [
        o for o in offers
        if o["availability"] in ("InStock", "LimitedAvailability")
        and o["condition"] in (None, "new")
        and (max_price is None or Decimal(o["price"]) <= max_price)
    ]
    best = eligible[0] if eligible else None
    brands = raw.get("brands") or []
    return {
        "product_id": str(raw.get("id") or ""),
        "title": str(raw["title"])[:200],
        "brand": (brands[0] or {}).get("name") if brands else None,
        "image_url": _image(raw),
        "offers": offers[:6],
        "offer_count": len(offers),
        "best_offer": best,
        "within_budget": best is not None if max_price is not None else None,
        "savings_vs_highest": str(Decimal(offers[-1]["price"]) - Decimal(best["price"])) if best and len(offers) > 1 else None,
    }


class WebShoppingService:
    def __init__(self, session: Optional[requests.Session] = None):
        self._session = session or requests.Session()

    def is_configured(self) -> bool:
        return bool(settings.CHANNEL3_API_KEY)

    def _headers(self, user_ref: Optional[str]) -> Dict[str, str]:
        headers = {"x-api-key": settings.CHANNEL3_API_KEY, "Content-Type": "application/json"}
        if user_ref:
            # Attribution des clics par utilisateur SIKA (identifiant opaque, aucune donnée personnelle)
            headers["x-user-id"] = f"sika-{user_ref}"[:128]
        return headers

    def refresh_offers(self, product_id: str, user_ref: Optional[str] = None) -> Dict[str, Any]:
        """Prix, stock et liens d'achat à jour (GET /v1/products/{id}, gratuit) : les liens d'offre expirent vite."""
        if not self.is_configured():
            raise WebShoppingError("WEB_SEARCH_NOT_CONFIGURED", "Web product search is not configured on the SIKA backend.")
        pid = str(product_id or "")
        if not pid or len(pid) > 64 or not pid.replace("-", "").replace("_", "").isalnum():
            raise WebShoppingError("INVALID_PRODUCT", "Unknown product.")
        try:
            resp = self._session.get(f"{settings.CHANNEL3_API_BASE}/v1/products/{pid}", headers=self._headers(user_ref), timeout=20)
        except requests.exceptions.RequestException as e:
            logger.warning(f"[WEB SHOPPING] Channel3 unreachable: {type(e).__name__}")
            raise WebShoppingError("WEB_SEARCH_UNAVAILABLE", "The product service could not be reached. Try again.")
        if resp.status_code == 404:
            raise WebShoppingError("INVALID_PRODUCT", "This product is no longer listed.")
        if resp.status_code != 200:
            raise WebShoppingError("WEB_SEARCH_UNAVAILABLE", f"The product service returned an error ({resp.status_code}).")
        product = normalize_product(resp.json())
        if not product:
            raise WebShoppingError("INVALID_PRODUCT", "This product has no available offer anymore.")
        return product

    def search(self, query: str, max_price: Any = None, limit: int = 5, user_ref: Optional[str] = None) -> Dict[str, Any]:
        if not self.is_configured():
            raise WebShoppingError("WEB_SEARCH_NOT_CONFIGURED", "Web product search is not configured on the SIKA backend.")
        query = (query or "").strip()[:200]
        if not query:
            raise WebShoppingError("EMPTY_QUERY", "Say what product you are looking for.")
        budget = _money(max_price) if max_price not in (None, "") else None
        body: Dict[str, Any] = {"query": query, "limit": max(1, min(int(limit or 10), 20)),
                                "filters": {"availability": ["InStock", "LimitedAvailability"]}}
        if budget:
            body["filters"]["price"] = {"max_price": float(budget)}
        try:
            resp = self._session.post(
                f"{settings.CHANNEL3_API_BASE}/v1/search",
                json=body,
                headers=self._headers(user_ref),
                timeout=20,
            )
        except requests.exceptions.RequestException as e:
            logger.warning(f"[WEB SHOPPING] Channel3 unreachable: {type(e).__name__}")
            raise WebShoppingError("WEB_SEARCH_UNAVAILABLE", "The product search service could not be reached. Try again.")
        if resp.status_code != 200:
            logger.warning(f"[WEB SHOPPING] Channel3 HTTP {resp.status_code}")
            raise WebShoppingError("WEB_SEARCH_UNAVAILABLE", f"The product search service returned an error ({resp.status_code}).")
        try:
            raw_products = resp.json().get("products") or []
        except ValueError:
            raise WebShoppingError("WEB_SEARCH_UNAVAILABLE", "The product search service returned an invalid response.")
        products = [p for p in (normalize_product(r, budget) for r in raw_products) if p]
        # Les produits avec une offre éligible d'abord, puis par meilleur prix
        products.sort(key=lambda p: (p["best_offer"] is None, Decimal(p["best_offer"]["price"]) if p["best_offer"] else Decimal(0)))
        merchants = {o["merchant"] for p in products for o in p["offers"]}
        # Le modèle et l'app voient exactement les mêmes produits (au plus 3), pour que le texte corresponde aux cartes
        shown = products[:3]
        return {
            "source": SOURCE,
            "query": query,
            "max_price": str(budget) if budget else None,
            "products_compared": len(products),
            "merchants_compared": len(merchants),
            "count": len(shown),
            "products": shown,
            "payment_note": "These are real merchants. SIKA cannot pay on their sites: the user opens the merchant page and pays there "
                            "(with PayPal when the merchant offers it). Only SIKA partner stores can be paid inside the app.",
        }


web_shopping_service = WebShoppingService()
