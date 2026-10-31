"""
SIKA Pay — Notifications de changements sur les produits suivis.

Chaque changement utile (baisse ou hausse de prix, retour en stock, rupture, nouveau marchand moins cher,
offre retirée, prix cible atteint) est enregistré pour l'utilisateur et affiché dans l'app. Si un téléphone
est enregistré, une notification push est aussi envoyée, sauf la nuit (22 h – 7 h, heure du téléphone).
"""

import hashlib
import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from sqlalchemy.orm import Session

from ..database import engine
from ..models.price_watch import PushDeviceModel, UserNotificationModel
from ..models.user import UserModel
from .push_service import push_service

logger = logging.getLogger("SikaNotifications")

QUIET_HOURS = (22, 7)  # pas de push entre 22 h et 7 h, heure locale du téléphone
MAX_DEVICES_PER_USER = 5

# Texte des notifications push, dans la langue du téléphone (l'app affiche son propre texte traduit)
_TEXTS = {
    "en": {
        "target_reached": ("Target price reached", "{title} is now {price} at {merchant}."),
        "price_drop": ("Price drop", "{title} is now {price} at {merchant} (was {previous})."),
        "price_rise": ("Price increase", "{title} went up to {price} at {merchant} (was {previous})."),
        "back_in_stock": ("Back in stock", "{title} is available again at {merchant}."),
        "out_of_stock": ("Out of stock", "{title} is no longer available at {merchant}."),
        "new_offer": ("Cheaper offer", "{merchant} now sells {title} for {price} (best was {previous})."),
        "offer_removed": ("Offer removed", "{merchant} no longer sells {title}."),
    },
    "fr": {
        "target_reached": ("Prix cible atteint", "{title} est maintenant à {price} chez {merchant}."),
        "price_drop": ("Baisse de prix", "{title} est maintenant à {price} chez {merchant} (avant : {previous})."),
        "price_rise": ("Hausse de prix", "{title} est passé à {price} chez {merchant} (avant : {previous})."),
        "back_in_stock": ("De retour en stock", "{title} est de nouveau disponible chez {merchant}."),
        "out_of_stock": ("En rupture de stock", "{title} n'est plus disponible chez {merchant}."),
        "new_offer": ("Offre moins chère", "{merchant} vend maintenant {title} à {price} (meilleur prix : {previous})."),
        "offer_removed": ("Offre retirée", "{merchant} ne vend plus {title}."),
    },
}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    return (dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)).isoformat()


def _money(amount: Optional[str], currency: Optional[str]) -> str:
    if not amount:
        return ""
    return f"{amount} {currency or 'USD'}"


def push_text(row: UserNotificationModel, language: str) -> tuple:
    title, body = _TEXTS.get(language, _TEXTS["en"])[row.kind]
    merchant = row.merchant or ("un marchand" if language == "fr" else "a merchant")
    return title, body.format(title=row.title, merchant=merchant, price=_money(row.price, row.currency),
                              previous=_money(row.previous_price, row.currency))


def is_quiet_hour(tz_offset_minutes: int, now: Optional[datetime] = None) -> bool:
    local = (now or _now()) + timedelta(minutes=tz_offset_minutes)
    start, end = QUIET_HOURS
    return local.hour >= start or local.hour < end


