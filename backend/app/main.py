# pyrefly: ignore [missing-import]
from fastapi import FastAPI
# pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware
from app.routes.sika_router import router as sika_router
from app.routes.wallet_router import router as wallet_router
from app.routes.perception_router import router as perception_router
from app.database import Base, engine
from app.repositories.financial_repository import financial_repository

"""
Point d'entrée principal de l'API SIKA AI Standalone.
"""

# Initialisation des tables SQL au démarrage
Base.metadata.create_all(bind=engine)
try:
    from sqlalchemy import text
    with engine.connect() as conn:
        conn.execute(text("ALTER TABLE sika_actions ADD COLUMN idempotency_key VARCHAR(100)"))
        conn.commit()
except Exception:
    pass

import os

app = FastAPI(
    title="SIKA AI API",
    description="Microservice indépendant pour l'Assistant Vocal et Financier SIKA",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

cors_origins_env = os.getenv("CORS_ALLOWED_ORIGINS", "*")
allowed_origins = [o.strip() for o in cors_origins_env.split(",") if o.strip()]
is_wildcard = "*" in allowed_origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=not is_wildcard,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

@app.middleware("http")
async def add_security_headers(request, call_next):
    """En-têtes de sécurité HTTP OWASP contre Clickjacking, XSS, MitM et fuites de données."""
    response = await call_next(request)
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

app.include_router(sika_router)
app.include_router(wallet_router)
app.include_router(perception_router)

@app.get("/")
def read_root():
    return {
        "message": "Bienvenue sur l'API SIKA Assistant Vocal",
        "version": "1.0.0",
        "database": "SQL Database Connected",
        "status": "running"
    }

if __name__ == "__main__":
    # pyrefly: ignore [missing-import]
    import uvicorn
    import os
    port = int(os.getenv("PORT", 8001))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
