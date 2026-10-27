"""
SIKA Pay — Alertes de prix sur des produits trouvés sur le web (Channel3 product subscriptions).

1. L'utilisateur choisit un prix cible (ou « retour en stock ») ; SIKA abonne le produit chez Channel3
   (POST /v1/product-subscriptions, gratuit).
2. Channel3 envoie les changements d'offre par webhook (Svix, format Standard Webhooks). La signature
   est vérifiée avec le secret whsec_ de l'endpoint avant tout traitement ; chaque événement n'est
   traité qu'une fois (livraison « au moins une fois »).
3. Une offre neuve qui passe sous le prix cible (ou revient en stock) déclenche l'alerte, affichée
   dans l'app. Aucun achat n'est fait automatiquement.
"""

import base64
import hashlib
import hmac
import logging
import time
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Dict, List, Optional

import requests
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import settings
from ..database import engine
from ..models.price_watch import PriceWatchModel, ShoppingWebhookEventModel

logger = logging.getLogger("SikaPriceWatch")

CENT = Decimal("0.01")
MAX_ACTIVE_WATCHES = 20
WATCH_EVENTS = ["offer.price.changed", "offer.availability.changed", "offer.created"]
SIGNATURE_TOLERANCE_SECONDS = 300


class PriceWatchError(Exception):
    def __init__(self, code: str, message: str, http_status: int = 400):
        self.code = code
        self.message = message
        self.http_status = http_status
        super().__init__(f"{code}: {message}")

    def to_dict(self) -> Dict[str, Any]:
        return {"success": False, "error_code": self.code, "message": self.message}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    return (dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)).isoformat()


def verify_standard_webhook(secret: str, headers: Dict[str, str], body: bytes, now: Optional[float] = None) -> bool:
    """Signature Svix / Standard Webhooks : HMAC-SHA256 de « id.timestamp.corps » avec le secret base64 (après whsec_)."""
    msg_id = headers.get("svix-id") or headers.get("webhook-id") or ""
    ts = headers.get("svix-timestamp") or headers.get("webhook-timestamp") or ""
    sigs = headers.get("svix-signature") or headers.get("webhook-signature") or ""
    if not (secret and msg_id and ts and sigs):
        return False
    try:
        if abs((now or time.time()) - int(ts)) > SIGNATURE_TOLERANCE_SECONDS:
            return False  # rejeu ou horloge incohérente
        key = base64.b64decode(secret.split("_", 1)[1] if secret.startswith("whsec_") else secret)
    except (ValueError, TypeError):
        return False
    expected = base64.b64encode(hmac.new(key, f"{msg_id}.{ts}.".encode() + body, hashlib.sha256).digest()).decode()
    for candidate in sigs.split():
        version, _, value = candidate.partition(",")
        if version == "v1" and hmac.compare_digest(value, expected):
            return True
    return False


