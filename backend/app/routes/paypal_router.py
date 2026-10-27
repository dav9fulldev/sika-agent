"""
SIKA Pay — Endpoints PayPal (sandbox).

Toutes les opérations exigent un JWT SIKA, sauf les pages de retour/annulation
appelées par le navigateur après le passage sur PayPal (elles ne font confiance
qu'à une vérification serveur GET /v2/checkout/orders/{id}).
"""

import html
import json
import logging
import re
from decimal import Decimal, InvalidOperation
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Query, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import settings
from ..services import demo_catalog
from ..services.auth_service import oauth2_auth_service
from ..services.security_rate_limiter import security_rate_limiter
from ..services.paypal_checkout_service import paypal_checkout_service, CheckoutError
from ..services.agent_mandate_service import agent_mandate_service, MandateError
from ..services.wallet_integrations.paypal_api_service import paypal_api_service, PayPalAPIError, PayPalNetworkError
from ..database import engine
from ..models.paypal_webhook_event import PayPalWebhookEventModel

logger = logging.getLogger("SikaPayPalRouter")

router = APIRouter(prefix="/api/v1/paypal", tags=["paypal"])

_CHECKOUT_ID = re.compile(r"^chk_[a-f0-9]{24}$")
_ORDER_ID = re.compile(r"^[A-Z0-9]{8,64}$")


class PrepareCheckoutRequest(BaseModel):
    sku: str = Field(..., max_length=64)
    quantity: int = Field(1, ge=1, le=10)
    budget_limit: Optional[str] = Field(None, max_length=20)
    budget_currency: Optional[str] = Field(None, max_length=3)


class ConfirmCheckoutRequest(BaseModel):
    details_hash: str = Field(..., min_length=64, max_length=64)


class CancelCheckoutRequest(BaseModel):
    reason: str = Field("USER_CANCELLED", max_length=100)


class AgentAuthorizationRequest(BaseModel):
    max_per_purchase: str = Field(..., max_length=20)
    daily_limit: str = Field(..., max_length=20)
    duration_hours: int = Field(..., ge=1, le=720)


def _raise(err: CheckoutError):
    raise HTTPException(status_code=err.http_status, detail=err.to_dict())


def _checkout_id(value: str) -> str:
    if not _CHECKOUT_ID.match(value or ""):
        raise HTTPException(status_code=404, detail={"success": False, "error_code": "NOT_FOUND", "message": "Checkout not found."})
    return value


@router.get("/status", summary="SIKA Pay status", description="État de la configuration PayPal sandbox (sans secret).")
def paypal_status():
    return {
        "provider": "PAYPAL",
        "environment": "sandbox",
        "configured": settings.paypal_configured,
        "api_base": settings.PAYPAL_API_BASE,
        "allowed_currencies": settings.PAYPAL_ALLOWED_CURRENCIES,
        "max_order_amount": f"{settings.PAYPAL_MAX_ORDER_AMOUNT:.2f}",
        "merchant": settings.PAYPAL_BRAND_NAME,
        "catalog_source": demo_catalog.CATALOG_SOURCE,
    }


@router.get("/catalog", summary="Demo catalog search")
def paypal_catalog(query: str = Query("", max_length=200), max_price: Optional[str] = Query(None, max_length=20),
                   authorization: Optional[str] = Header(None)):
    oauth2_auth_service.require_authenticated_user_id(authorization)
    price = None
    if max_price:
        try:
            price = Decimal(max_price)
        except InvalidOperation:
            raise HTTPException(status_code=422, detail="max_price must be a number.")
    return {"source": demo_catalog.CATALOG_SOURCE, "products": demo_catalog.search_products(query, max_price=price, limit=10)}


