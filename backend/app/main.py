from fastapi import FastAPI
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
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
