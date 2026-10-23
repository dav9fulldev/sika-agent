"""
Catalogue de démonstration du marchand fictif "SIKA Demo Store".

IMPORTANT — Données de démonstration :
- Ces produits sont FICTIFS. Ils servent uniquement de source d'informations
  non financières (nom, description, prix catalogue) pour le parcours de commerce agentique.
- Aucun résultat PayPal n'est simulé ici : les commandes sont créées et capturées
  réellement dans le sandbox PayPal à partir de ces prix.
- Le prix fait foi côté serveur : l'agent IA ne peut transmettre qu'un SKU et une quantité,
  jamais un montant.

Tous les articles sont numériques (aucune livraison), ce qui correspond à
shipping_preference=NO_SHIPPING côté PayPal.
"""

import re
from decimal import Decimal
from typing import Dict, Any, List, Optional

CATALOG_SOURCE = "SIKA Demo Store — fictional sandbox catalog (demo data, not real products)"
CATALOG_CURRENCY = "USD"

_PRODUCTS: List[Dict[str, Any]] = [
    {
        "sku": "SIKA-COURSE-BUDGET",
        "name": "Online course: Personal Budgeting Basics",
        "description": "6-hour self-paced video course on budgeting, saving and avoiding debt.",
        "price": "29.00",
        "category": "education",
        "tags": ["course", "budget", "budgeting", "finance", "learning", "cours", "formation", "épargne"],
    },
    {
        "sku": "SIKA-COURSE-EXCEL",
        "name": "Online course: Excel for Small Business",
        "description": "Spreadsheets, invoices and cash-flow tracking for small shop owners.",
        "price": "49.00",
        "category": "education",
        "tags": ["course", "excel", "spreadsheet", "business", "learning", "cours", "formation", "commerce"],
    },
    {
        "sku": "SIKA-COURSE-MARKETING",
        "name": "Online course: Social Media Marketing Starter",
        "description": "Grow a small business on social networks, with 30 ready-made post templates.",
        "price": "64.00",
        "category": "education",
        "tags": ["course", "marketing", "social", "business", "learning", "cours", "formation"],
    },
    {
        "sku": "SIKA-EBOOK-SMALLBIZ",
        "name": "E-book: Starting a Small Business",
        "description": "Practical 180-page guide: business plan, pricing, first customers.",
        "price": "12.50",
        "category": "books",
        "tags": ["ebook", "book", "business", "guide", "livre", "entreprise"],
    },
    {
        "sku": "SIKA-CLOUD-200GB",
        "name": "Cloud storage 200 GB — 1 year plan",
        "description": "Encrypted cloud backup for photos and documents, 12 months.",
        "price": "29.99",
        "category": "software",
        "tags": ["cloud", "storage", "backup", "stockage", "sauvegarde", "subscription"],
    },
    {
        "sku": "SIKA-LANG-3M",
        "name": "Language learning app — 3-month premium plan",
        "description": "English/French lessons with speaking practice, 3 months.",
        "price": "36.00",
        "category": "education",
        "tags": ["language", "english", "french", "app", "langue", "anglais", "subscription"],
    },
    {
        "sku": "SIKA-PHOTO-PRO",
        "name": "Photo editing software — annual license",
        "description": "Professional photo editor for product pictures, 1-year license.",
        "price": "54.99",
        "category": "software",
        "tags": ["photo", "editing", "software", "license", "logiciel", "image"],
    },
    {
        "sku": "SIKA-WEB-STARTER",
        "name": "Website starter pack — domain + hosting, 1 year",
        "description": "One domain name and basic hosting to put a small business online.",
        "price": "47.88",
        "category": "software",
        "tags": ["website", "domain", "hosting", "site", "web", "business", "hébergement"],
    },
    {
        "sku": "SIKA-DESIGN-TEMPLATES",
        "name": "Design template pack — 120 social & flyer templates",
        "description": "Editable templates for flyers, menus and social posts.",
        "price": "19.00",
        "category": "design",
        "tags": ["design", "templates", "flyer", "social", "modèles"],
    },
]

_STOPWORDS = {
    "a", "an", "the", "i", "want", "to", "buy", "me", "for", "under", "my", "of", "and", "with", "help",
    "le", "la", "les", "un", "une", "des", "je", "veux", "acheter", "pour", "moins", "de", "mon", "ma", "et",
    "budget", "dollars", "usd", "prepare", "payment", "paiement", "please", "stp", "than", "less", "max",
    "dollar", "without", "going", "over", "spend", "need", "some", "something", "get", "find", "cheap", "cheaper",
    "aide", "moi", "sans", "dépasser", "depasser", "trouve", "trouver", "besoin", "quelque", "chose", "voudrais",
}


def _public(product: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "sku": product["sku"],
        "name": product["name"],
        "description": product["description"],
        "unit_price": product["price"],
        "currency": CATALOG_CURRENCY,
        "category": product["category"],
        "delivery": "digital",
        "source": CATALOG_SOURCE,
    }


def get_product(sku: str) -> Optional[Dict[str, Any]]:
    clean = (sku or "").strip().upper()
    for p in _PRODUCTS:
        if p["sku"] == clean:
            return _public(p)
    return None


def list_products() -> List[Dict[str, Any]]:
    return [_public(p) for p in _PRODUCTS]


def search_products(query: str = "", max_price: Optional[Decimal] = None, limit: int = 5) -> List[Dict[str, Any]]:
    """Recherche par mots-clés dans le catalogue de démonstration, filtrée par prix maximum."""
    return [p for _, p in rank_products(query, max_price, limit)]


def query_tokens(query: str) -> List[str]:
    """Mots significatifs d'une requête (les nombres sont des budgets ou quantités, pas des mots-clés)."""
    return [t for t in re.findall(r"[a-zA-ZÀ-ÿ]+", (query or "").lower()) if t not in _STOPWORDS and len(t) > 2]


def _matches(token: str, words: set) -> bool:
    # Mot entier, ou pluriel/singulier simple ("photo" ~ "photos")
    return any(w == token or (len(token) >= 4 and (w.startswith(token) or token.startswith(w)) and abs(len(w) - len(token)) <= 2)
               for w in words)


def rank_products(query: str = "", max_price: Optional[Decimal] = None, limit: int = 5) -> List[tuple]:
    """Comme search_products, mais renvoie des couples (score de pertinence, produit)."""
    tokens = query_tokens(query)

    scored = []
    for p in _PRODUCTS:
        price = Decimal(p["price"])
        if max_price is not None and price > max_price:
            continue
        words = set(re.findall(r"[a-zA-ZÀ-ÿ]+", " ".join([p["name"], p["description"], p["category"], " ".join(p["tags"])]).lower()))
        score = sum(1 for t in tokens if _matches(t, words))
        if tokens and score == 0:
            continue
        scored.append((score, price, p))

    scored.sort(key=lambda x: (-x[0], x[1]))
    return [(score, _public(p)) for score, _, p in scored[: max(1, min(limit, 10))]]
