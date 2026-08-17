"""
Database Connection & Session Management for SIKA AI Backend

Supports PostgreSQL (Production) and SQLite (Local Development Fallback).
"""

import os
# pyrefly: ignore [missing-import]
from sqlalchemy import create_engine
# pyrefly: ignore [missing-import]
from sqlalchemy.ext.declarative import declarative_base
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import sessionmaker

# URL par défaut: SQLite local ou PostgreSQL via variable d'environnement DATABASE_URL
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite:////Users/mac/Desktop/SIKA/backend/sika_local.db"
)

# Configuration engine pour SQLite et PostgreSQL
connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(
    DATABASE_URL,
    connect_args=connect_args,
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
