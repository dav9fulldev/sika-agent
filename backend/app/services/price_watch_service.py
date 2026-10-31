"""
SIKA Pay — Alertes de prix sur des produits trouvés sur le web (Channel3 product subscriptions).

1. L'utilisateur choisit un prix cible (ou « retour en stock ») ; SIKA abonne le produit chez Channel3
   (POST /v1/product-subscriptions, gratuit).
2. Channel3 envoie les changements d'offre par webhook (Svix, format Standard Webhooks). La signature
   est vérifiée avec le secret whsec_ de l'endpoint avant tout traitement ; chaque événement n'est
   traité qu'une fois (livraison « au moins une fois »).
3. Une offre neuve qui passe sous le prix cible (ou revient en stock) déclenche l'alerte.
4. Suivi automatique : les produits que SIKA montre sont suivis 30 jours (au plus 20, désactivable).
   Chaque changement utile du meilleur prix ou du stock crée une notification (app + push), sans spam :
   variations de moins de 2 % ou de 1 dollar ignorées, une notification par produit et par jour au plus.
Aucun achat n'est fait automatiquement.
"""

import base64
import hashlib
import hmac
import logging
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Dict, List, Optional

import requests
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from ..config import settings
from ..database import engine
from ..models.price_watch import PriceWatchModel, ShoppingWebhookEventModel, UserNotificationModel
from ..models.user import UserModel

logger = logging.getLogger("SikaPriceWatch")

CENT = Decimal("0.01")
MAX_ACTIVE_WATCHES = 20
MAX_AUTO_WATCHES = 20
AUTO_FOLLOW_DAYS = 30
WATCH_EVENTS = ["offer.price.changed", "offer.availability.changed", "offer.created", "offer.deleted"]
# Anti-spam : variation minimale et une notification par produit et par jour (sauf prix cible et retour en stock)
NOTIFY_MIN_DELTA = Decimal("1.00")
NOTIFY_MIN_RATIO = Decimal("0.02")
NOTIFY_COOLDOWN = timedelta(hours=24)
URGENT_KINDS = {"target_reached", "back_in_stock"}
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


def _aware(dt: Optional[datetime]) -> Optional[datetime]:
    if dt is None:
        return None
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _iso(dt: Optional[datetime]) -> Optional[str]:
    return _aware(dt).isoformat() if dt else None


def _dec(value: Any) -> Optional[Decimal]:
    if value is None or isinstance(value, bool):
        return None
    try:
        d = Decimal(str(value)).quantize(CENT, rounding=ROUND_HALF_UP)
    except (InvalidOperation, ValueError):
        return None
    return d if d.is_finite() and d > 0 else None


