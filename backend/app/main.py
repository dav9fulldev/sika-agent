# pyrefly: ignore [missing-import]
from fastapi import FastAPI
# pyrefly: ignore [missing-import]
from fastapi.middleware.cors import CORSMiddleware
from app.routes.sika_router import router as sika_router

"""
Point d'entrée principal de l'API SIKA AI Standalone.
"""

app = FastAPI(
    title="SIKA AI API",
    description="Microservice indépendant pour l'Assistant Vocal et Financier SIKA",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(sika_router)

@app.get("/")
def read_root():
    return {
        "message": "Bienvenue sur l'API SIKA Assistant Vocal",
        "version": "1.0.0",
        "status": "running"
    }

if __name__ == "__main__":
    # pyrefly: ignore [missing-import]
    import uvicorn
    import os
    port = int(os.getenv("PORT", 8080))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
