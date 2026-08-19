"""
SQLAlchemy Session Factory & FastAPI get_db dependency.
"""

# pyrefly: ignore [missing-import]
from sqlalchemy.orm import sessionmaker
from .connection import engine

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    """Dépendance FastAPI pour obtenir une session de base de données."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
