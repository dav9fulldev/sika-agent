"""
SIKA Pay — Alertes de prix sur des produits du web (Channel3).

Les routes d'alertes exigent un JWT SIKA. Le webhook Channel3 n'est traité qu'après vérification
de sa signature (secret whsec_ de l'endpoint, format Standard Webhooks).
"""

import json
import logging
from typing import Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

from ..config import settings
from ..services.auth_service import oauth2_auth_service
from ..services.price_watch_service import price_watch_service, PriceWatchError, verify_standard_webhook

logger = logging.getLogger("SikaShoppingRouter")

router = APIRouter(prefix="/api/v1/shopping", tags=["shopping"])


class PriceWatchRequest(BaseModel):
    product_id: str = Field(..., min_length=1, max_length=64)
    target_price: Optional[str] = Field(None, max_length=20)


def _raise(err: PriceWatchError):
    raise HTTPException(status_code=err.http_status, detail=err.to_dict())


@router.get("/price-watches", summary="My price alerts")
def list_price_watches(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    watches = price_watch_service.list(user_id)
    return {"watches": watches, "unseen": sum(1 for w in watches if w["unseen"])}


@router.post("/price-watches", summary="Watch a web product's price")
def create_price_watch(data: PriceWatchRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    try:
        return price_watch_service.create(user_id, data.product_id, data.target_price)
    except PriceWatchError as e:
        _raise(e)


@router.post("/price-watches/seen", summary="Mark triggered alerts as seen")
def mark_price_watches_seen(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    price_watch_service.mark_seen(user_id)
    return {"success": True}


@router.delete("/price-watches/{watch_id}", summary="Stop a price alert")
def delete_price_watch(watch_id: int, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    try:
        return price_watch_service.cancel(user_id, watch_id)
    except PriceWatchError as e:
        _raise(e)


@router.post("/channel3/webhook", include_in_schema=False)
async def channel3_webhook(request: Request):
    body = await request.body()
    if not settings.CHANNEL3_WEBHOOK_SECRET:
        # Jamais de traitement sans vérification : Channel3 réessaiera une fois le secret configuré
        raise HTTPException(status_code=503, detail="Webhook secret not configured.")
    headers = {k.lower(): v for k, v in request.headers.items()}
    if not verify_standard_webhook(settings.CHANNEL3_WEBHOOK_SECRET, headers, body):
        logger.warning("[CHANNEL3 WEBHOOK] Rejected event with an invalid signature")
        raise HTTPException(status_code=401, detail="Invalid webhook signature.")
    try:
        event = json.loads(body or b"{}")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid JSON.")
    outcome = price_watch_service.handle_event(event, message_id=headers.get("svix-id") or headers.get("webhook-id"))
    logger.info(f"[CHANNEL3 WEBHOOK] {event.get('type')} {str(event.get('id'))[:12]}: {outcome}")
    return {"received": True, "outcome": outcome}