class PriceWatchService:
    def __init__(self, session: Optional[requests.Session] = None):
        self._session = session or requests.Session()

    # ------------------------------------------------------------------
    # Abonnements Channel3
    # ------------------------------------------------------------------

    def _channel3(self, method: str, path: str, json_body: Optional[dict] = None) -> Dict[str, Any]:
        if not settings.CHANNEL3_API_KEY:
            raise PriceWatchError("WEB_SEARCH_NOT_CONFIGURED", "Price alerts are not configured on the SIKA backend.", 503)
        try:
            resp = self._session.request(method, f"{settings.CHANNEL3_API_BASE}{path}", json=json_body,
                                         headers={"x-api-key": settings.CHANNEL3_API_KEY, "Content-Type": "application/json"},
                                         timeout=20)
        except requests.exceptions.RequestException as e:
            logger.warning(f"[PRICE WATCH] Channel3 unreachable: {type(e).__name__}")
            raise PriceWatchError("WEB_SEARCH_UNAVAILABLE", "The price alert service could not be reached. Try again.", 503)
        if resp.status_code == 404:
            raise PriceWatchError("INVALID_PRODUCT", "This product is no longer listed.", 404)
        if resp.status_code not in (200, 201):
            logger.warning(f"[PRICE WATCH] Channel3 {method} {path} -> HTTP {resp.status_code}")
            raise PriceWatchError("WEB_SEARCH_UNAVAILABLE", f"The price alert service returned an error ({resp.status_code}).", 503)
        try:
            return resp.json()
        except ValueError:
            return {}

    # ------------------------------------------------------------------
    # Alertes de l'utilisateur
    # ------------------------------------------------------------------

    @staticmethod
    def to_public(row: PriceWatchModel) -> Dict[str, Any]:
        return {
            "watch_id": row.id,
            "product_id": row.product_id,
            "title": row.title,
            "image_url": row.image_url,
            "target_price": row.target_price,
            "currency": row.currency,
            "status": row.status,
            "last_price": row.last_price,
            "last_merchant": row.last_merchant,
            "last_event": row.last_event,
            "triggered_at": _iso(row.triggered_at),
            "unseen": row.status == "triggered" and row.seen_at is None,
            "created_at": _iso(row.created_at),
        }

    def create(self, user_id: int, product_id: str, target_price: Any = None) -> Dict[str, Any]:
        from .web_shopping_service import web_shopping_service, WebShoppingError

        target = None
        if target_price not in (None, ""):
            try:
                target = Decimal(str(target_price)).quantize(CENT, rounding=ROUND_HALF_UP)
            except (InvalidOperation, ValueError):
                raise PriceWatchError("INVALID_TARGET", "The target price must be a number.")
            if isinstance(target_price, bool) or not target.is_finite() or target <= 0:
                raise PriceWatchError("INVALID_TARGET", "The target price must be a positive amount.")
        try:
            product = web_shopping_service.refresh_offers(product_id, user_ref=str(user_id))
        except WebShoppingError as e:
            raise PriceWatchError(e.code, e.message, 404 if e.code == "INVALID_PRODUCT" else 503)

        with Session(engine) as db:
            active = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id,
                                                      PriceWatchModel.status == "active").all()
            same = next((w for w in active if w.product_id == product["product_id"]), None)
            if not same and len(active) >= MAX_ACTIVE_WATCHES:
                raise PriceWatchError("TOO_MANY_WATCHES", f"You can watch up to {MAX_ACTIVE_WATCHES} products at a time.")

        # Abonnement idempotent chez Channel3 (même produit et mêmes événements = même abonnement)
        sub = self._channel3("POST", "/v1/product-subscriptions",
                             {"product_id": product["product_id"], "events": WATCH_EVENTS})
        best = product.get("best_offer") or {}
        now = _now()
        with Session(engine) as db:
            row = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id,
                                                   PriceWatchModel.product_id == product["product_id"],
                                                   PriceWatchModel.status == "active").first()
            if not row:
                row = PriceWatchModel(user_id=user_id, product_id=product["product_id"], created_at=now)
                db.add(row)
            row.title = product["title"][:200]
            row.image_url = (product.get("image_url") or "")[:512] or None
            row.target_price = str(target) if target is not None else None
            row.currency = best.get("currency") or "USD"
            row.subscription_id = str(sub.get("subscription_id") or sub.get("id") or "")[:64] or None
            row.last_price = best.get("price")
            row.last_merchant = best.get("merchant")
            row.updated_at = now
            db.commit()
            db.refresh(row)
            return self.to_public(row)

    def list(self, user_id: int) -> List[Dict[str, Any]]:
        with Session(engine) as db:
            rows = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id,
                                                    PriceWatchModel.status != "cancelled") \
                .order_by(PriceWatchModel.updated_at.desc()).limit(50).all()
            return [self.to_public(r) for r in rows]

    def mark_seen(self, user_id: int) -> None:
        with Session(engine) as db:
            db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id, PriceWatchModel.status == "triggered",
                                             PriceWatchModel.seen_at.is_(None)).update({"seen_at": _now()},
                                                                                      synchronize_session=False)
            db.commit()

    def cancel(self, user_id: int, watch_id: int) -> Dict[str, Any]:
        with Session(engine) as db:
            row = db.query(PriceWatchModel).filter(PriceWatchModel.id == watch_id).first()
            if not row or row.user_id != user_id:
                raise PriceWatchError("NOT_FOUND", "Price alert not found.", 404)
            row.status = "cancelled"
            row.updated_at = _now()
            db.commit()
            # L'abonnement Channel3 est partagé par produit : on ne l'annule que si plus personne ne le suit
            still_used = db.query(PriceWatchModel).filter(PriceWatchModel.subscription_id == row.subscription_id,
                                                          PriceWatchModel.status == "active").count()
            sub_id = row.subscription_id
            result = self.to_public(row)
        if sub_id and not still_used:
            try:
                self._channel3("DELETE", f"/v1/product-subscriptions/{sub_id}")
            except PriceWatchError as e:
                logger.warning(f"[PRICE WATCH] Channel3 unsubscribe failed: {e.code}")
        return result

    # ------------------------------------------------------------------
    # Webhooks Channel3 (signature déjà vérifiée par la route)
    # ------------------------------------------------------------------

    def handle_event(self, event: Dict[str, Any], message_id: Optional[str] = None) -> str:
        # L'ancien format « price.changed » (Price Tracking, obsolète) n'a pas d'id : on dédoublonne sur svix-id
        event_id = str(event.get("id") or message_id or "")[:80]
        event_type = str(event.get("type") or "")[:40]
        if not event_id or not (event_type.startswith("offer.") or event_type == "price.changed"):
            return "IGNORED"
        with Session(engine) as db:
            db.add(ShoppingWebhookEventModel(event_id=event_id, event_type=event_type))
            try:
                db.commit()
            except IntegrityError:
                return "DUPLICATE"

        data = event.get("data") or {}
        subject = data.get("subject") or {}
        product_id = str(subject.get("product_id") or "")
        merchant = str(subject.get("domain") or "")[:120] or None
        price = availability = None
        condition = "new"
        if event_type == "price.changed":
            # Format à plat : canonical_product_id, domain, old_price, new_price, currency, buy_url
            product_id = str(event.get("canonical_product_id") or "")
            merchant = str(event.get("domain") or "")[:120] or None
            price = event.get("new_price")
        elif event_type == "offer.price.changed":
            price = (data.get("current") or {}).get("price")
        elif event_type == "offer.availability.changed":
            availability = data.get("current")
        elif event_type == "offer.created":
            offer = data.get("offer") or {}
            price = (offer.get("price") or {}).get("price")
            availability = offer.get("availability")
            condition = offer.get("condition") or "new"
        else:
            return self._finish(event_id, "IGNORED_EVENT_TYPE")

        triggered = 0
        now = _now()
        with Session(engine) as db:
            rows = db.query(PriceWatchModel).filter(PriceWatchModel.product_id == product_id,
                                                    PriceWatchModel.status == "active").all()
            for row in rows:
                row.last_event = event_type
                row.updated_at = now
                if price is not None:
                    row.last_price = str(Decimal(str(price)).quantize(CENT))
                    row.last_merchant = merchant
                hit = False
                if condition in (None, "new"):
                    if row.target_price and price is not None and availability != "OutOfStock":
                        hit = Decimal(str(price)) <= Decimal(row.target_price)
                    elif not row.target_price and availability == "InStock":
                        hit = True
                if hit:
                    row.status = "triggered"
                    row.triggered_at = now
                    row.last_merchant = merchant
                    triggered += 1
            db.commit()
        return self._finish(event_id, f"MATCHED_{len(rows)}_TRIGGERED_{triggered}" if rows else "NO_WATCH")

    @staticmethod
    def _finish(event_id: str, outcome: str) -> str:
        with Session(engine) as db:
            row = db.get(ShoppingWebhookEventModel, event_id)
            if row:
                row.outcome = outcome[:80]
                db.commit()
        return outcome


price_watch_service = PriceWatchService()