def _significant(before: Decimal, after: Decimal) -> bool:
    delta = abs(after - before)
    return delta >= NOTIFY_MIN_DELTA and delta >= before * NOTIFY_MIN_RATIO


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
            "source": row.source or "user",
            "expires_at": _iso(row.expires_at),
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
            if not same and sum(1 for w in active if w.source != "auto") >= MAX_ACTIVE_WATCHES:
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
            # Une alerte demandée remplace le suivi automatique du même produit (plus d'expiration)
            row.source = "user"
            row.expires_at = None
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
            now = _now()
            return [self.to_public(r) for r in rows
                    if not (r.source == "auto" and r.expires_at and _aware(r.expires_at) < now)]

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
            sub_id = row.subscription_id
            result = self.to_public(row)
        self._release([sub_id])
        return result

    def _release(self, subscription_ids: List[Optional[str]]) -> None:
        """Annule chez Channel3 les abonnements que plus aucune surveillance active n'utilise (ils sont partagés par produit)."""
        for sub_id in {s for s in subscription_ids if s}:
            with Session(engine) as db:
                still_used = db.query(PriceWatchModel).filter(PriceWatchModel.subscription_id == sub_id,
                                                              PriceWatchModel.status == "active").count()
            if still_used:
                continue
            try:
                self._channel3("DELETE", f"/v1/product-subscriptions/{sub_id}")
            except PriceWatchError as e:
                logger.warning(f"[PRICE WATCH] Channel3 unsubscribe failed: {e.code}")

    # ------------------------------------------------------------------
    # Suivi automatique des produits montrés par SIKA
    # ------------------------------------------------------------------

    def auto_follow(self, user_id: int, products: List[Dict[str, Any]]) -> int:
        """Suit les produits montrés à l'utilisateur pendant 30 jours. Ne lève jamais d'exception."""
        with Session(engine) as db:
            user = db.get(UserModel, user_id)
            if not user or not user.auto_follow_products:
                return 0
        followed = 0
        for product in products[:3]:
            if not product.get("product_id") or not product.get("title"):
                continue
            try:
                followed += self._follow(user_id, product)
            except PriceWatchError as e:
                logger.warning(f"[PRICE WATCH] Auto-follow skipped: {e.code}")
        self._evict_auto(user_id)
        return followed

    def _follow(self, user_id: int, product: Dict[str, Any]) -> int:
        now = _now()
        expires = now + timedelta(days=AUTO_FOLLOW_DAYS)
        with Session(engine) as db:
            row = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id,
                                                   PriceWatchModel.product_id == product["product_id"],
                                                   PriceWatchModel.status == "active").first()
            if row:
                if row.source == "auto":
                    row.expires_at = expires  # montré à nouveau : le suivi repart pour 30 jours
                    row.updated_at = now
                    db.commit()
                return 0
        sub = self._channel3("POST", "/v1/product-subscriptions",
                             {"product_id": product["product_id"], "events": WATCH_EVENTS})
        best = product.get("best_offer") or {}
        with Session(engine) as db:
            db.add(PriceWatchModel(
                user_id=user_id, product_id=product["product_id"], title=product["title"][:200],
                image_url=(product.get("image_url") or "")[:512] or None, target_price=None,
                currency=best.get("currency") or "USD", source="auto", expires_at=expires,
                subscription_id=str(sub.get("subscription_id") or sub.get("id") or "")[:64] or None,
                last_price=best.get("price"), last_merchant=best.get("merchant"),
                created_at=now, updated_at=now,
            ))
            db.commit()
        return 1

    def _evict_auto(self, user_id: int) -> None:
        now = _now()
        released = []
        with Session(engine) as db:
            rows = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id, PriceWatchModel.source == "auto",
                                                    PriceWatchModel.status == "active") \
                .order_by(PriceWatchModel.updated_at.desc(), PriceWatchModel.id.desc()).all()
            for i, row in enumerate(rows):
                if i >= MAX_AUTO_WATCHES or (row.expires_at and _aware(row.expires_at) < now):
                    row.status = "cancelled"
                    row.updated_at = now
                    released.append(row.subscription_id)
            db.commit()
        self._release(released)

    def stop_auto_follow(self, user_id: int) -> None:
        released = []
        with Session(engine) as db:
            rows = db.query(PriceWatchModel).filter(PriceWatchModel.user_id == user_id, PriceWatchModel.source == "auto",
                                                    PriceWatchModel.status == "active").all()
            for row in rows:
                row.status = "cancelled"
                row.updated_at = _now()
                released.append(row.subscription_id)
            db.commit()
        self._release(released)

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
        price = previous = availability = previous_availability = None
        condition = "new"
        if event_type == "price.changed":
            # Format à plat : canonical_product_id, domain, old_price, new_price, currency, buy_url
            product_id = str(event.get("canonical_product_id") or "")
            merchant = str(event.get("domain") or "")[:120] or None
            price, previous = _dec(event.get("new_price")), _dec(event.get("old_price"))
        elif event_type == "offer.price.changed":
            price = _dec((data.get("current") or {}).get("price"))
            previous = _dec((data.get("previous") or {}).get("price"))
        elif event_type == "offer.availability.changed":
            availability, previous_availability = data.get("current"), data.get("previous")
        elif event_type in ("offer.created", "offer.deleted"):
            offer = data.get("offer") or {}
            merchant = str(offer.get("domain") or merchant or "")[:120] or None
            price = _dec((offer.get("price") or {}).get("price"))
            availability = offer.get("availability")
            condition = offer.get("condition") or "new"
        else:
            return self._finish(event_id, "IGNORED_EVENT_TYPE")

        triggered = 0
        created: List[UserNotificationModel] = []
        expired: List[Optional[str]] = []
        now = _now()
        with Session(engine) as db:
            rows = db.query(PriceWatchModel).filter(PriceWatchModel.product_id == product_id,
                                                    PriceWatchModel.status == "active").all()
            for row in rows:
                if row.source == "auto" and row.expires_at and _aware(row.expires_at) < now:
                    row.status = "cancelled"  # suivi automatique terminé : plus de notification
                    row.updated_at = now
                    expired.append(row.subscription_id)
                    continue
                row.last_event = event_type
                row.updated_at = now
                change = self._change(row, event_type, merchant, price, previous, availability,
                                      previous_availability, condition)
                # Alerte demandée par l'utilisateur : prix cible atteint, ou retour en stock sans prix cible
                hit = False
                if row.source != "auto" and condition in (None, "new") and event_type != "offer.deleted":
                    if row.target_price and price is not None and availability != "OutOfStock":
                        hit = price <= Decimal(row.target_price)
                    elif not row.target_price and availability == "InStock":
                        hit = True
                if hit:
                    row.status = "triggered"
                    row.triggered_at = now
                    row.last_merchant = merchant
                    if price is not None:
                        row.last_price = str(price)
                    triggered += 1
                    change = ("target_reached" if row.target_price else "back_in_stock",
                              price or _dec(row.last_price), None)
                if change and (change[0] in URGENT_KINDS or not row.last_notified_at
                               or now - _aware(row.last_notified_at) >= NOTIFY_COOLDOWN):
                    kind, amount, before = change
                    note = UserNotificationModel(
                        user_id=row.user_id, kind=kind, product_id=row.product_id, title=row.title,
                        merchant=merchant, price=str(amount) if amount else None,
                        previous_price=str(before) if before else None, currency=row.currency,
                        image_url=row.image_url, created_at=now)
                    db.add(note)
                    created.append(note)
                    row.last_notified_at = now
            db.commit()
            notification_ids = [n.id for n in created]
        self._release(expired)
        if notification_ids:
            from .notification_service import notification_service
            notification_service.deliver(notification_ids)
        outcome = f"MATCHED_{len(rows)}_TRIGGERED_{triggered}" if rows else "NO_WATCH"
        return self._finish(event_id, f"{outcome}_NOTIFIED_{len(notification_ids)}" if rows else outcome)

    @staticmethod
    def _change(row: PriceWatchModel, event_type: str, merchant: Optional[str], price: Optional[Decimal],
                previous: Optional[Decimal], availability: Any, previous_availability: Any,
                condition: Optional[str]):
        """Met à jour le meilleur prix connu et retourne (type, prix, prix précédent) si le changement compte pour l'utilisateur."""
        best = _dec(row.last_price)
        best_merchant = row.last_merchant
        if condition not in (None, "new"):
            return None  # occasion ou reconditionné : hors comparaison
        if event_type in ("offer.price.changed", "price.changed"):
            if price is None:
                return None
            if best is None or merchant == best_merchant:
                # Le marchand le moins cher change son prix
                row.last_price, row.last_merchant = str(price), merchant
                before = previous or best
                if before is None or not _significant(before, price):
                    return None
                return ("price_drop" if price < before else "price_rise", price, before)
            if price < best:
                # Un autre marchand devient le moins cher
                row.last_price, row.last_merchant = str(price), merchant
                return ("price_drop", price, best) if _significant(best, price) else None
            return None  # hausse ou baisse chez un marchand plus cher : sans effet pour l'utilisateur
        if event_type == "offer.availability.changed":
            if previous_availability == "OutOfStock" and availability == "InStock":
                return ("back_in_stock", best if merchant == best_merchant else None, None)
            if availability == "OutOfStock" and merchant == best_merchant:
                return ("out_of_stock", best, None)
            return None
        if event_type == "offer.created":
            if price is None or availability == "OutOfStock":
                return None
            if best is None or price < best:
                row.last_price, row.last_merchant = str(price), merchant
                return ("new_offer", price, best) if best is not None and _significant(best, price) else None
            return None
        if event_type == "offer.deleted" and merchant and merchant == best_merchant:
            return ("offer_removed", best, None)
        return None

    @staticmethod
    def _finish(event_id: str, outcome: str) -> str:
        with Session(engine) as db:
            row = db.get(ShoppingWebhookEventModel, event_id)
            if row:
                row.outcome = outcome[:80]
                db.commit()
        return outcome


price_watch_service = PriceWatchService()
