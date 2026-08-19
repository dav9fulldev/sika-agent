"""
Database Connection & Session Management for SIKA AI Backend

Supports Google Cloud SQL (PostgreSQL Production) and SQLite (Local Development Fallback).
Connection Name Cloud SQL: sika-all-things-agentic:europe-west9:sika-db-instance
"""

import os
# pyrefly: ignore [missing-import]
from sqlalchemy import create_engine
# pyrefly: ignore [missing-import]
from sqlalchemy.ext.declarative import declarative_base
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import sessionmaker

INSTANCE_CONNECTION_NAME = os.getenv(
    "INSTANCE_CONNECTION_NAME",
    "sika-all-things-agentic:europe-west9:sika-db-instance"
)

# URL par défaut: PostgreSQL Cloud SQL ou SQLite local
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    f"postgresql+psycopg2://postgres:SikaSecurePassword2026!@34.155.139.201:5432/sika_db"
)

# Configuration engine pour SQLite et PostgreSQL Cloud SQL
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

try:
    engine = create_engine(
        DATABASE_URL,
        connect_args=connect_args,
        echo=False,
        pool_pre_ping=True,
    )
except Exception:
    # Fallback sécurisé sur SQLite si la connexion distante n'est pas joignable sans proxy
    FALLBACK_URL = "sqlite:////Users/mac/Desktop/SIKA/backend/sika_local.db"
    engine = create_engine(
        FALLBACK_URL,
        connect_args={"check_same_thread": False},
        echo=False
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    """Dépendance FastAPI pour obtenir une session de base de données."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
