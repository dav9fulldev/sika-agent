"""
SIKA Pay — Tableau de bord web (AG Studio), en lecture seule.

- POST /code : l'app (jeton normal) obtient un code à usage unique à saisir dans le navigateur.
- POST /session : le navigateur échange ce code contre un jeton limité au tableau de bord.
- GET /config, GET /data, POST /llm : acceptent ce jeton limité (ou un jeton normal) ;
  aucune autre route de l'API ne l'accepte.
"""

from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

from ..config import settings
from ..services.auth_service import oauth2_auth_service
from ..services.dashboard_service import dashboard_service, DashboardError
from ..services import dashboard_llm

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])

MAX_LLM_BODY_BYTES = 2_000_000


class SessionRequest(BaseModel):
    code: str = Field(..., min_length=4, max_length=20)


class LlmRequest(BaseModel):
    input: List[Dict[str, Any]]
    instructions: Optional[str] = Field(None, max_length=200_000)
    tools: Optional[List[Dict[str, Any]]] = None
    toolChoice: Optional[Any] = None
    responseFormat: Optional[Dict[str, Any]] = None
    model: Optional[Dict[str, Any]] = None


def _raise(err: DashboardError):
    raise HTTPException(status_code=err.http_status, detail=err.to_dict())


@router.post("/code", summary="Get a single-use code to open the web dashboard")
def create_code(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization)
    return {**dashboard_service.create_code(user_id), "url": f"{settings.PUBLIC_BASE_URL}/dashboard/"}


@router.post("/session", summary="Exchange a dashboard code for a read-only session")
def create_session(data: SessionRequest, request: Request):
    client_ip = request.client.host if request.client else "unknown"
    try:
        return dashboard_service.exchange_code(data.code, client_ip=client_ip)
    except DashboardError as e:
        _raise(e)


@router.get("/config", summary="Dashboard configuration")
def get_config(authorization: Optional[str] = Header(None)):
    oauth2_auth_service.require_authenticated_user_id(authorization, allow_dashboard=True)
    # Une clé de licence AG Studio est utilisée dans le navigateur : elle n'est pas secrète, seulement hors du dépôt
    return {"ag_studio_license": settings.AG_STUDIO_LICENSE or "", "ai_enabled": True}


@router.get("/data", summary="My payments, followed products and alerts, for the dashboard")
def get_data(authorization: Optional[str] = Header(None)):
    user_id = oauth2_auth_service.require_authenticated_user_id(authorization, allow_dashboard=True)
    return dashboard_service.data(user_id)


@router.post("/llm", summary="One AG Studio agent turn, answered by Gemini")
async def llm_turn(data: LlmRequest, request: Request, authorization: Optional[str] = Header(None)):
    oauth2_auth_service.require_authenticated_user_id(authorization, allow_dashboard=True)
    if int(request.headers.get("content-length") or 0) > MAX_LLM_BODY_BYTES:
        raise HTTPException(status_code=413, detail="Request too large.")
    return await dashboard_llm.execute_turn(data.model_dump())
