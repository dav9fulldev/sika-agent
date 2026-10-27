"""
Commerce Tools pour l'Agent SIKA Pay (PayPal sandbox)

Séparation stricte des responsabilités :
- search_demo_catalog          READ_ONLY              lecture du catalogue de démonstration
- prepare_paypal_checkout      CONFIRMATION_REQUIRED  prépare un checkout (aucun appel PayPal, aucun débit)
- get_paypal_checkout_status   READ_ONLY              revérifie le statut réel auprès de PayPal
- list_recent_paypal_checkouts READ_ONLY              historique de l'utilisateur

- confirm_checkout_with_authorization CONFIRMATION_REQUIRED confirme un checkout préparé, UNIQUEMENT si
  l'utilisateur a accordé une autorisation active (mode hybride) ; limites vérifiées par le serveur.
  Ce tool n'est présenté au modèle que lorsque cette autorisation existe.

La capture n'est PAS un tool : elle suit l'approbation du payeur sur PayPal, vérifiée côté serveur.
Le modèle ne fournit jamais de montant : uniquement un SKU, une quantité et le budget exprimé
par l'utilisateur. `user_id` est toujours injecté par le serveur.
"""

from decimal import Decimal, InvalidOperation
from typing import Optional

from .tool_models import RiskLevel, ToolResult
from ...services import demo_catalog
from ...services.paypal_checkout_service import paypal_checkout_service, CheckoutError

SEARCH_SCHEMA = {
    "type": "object",
    "properties": {
        "query": {"type": "string", "description": "Keywords describing what the user wants to buy, e.g. 'excel course'."},
        "max_price": {"type": "number", "description": "Budget ceiling stated by the user, in the catalog currency (USD). Omit if the user gave none."},
    },
    "required": ["query"],
}

PREPARE_SCHEMA = {
    "type": "object",
    "properties": {
        "sku": {"type": "string", "description": "Exact SKU returned by search_demo_catalog. Never invent one."},
        "quantity": {"type": "integer", "description": "Quantity requested by the user (1-10). Use 1 if the user did not specify."},
        "budget_limit": {"type": "number", "description": "Budget ceiling stated by the user. Omit if the user gave none."},
        "budget_currency": {"type": "string", "description": "ISO currency of the user's budget, e.g. USD. Omit if unknown."},
    },
    "required": ["sku", "quantity"],
}

STATUS_SCHEMA = {
    "type": "object",
    "properties": {
        "checkout_id": {"type": "string", "description": "checkout_id returned by prepare_paypal_checkout (starts with chk_)."},
    },
    "required": ["checkout_id"],
}

WEB_SEARCH_SCHEMA = {
    "type": "object",
    "properties": {
        "query": {"type": "string", "description": "Product the user wants, e.g. 'noise cancelling bluetooth headphones'."},
        "max_price": {"type": "number", "description": "Budget ceiling stated by the user, in USD. Omit if none."},
    },
    "required": ["query"],
}

WATCH_SCHEMA = {
    "type": "object",
    "properties": {
        "product_id": {"type": "string", "description": "product_id of a product returned by search_web_products."},
        "target_price": {"type": "number", "description": "Alert when a new offer is at or below this price (USD). Omit to be alerted when it is back in stock."},
    },
    "required": ["product_id"],
}

AGENT_CONFIRM_SCHEMA = {
    "type": "object",
    "properties": {
        "checkout_id": {"type": "string", "description": "checkout_id just returned by prepare_paypal_checkout (starts with chk_)."},
    },
    "required": ["checkout_id"],
}

LIST_SCHEMA = {
    "type": "object",
    "properties": {
        "limit": {"type": "integer", "description": "Number of recent checkouts to return (1-10)."},
    },
}


def _uid(user_id) -> Optional[int]:
    return int(user_id) if user_id is not None and str(user_id).isdigit() else None


def search_demo_catalog(query: str, max_price: Optional[float] = None) -> ToolResult:
    """Recherche des produits dans le catalogue du marchand de démonstration."""
    price = None
    if max_price is not None:
        try:
            price = Decimal(str(max_price))
            if not price.is_finite() or price <= 0:
                raise InvalidOperation
        except (InvalidOperation, ValueError):
            return ToolResult(success=False, tool_name="search_demo_catalog", risk_level=RiskLevel.READ_ONLY,
                              data={}, error_message="max_price must be a positive number.")
    products = demo_catalog.search_products(query or "", max_price=price, limit=5)
    return ToolResult(
        success=True,
        tool_name="search_demo_catalog",
        risk_level=RiskLevel.READ_ONLY,
        data={
            "source": demo_catalog.CATALOG_SOURCE,
            "currency": demo_catalog.CATALOG_CURRENCY,
            "query": query,
            "max_price": str(price) if price is not None else None,
            "count": len(products),
            "products": products,
        },
    )


def prepare_paypal_checkout(sku: str, quantity: int = 1, budget_limit: Optional[float] = None,
                            budget_currency: Optional[str] = None, user_id: Optional[str] = None,
                            user_request: Optional[str] = None) -> ToolResult:
    """Prépare un checkout PayPal sandbox SANS créer de commande ni débiter (confirmation humaine requise)."""
    uid = _uid(user_id)
    if uid is None:
        return ToolResult(success=False, tool_name="prepare_paypal_checkout", risk_level=RiskLevel.CONFIRMATION_REQUIRED,
                          data={}, error_message="An authenticated user is required.")
    try:
        checkout = paypal_checkout_service.prepare_checkout(
            uid, sku, quantity, budget_limit, budget_currency, user_request=user_request
        )
    except CheckoutError as e:
        return ToolResult(success=False, tool_name="prepare_paypal_checkout", risk_level=RiskLevel.CONFIRMATION_REQUIRED,
                          data={"error_code": e.code, **e.data}, error_message=e.message)
    return ToolResult(
        success=True,
        tool_name="prepare_paypal_checkout",
        risk_level=RiskLevel.CONFIRMATION_REQUIRED,
        requires_confirmation=True,
        data={"action_id": checkout["checkout_id"], "checkout": checkout},
    )


