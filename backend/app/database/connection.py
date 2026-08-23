"""
Database Connection & Engine Management for SIKA AI Backend.
Supports PostgreSQL (Cloud SQL) and SQLite (Development Fallback).
"""

import logging
from sqlalchemy import create_engine
from app.config import settings

logger = logging.getLogger("SikaDatabase")

DATABASE_URL = settings.DATABASE_URL

if DATABASE_URL.startswith("sqlite"):
    connect_args = {"check_same_thread": False}
    engine = create_engine(
        DATABASE_URL,
        connect_args=connect_args,
        echo=False,
        pool_pre_ping=True
    )
else:
    connect_args = {"connect_timeout": 10}
    try:
        engine = create_engine(
            DATABASE_URL,
            connect_args=connect_args,
            echo=False,
            pool_pre_ping=True,
            pool_recycle=1800,
            pool_size=10,
            max_overflow=20
        )
        with engine.connect() as conn:
            target_info = DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else DATABASE_URL
            print(f"[DB ENGINE] 🐘 ✅ CONNECTÉ AVEC SUCCÈS À POSTGRESQL CLOUD SQL ({target_info})")
            logger.info(f"Connected successfully to PostgreSQL Cloud SQL ({target_info})")
    except Exception as e:
        print(f"[DB ERROR] ❌ ÉCHEC DE CONNEXION POSTGRESQL/CLOUD SQL: {e}")
        logger.error(f"Failed to connect to PostgreSQL database: {e}")

        # En production, aucun fallback silencieux vers SQLite n'est autorisé
        if settings.ENV in ["production", "prod"]:
            raise RuntimeError(
                f"[SECURITY FATAL] Impossible d'établir la connexion avec la base de données PostgreSQL en production: {e}"
            ) from e

        # En développement local uniquement : fallback SQLite pour le confort de dev
        print("[DB WARNING] ⚠️ Basculement temporaire sur SQLite local (dev) suite à l'erreur PostgreSQL.")
        engine = create_engine(
            "sqlite:///sika_local.db",
            connect_args={"check_same_thread": False},
            echo=False
        )