class NotificationService:
    @staticmethod
    def to_public(row: UserNotificationModel) -> Dict[str, Any]:
        return {
            "id": row.id,
            "kind": row.kind,
            "product_id": row.product_id,
            "title": row.title,
            "merchant": row.merchant,
            "price": row.price,
            "previous_price": row.previous_price,
            "currency": row.currency,
            "image_url": row.image_url,
            "read": row.read_at is not None,
            "created_at": _iso(row.created_at),
        }

    def list(self, user_id: int, limit: int = 50) -> Dict[str, Any]:
        with Session(engine) as db:
            rows = db.query(UserNotificationModel).filter(UserNotificationModel.user_id == user_id) \
                .order_by(UserNotificationModel.created_at.desc(), UserNotificationModel.id.desc()).limit(limit).all()
            unread = db.query(UserNotificationModel).filter(UserNotificationModel.user_id == user_id,
                                                            UserNotificationModel.read_at.is_(None)).count()
            return {"notifications": [self.to_public(r) for r in rows], "unread": unread}

    def mark_read(self, user_id: int) -> None:
        with Session(engine) as db:
            db.query(UserNotificationModel).filter(UserNotificationModel.user_id == user_id,
                                                   UserNotificationModel.read_at.is_(None)) \
                .update({"read_at": _now()}, synchronize_session=False)
            db.commit()

    # ------------------------------------------------------------------
    # Appareils (jetons FCM)
    # ------------------------------------------------------------------

    @staticmethod
    def _hash(token: str) -> str:
        return hashlib.sha256(token.encode()).hexdigest()

    def register_device(self, user_id: int, token: str, platform: str = "android", language: str = "en",
                        tz_offset_minutes: int = 0) -> None:
        token_hash = self._hash(token)
        with Session(engine) as db:
            # Un jeton appartient au dernier compte connecté sur ce téléphone
            row = db.query(PushDeviceModel).filter(PushDeviceModel.token_hash == token_hash).first()
            if not row:
                row = PushDeviceModel(token=token, token_hash=token_hash)
                db.add(row)
            row.user_id = user_id
            row.platform = platform
            row.language = "fr" if language == "fr" else "en"
            row.tz_offset_minutes = max(-14 * 60, min(14 * 60, int(tz_offset_minutes)))
            row.updated_at = _now()
            db.commit()
            # On garde les appareils les plus récents seulement
            stale = db.query(PushDeviceModel).filter(PushDeviceModel.user_id == user_id) \
                .order_by(PushDeviceModel.updated_at.desc()).offset(MAX_DEVICES_PER_USER).all()
            for old in stale:
                db.delete(old)
            db.commit()

    def unregister_device(self, user_id: int, token: str) -> None:
        with Session(engine) as db:
            db.query(PushDeviceModel).filter(PushDeviceModel.user_id == user_id,
                                             PushDeviceModel.token_hash == self._hash(token)).delete()
            db.commit()

    # ------------------------------------------------------------------
    # Préférences
    # ------------------------------------------------------------------

    def preferences(self, user_id: int) -> Dict[str, Any]:
        with Session(engine) as db:
            user = db.get(UserModel, user_id)
            return {"auto_follow_products": bool(user.auto_follow_products) if user else True}

    def set_preferences(self, user_id: int, auto_follow_products: bool) -> Dict[str, Any]:
        with Session(engine) as db:
            user = db.get(UserModel, user_id)
            if user:
                user.auto_follow_products = bool(auto_follow_products)
                db.commit()
        if not auto_follow_products:
            from .price_watch_service import price_watch_service
            price_watch_service.stop_auto_follow(user_id)
        return self.preferences(user_id)

    # ------------------------------------------------------------------
    # Envoi
    # ------------------------------------------------------------------

    def deliver(self, notification_ids: List[int], now: Optional[datetime] = None) -> int:
        """Envoie en push les notifications créées ; retourne le nombre de messages envoyés."""
        if not notification_ids or not push_service.enabled():
            return 0
        sent = 0
        with Session(engine) as db:
            rows = db.query(UserNotificationModel).filter(UserNotificationModel.id.in_(notification_ids)).all()
            for row in rows:
                devices = db.query(PushDeviceModel).filter(PushDeviceModel.user_id == row.user_id).all()
                for device in devices:
                    if is_quiet_hour(device.tz_offset_minutes, now):
                        continue
                    title, body = push_text(row, device.language)
                    outcome = push_service.send(device.token, title, body,
                                                {"type": "product_alert", "notification_id": row.id, "kind": row.kind})
                    if outcome == "SENT":
                        sent += 1
                    elif outcome == "INVALID_TOKEN":
                        db.delete(device)
            db.commit()
        return sent


notification_service = NotificationService()