def confirm_checkout_with_authorization(checkout_id: str, user_id: Optional[str] = None) -> ToolResult:
    """Confirme un checkout préparé au nom de l'utilisateur, dans les limites de l'autorisation qu'il a accordée."""
    uid = _uid(user_id)
    name = "confirm_checkout_with_authorization"
    if uid is None:
        return ToolResult(success=False, tool_name=name, risk_level=RiskLevel.CONFIRMATION_REQUIRED,
                          data={}, error_message="An authenticated user is required.")
    try:
        checkout = paypal_checkout_service.confirm_by_agent(uid, str(checkout_id))
    except CheckoutError as e:
        return ToolResult(success=False, tool_name=name, risk_level=RiskLevel.CONFIRMATION_REQUIRED,
                          data={"error_code": e.code}, error_message=e.message)
    return ToolResult(success=True, tool_name=name, risk_level=RiskLevel.CONFIRMATION_REQUIRED,
                      data={"action_id": checkout["checkout_id"], "checkout": checkout})


def search_web_products(query: str, max_price: Optional[float] = None, user_id: Optional[str] = None) -> ToolResult:
    """Recherche de vrais produits chez des marchands en ligne (Channel3) : comparaison seulement, aucun paiement."""
    from ...services.web_shopping_service import web_shopping_service, WebShoppingError
    try:
        data = web_shopping_service.search(query, max_price, limit=10, user_ref=str(_uid(user_id)) if _uid(user_id) else None)
    except WebShoppingError as e:
        return ToolResult(success=False, tool_name="search_web_products", risk_level=RiskLevel.READ_ONLY,
                          data={"error_code": e.code}, error_message=e.message)
    return ToolResult(success=True, tool_name="search_web_products", risk_level=RiskLevel.READ_ONLY, data=data)


def watch_web_product_price(product_id: str, target_price: Optional[float] = None, user_id: Optional[str] = None) -> ToolResult:
    """Crée une alerte de prix (ou de retour en stock) sur un produit du web. Aucun achat automatique."""
    from ...services.price_watch_service import price_watch_service, PriceWatchError
    uid = _uid(user_id)
    if uid is None:
        return ToolResult(success=False, tool_name="watch_web_product_price", risk_level=RiskLevel.READ_ONLY,
                          data={}, error_message="An authenticated user is required.")
    try:
        watch = price_watch_service.create(uid, product_id, target_price)
    except PriceWatchError as e:
        return ToolResult(success=False, tool_name="watch_web_product_price", risk_level=RiskLevel.READ_ONLY,
                          data={"error_code": e.code}, error_message=e.message)
    return ToolResult(success=True, tool_name="watch_web_product_price", risk_level=RiskLevel.READ_ONLY, data={"watch": watch})


def list_price_watches(user_id: Optional[str] = None) -> ToolResult:
    """Alertes de prix de l'utilisateur et celles déjà déclenchées."""
    from ...services.price_watch_service import price_watch_service
    uid = _uid(user_id)
    if uid is None:
        return ToolResult(success=False, tool_name="list_price_watches", risk_level=RiskLevel.READ_ONLY,
                          data={}, error_message="An authenticated user is required.")
    return ToolResult(success=True, tool_name="list_price_watches", risk_level=RiskLevel.READ_ONLY,
                      data={"watches": price_watch_service.list(uid)})


def get_paypal_checkout_status(checkout_id: str, user_id: Optional[str] = None) -> ToolResult:
    """Retourne le statut d'un checkout après revérification (lecture seule) auprès de PayPal."""
    uid = _uid(user_id)
    if uid is None:
        return ToolResult(success=False, tool_name="get_paypal_checkout_status", risk_level=RiskLevel.READ_ONLY,
                          data={}, error_message="An authenticated user is required.")
    try:
        checkout = paypal_checkout_service.sync_with_paypal(uid, str(checkout_id))
    except CheckoutError as e:
        return ToolResult(success=False, tool_name="get_paypal_checkout_status", risk_level=RiskLevel.READ_ONLY,
                          data={"error_code": e.code}, error_message=e.message)
    checkout.pop("events", None)
    return ToolResult(success=True, tool_name="get_paypal_checkout_status", risk_level=RiskLevel.READ_ONLY,
                      data={"checkout": checkout})


def list_recent_paypal_checkouts(limit: int = 5, user_id: Optional[str] = None) -> ToolResult:
    """Liste les derniers checkouts PayPal de l'utilisateur (statuts enregistrés)."""
    uid = _uid(user_id)
    if uid is None:
        return ToolResult(success=False, tool_name="list_recent_paypal_checkouts", risk_level=RiskLevel.READ_ONLY,
                          data={}, error_message="An authenticated user is required.")
    rows = paypal_checkout_service.list_checkouts(uid, min(max(int(limit or 5), 1), 10))
    summary = [
        {k: c[k] for k in ("checkout_id", "status", "status_label", "total_amount", "currency", "created_at")}
        | {"item": c["item"]["name"], "paypal_order_id": c["paypal"]["order_id"]}
        for c in rows
    ]
    return ToolResult(success=True, tool_name="list_recent_paypal_checkouts", risk_level=RiskLevel.READ_ONLY,
                      data={"count": len(summary), "checkouts": summary})
