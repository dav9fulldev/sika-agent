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

# URL par défaut: Cloud SQL Proxy local (127.0.0.1:5433) ou variable DATABASE_URL
DEFAULT_CLOUD_SQL_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://sika_user:SikaSecurePassword2026!@127.0.0.1:5433/sika_db"
)
DEFAULT_SQLITE_URL = "sqlite:////Users/mac/Desktop/SIKA/backend/sika_local.db"
DATABASE_URL = DEFAULT_CLOUD_SQL_URL

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {"connect_timeout": 3}

try:
    engine = create_engine(
        DATABASE_URL,
        connect_args=connect_args,
        echo=False,
        pool_pre_ping=True,
    )
    # Test immédiat de la connexion SQL
    with engine.connect() as conn:
        pass
except Exception:
    # Si Cloud SQL nécessite cloud-sql-proxy ou n'est pas encore joignable, fallback transparent sur SQLite local
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
