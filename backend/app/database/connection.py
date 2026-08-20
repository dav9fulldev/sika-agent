"""
Database Connection & Engine Management for SIKA AI Backend.
Supports PostgreSQL (Cloud SQL) and SQLite (Development Fallback).
"""

import os
import logging
from pathlib import Path
from dotenv import load_dotenv

# Charger les variables d'environnement depuis le fichier .env
env_path = Path(__file__).resolve().parent.parent.parent / ".env"
load_dotenv(env_path)

# pyrefly: ignore [missing-import]
from sqlalchemy import create_engine

logger = logging.getLogger("SikaDatabase")

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
    
    if not DATABASE_URL.startswith("sqlite"):
        print("[DB WARNING] ⚠️ Basculement temporaire sur SQLite local (sika_local.db) suite à l'erreur PostgreSQL.")
        engine = create_engine(
            DEFAULT_SQLITE_URL,
            connect_args={"check_same_thread": False},
            echo=False
        )
