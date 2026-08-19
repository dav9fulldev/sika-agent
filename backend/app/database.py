"""
Database Connection & Session Management for SIKA AI Backend

Supports Google Cloud SQL (PostgreSQL Production) and SQLite (Local Development Fallback).
"""

import os
import logging
# pyrefly: ignore [missing-import]
from sqlalchemy import create_engine
# pyrefly: ignore [missing-import]
from sqlalchemy.ext.declarative import declarative_base
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import sessionmaker

logger = logging.getLogger("SikaDatabase")

# Variable d'environnement DATABASE_URL (chargee depuis backend/.env ou environnement)
DEFAULT_SQLITE_URL = "sqlite:////Users/mac/Desktop/SIKA/backend/sika_local.db"
DATABASE_URL = os.getenv("DATABASE_URL", DEFAULT_SQLITE_URL)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {"connect_timeout": 5}

try:
    engine = create_engine(
        DATABASE_URL,
        connect_args=connect_args,
        echo=False,
        pool_pre_ping=True,
    )
    # Test actif de connexion au démarrage
    with engine.connect() as conn:
        dialect_name = engine.dialect.name
        if dialect_name == "postgresql":
            target_info = DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL
            print(f"[DB ENGINE] 🐘 ✅ CONNECTÉ AVEC SUCCÈS À POSTGRESQL CLOUD SQL ({target_info})")
            logger.info("Connected successfully to PostgreSQL Cloud SQL")
        else:
            print(f"[DB ENGINE] 📁 CONNECTÉ À SQLITE LOCAL ({DATABASE_URL})")
            logger.info("Connected to local SQLite database")
except Exception as e:
    print(f"[DB ERROR] ❌ ÉCHEC DE CONNEXION POSTGRESQL/CLOUD SQL ({DATABASE_URL}): {e}")
    logger.error(f"Failed to connect to database URL {DATABASE_URL}: {e}")
    
    # Fallback explicite vers SQLite avec avertissement visible
    if not DATABASE_URL.startswith("sqlite"):
        print("[DB WARNING] ⚠️ Basculement temporaire sur SQLite local (sika_local.db) suite à l'erreur PostgreSQL.")
        engine = create_engine(
            DEFAULT_SQLITE_URL,
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
