"""
SIKA Pay — Notifications de changements sur les produits suivis, appareils push et préférences.

Toutes les routes exigent un JWT SIKA : chacun ne voit et ne modifie que ses propres notifications.
"""

from typing import Optional

from fastapi import APIRouter, Header
from pydantic import BaseModel, Field

from ..services.auth_service import oauth2_auth_service
from ..services.notification_service import notification_service

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])


class DeviceRequest(BaseModel):
    token: str = Field(..., min_length=20, max_length=4096)
    platform: str = Field("android", pattern="^(android|ios)$")
    language: str = Field("en", pattern="^(en|fr)$")
    tz_offset_minutes: int = Field(0, ge=-14 * 60, le=14 * 60)


class DeviceRemoveRequest(BaseModel):
    token: str = Field(..., min_length=20, max_length=4096)


class PreferencesRequest(BaseModel):
    auto_follow_products: bool


@router.get("", summary="My product alerts and changes")
def list_notifications(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return notification_service.list(user_id)


@router.post("/read", summary="Mark all notifications as read")
def mark_notifications_read(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    notification_service.mark_read(user_id)
    return {"success": True}


@router.post("/devices", summary="Register this phone for push notifications")
def register_device(data: DeviceRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    notification_service.register_device(user_id, data.token, data.platform, data.language, data.tz_offset_minutes)
    return {"success": True}


@router.post("/devices/remove", summary="Stop push notifications on this phone (log out)")
def remove_device(data: DeviceRemoveRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    notification_service.unregister_device(user_id, data.token)
    return {"success": True}


@router.get("/preferences", summary="Notification preferences")
def get_preferences(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return notification_service.preferences(user_id)


@router.put("/preferences", summary="Turn automatic product following on or off")
def set_preferences(data: PreferencesRequest, authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return notification_service.set_preferences(user_id, data.auto_follow_products)
