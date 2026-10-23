import os
import uuid
import logging
from fastapi import FastAPI, Request, HTTPException, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.exc import SQLAlchemyError

from app.config import settings, APP_VERSION
from app.services.logging_sanitizer import setup_secure_logging
from app.routes.sika_router import router as sika_router
from app.routes.perception_router import router as perception_router
from app.routes.user_router import router as user_router
from app.routes.paypal_router import router as paypal_router
from app.database import Base, engine
from app import models as _all_models  # noqa: F401  (enregistre toutes les tables avant create_all)

"""
Point d'entrée principal de l'API SIKA AI Standalone.
Sécurisé pour les environnements de développement et de production bancaire.
"""

from contextlib import asynccontextmanager

logger = logging.getLogger("SikaAPI")
setup_secure_logging()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Cycle de vie FastAPI : initialisation propre sans bloquer l'importation de l'application."""
    if settings.ENV not in ["production", "prod"]:
        try:
            Base.metadata.create_all(bind=engine)
        except Exception as e:
            logger.warning(f"[DB INIT DEV] Notification lors de l'initialisation locale des tables: {e}")
    yield


# Configuration conditionnelle de la documentation Swagger / OpenAPI
docs_url = "/docs" if settings.DOCS_ENABLED else None
redoc_url = "/redoc" if settings.DOCS_ENABLED else None
openapi_url = "/openapi.json" if settings.DOCS_ENABLED else None

app = FastAPI(
    title="SIKA AI API",
    description="SIKA Pay — AI payment agent API (PayPal Orders v2 sandbox + Gemini)",
    version=APP_VERSION,
    docs_url=docs_url,
    redoc_url=redoc_url,
    openapi_url=openapi_url,
    lifespan=lifespan
)

# Configuration CORS sécurisée
cors_origins = settings.ALLOWED_ORIGINS
is_wildcard = "*" in cors_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=not is_wildcard,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)


@app.middleware("http")
async def security_and_tracing_middleware(request: Request, call_next):
    """
    Middleware de traçabilité (X-Request-ID), de limitation de payload (1MB)
    et d'application des en-têtes de sécurité HTTP OWASP.
    """
    # 1. Traçabilité distribuée avec X-Request-ID
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    request.state.request_id = request_id

    # 2. Protection DoS : Limitation stricte de la taille du payload (1 Mo max)
    content_length = request.headers.get("content-length")
    if content_length and int(content_length) > settings.MAX_REQUEST_BODY_SIZE:
        logger.warning(f"[DOS ALERT] Rejet de requête volumineuse ({content_length} octets) - RequestID: {request_id}")
        return JSONResponse(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            content={
                "detail": "Payload trop volumineux. La taille maximale autorisée est de 1 Mo.",
                "error_code": "PAYLOAD_TOO_LARGE",
                "request_id": request_id
            },
            headers={"X-Request-ID": request_id}
        )

    # 3. Exécution de la requête
    response = await call_next(request)

    # 4. Ajout des en-têtes de sécurité HTTP OWASP
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    response.headers["Content-Security-Policy"] = (
        "default-src 'self' https://cdn.jsdelivr.net; "
        "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
        "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
        "img-src 'self' data: https:; "
        "font-src 'self' data: https://cdn.jsdelivr.net;"
    )

    return response


# =============================================================================
# GESTIONNAIRES D'EXCEPTIONS SÉCURISÉS (ANTI-INFORMATION DISCLOSURE)
# =============================================================================

@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request: Request, exc: SQLAlchemyError):
    """Intercepte les erreurs SQL et masque les requêtes / schémas internes."""
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    logger.error(f"[DB ERROR] [RequestID: {request_id}] Erreur base de données: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Une erreur liée à la base de données est survenue.",
            "error_code": "DATABASE_ERROR",
            "request_id": request_id
        },
        headers={"X-Request-ID": request_id}
    )


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, exc: Exception):
    """Intercepte toutes les exceptions non gérées pour éviter la fuite de stacktraces."""
    request_id = getattr(request.state, "request_id", str(uuid.uuid4()))
    logger.critical(f"[UNHANDLED EXCEPTION] [RequestID: {request_id}] {type(exc).__name__}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Une erreur interne inattendue est survenue.",
            "error_code": "INTERNAL_SERVER_ERROR",
            "request_id": request_id
        },
        headers={"X-Request-ID": request_id}
    )


app.include_router(sika_router)
app.include_router(paypal_router)
app.include_router(perception_router)
app.include_router(user_router)


@app.get("/")
def read_root():
    return {
        "message": "Bienvenue sur l'API SIKA Assistant Vocal",
        "version": APP_VERSION,
        "environment": settings.ENV,
        "database": "SQL Database Connected",
        "status": "running"
    }


@app.get("/health")
def health_check():
    """Endpoint de sondage de santé (Liveness/Readiness) pour Docker et Cloud Run."""
    return {
        "status": "healthy",
        "environment": settings.ENV,
        "version": APP_VERSION
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8001))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