@router.post("/checkouts", summary="Prepare checkout", description="Prépare un checkout sans contacter PayPal ni débiter.")
def prepare_checkout(data: PrepareCheckoutRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    try:
        return paypal_checkout_service.prepare_checkout(
            user_id, data.sku, data.quantity, data.budget_limit, data.budget_currency
        )
    except CheckoutError as e:
        _raise(e)


@router.get("/checkouts", summary="Checkout history")
def list_checkouts(limit: int = Query(10, ge=1, le=50), authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return {"checkouts": paypal_checkout_service.list_checkouts(user_id, limit)}


@router.get("/checkouts/{checkout_id}", summary="Checkout details",
            description="Détails + journal d'audit. sync=true revérifie le statut auprès de PayPal (lecture seule).")
def get_checkout(checkout_id: str, sync: bool = False, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    try:
        return paypal_checkout_service.get_checkout(user_id, _checkout_id(checkout_id), sync=sync)
    except CheckoutError as e:
        _raise(e)


@router.post("/checkouts/{checkout_id}/confirm", summary="Confirm and create PayPal order",
             description="Confirmation explicite de l'utilisateur : crée la commande PayPal sandbox et renvoie le lien d'approbation.")
def confirm_checkout(checkout_id: str, data: ConfirmCheckoutRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    security_rate_limiter.check_confirm_rate_limit(str(user_id))
    try:
        return paypal_checkout_service.confirm_and_create_order(user_id, _checkout_id(checkout_id), data.details_hash)
    except CheckoutError as e:
        _raise(e)


@router.post("/checkouts/{checkout_id}/capture", summary="Capture approved PayPal order",
             description="Capture uniquement si PayPal confirme côté serveur que la commande est APPROVED.")
def capture_checkout(checkout_id: str, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    security_rate_limiter.check_confirm_rate_limit(str(user_id))
    try:
        return paypal_checkout_service.capture(user_id, _checkout_id(checkout_id))
    except CheckoutError as e:
        _raise(e)


@router.post("/checkouts/{checkout_id}/cancel", summary="Cancel checkout")
def cancel_checkout(checkout_id: str, data: Optional[CancelCheckoutRequest] = None, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    try:
        return paypal_checkout_service.cancel(user_id, _checkout_id(checkout_id), (data.reason if data else "USER_CANCELLED"))
    except CheckoutError as e:
        _raise(e)


# ----------------------------------------------------------------------
# Recherche web (Channel3) : offres à jour juste avant d'ouvrir le site du marchand
# ----------------------------------------------------------------------

@router.get("/web-products/{product_id}", summary="Fresh offers for a web product",
            description="Prix, stock et liens d'achat à jour (les liens d'offre expirent). Aucun paiement.")
def web_product_offers(product_id: str, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    from ..services.web_shopping_service import web_shopping_service, WebShoppingError
    try:
        return web_shopping_service.refresh_offers(product_id, user_ref=str(user_id))
    except WebShoppingError as e:
        status = 404 if e.code == "INVALID_PRODUCT" else 503
        raise HTTPException(status_code=status, detail={"success": False, "error_code": e.code, "message": e.message})


# ----------------------------------------------------------------------
# Mode hybride : autorisation accordée par l'utilisateur à l'agent
# ----------------------------------------------------------------------

@router.get("/agent-authorization", summary="Current agent authorization")
def get_agent_authorization(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return agent_mandate_service.get(user_id)


@router.put("/agent-authorization", summary="Authorize SIKA to confirm purchases",
            description="L'utilisateur autorise l'agent à confirmer des achats pour lui, dans les limites qu'il fixe.")
def put_agent_authorization(data: AgentAuthorizationRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    try:
        return agent_mandate_service.grant(user_id, data.max_per_purchase, data.daily_limit, data.duration_hours)
    except MandateError as e:
        raise HTTPException(status_code=e.http_status, detail=e.to_dict())


@router.delete("/agent-authorization", summary="Revoke the agent authorization")
def delete_agent_authorization(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return agent_mandate_service.revoke(user_id)


# ----------------------------------------------------------------------
# Webhooks PayPal (signature vérifiée par l'API PayPal avant tout traitement)
# ----------------------------------------------------------------------

_webhook_id_cache: dict = {}


def webhook_url() -> str:
    return f"{settings.PUBLIC_BASE_URL}/api/v1/paypal/webhook"


def _resolve_webhook_id() -> Optional[str]:
    """PAYPAL_WEBHOOK_ID si défini, sinon l'ID du webhook enregistré chez PayPal pour cette URL."""
    if settings.PAYPAL_WEBHOOK_ID:
        return settings.PAYPAL_WEBHOOK_ID
    if "id" not in _webhook_id_cache:
        url = webhook_url()
        found = next((w.get("id") for w in paypal_api_service.list_webhooks() if w.get("url") == url), None)
        if not found:
            return None
        _webhook_id_cache["id"] = found
    return _webhook_id_cache["id"]


@router.post("/webhook", include_in_schema=False)
async def paypal_webhook(request: Request):
    raw = await request.body()
    try:
        event = json.loads(raw or b"{}")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid JSON.")
    event_id = str(event.get("id") or "")[:64]
    event_type = str(event.get("event_type") or "")[:80]
    if not event_id or not event_type:
        raise HTTPException(status_code=400, detail="Not a PayPal event.")

    try:
        webhook_id = _resolve_webhook_id()
        verified = bool(webhook_id) and paypal_api_service.verify_webhook_signature(
            headers={k.lower(): v for k, v in request.headers.items()}, event=event, webhook_id=webhook_id)
    except (PayPalAPIError, PayPalNetworkError) as e:
        # PayPal renverra l'événement : on répond en erreur plutôt que d'accepter sans vérification
        logger.warning(f"[PAYPAL WEBHOOK] Verification unavailable for {event_type}: {type(e).__name__}")
        raise HTTPException(status_code=503, detail="Signature verification unavailable.")
    if not verified:
        logger.warning(f"[PAYPAL WEBHOOK] Rejected unverified event {event_type}")
        raise HTTPException(status_code=401, detail="Invalid webhook signature.")

    with Session(engine) as db:
        if db.get(PayPalWebhookEventModel, event_id):
            return {"received": True, "duplicate": True}
        record = PayPalWebhookEventModel(event_id=event_id, event_type=event_type,
                                         resource_id=str((event.get("resource") or {}).get("id") or "")[:64] or None)
        db.add(record)
        try:
            db.commit()
        except IntegrityError:
            return {"received": True, "duplicate": True}

    outcome = paypal_checkout_service.handle_webhook_event(event)
    with Session(engine) as db:
        record = db.get(PayPalWebhookEventModel, event_id)
        if record:
            record.outcome = outcome[:80]
            db.commit()
    logger.info(f"[PAYPAL WEBHOOK] {event_type} {event_id}: {outcome}")
    return {"received": True, "outcome": outcome}


def _page(title: str, body: str) -> HTMLResponse:
    content = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1"><title>SIKA Pay</title>
<style>body{{font-family:system-ui,-apple-system,sans-serif;background:#0b1020;color:#f1f5f9;margin:0;padding:32px 20px;text-align:center}}
.card{{max-width:420px;margin:40px auto;background:#151b2e;border-radius:20px;padding:28px}}
.badge{{display:inline-block;background:#f59e0b22;color:#fbbf24;border-radius:999px;padding:4px 12px;font-size:12px;font-weight:600}}
a.btn{{display:block;margin-top:24px;background:#635bff;color:#fff;text-decoration:none;padding:14px;border-radius:14px;font-weight:600}}
p{{color:#cbd5e1;line-height:1.5}}</style></head>
<body><div class="card"><span class="badge">PayPal SANDBOX — test mode</span><h2>{html.escape(title)}</h2>
<p>{html.escape(body)}</p><a class="btn" href="sikapay://paypal/return">Return to SIKA Pay</a></div>
<script>setTimeout(function(){{location.href="sikapay://paypal/return"}},600)</script></body></html>"""
    return HTMLResponse(content=content)


@router.get("/return", include_in_schema=False)
def paypal_return(token: str = Query("", max_length=64)):
    if not _ORDER_ID.match(token or ""):
        return _page("Unknown order", "This PayPal return link is not valid.")
    status = paypal_checkout_service.handle_payer_return(token)
    if status == "COMPLETED":
        return _page("Payment completed", "PayPal confirmed the payment. Return to SIKA Pay to see your receipt.")
    if status in ("APPROVED", "CAPTURING", "PENDING", "UNKNOWN_RESULT"):
        return _page("Approval received", "PayPal confirmed your approval. Return to SIKA Pay: it is verifying the payment with PayPal.")
    if status is None:
        return _page("Unknown order", "SIKA does not know this PayPal order.")
    return _page("Back from PayPal", "Return to SIKA Pay: it will verify the order status with PayPal.")


@router.get("/cancel", include_in_schema=False)
def paypal_cancel(token: str = Query("", max_length=64)):
    if _ORDER_ID.match(token or ""):
        paypal_checkout_service.handle_payer_cancel(token)
    return _page("Payment cancelled", "You cancelled on PayPal. No payment was made.")
