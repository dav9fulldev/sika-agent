"""
Financial Repository — Accès à la Base de Données SIKA
Gère l'Identité, les Références de Wallets Connectés, les Préférences et la Mémoire Agent.
"""

from typing import List, Dict, Any, Optional
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Session
from datetime import datetime
from ..database import SessionLocal, Base, engine
from ..models import (
    UserModel,
    ConnectedWalletModel,
    UserPreferenceModel,
    SavingsGoalModel,
    AgentMemoryModel,
)

class FinancialRepository:
    """Gère les opérations de lecture et d'écriture SQL sur la base de données SIKA."""

    def __init__(self):
        # Initialise automatiquement les tables au premier démarrage
        try:
            Base.metadata.create_all(bind=engine)
        except Exception as e:
            print(f"[DB INIT] Notice during table creation: {e}")

    def get_wallets(self, user_id: Any = None) -> List[Dict[str, Any]]:
        """Récupère les portefeuilles connectés depuis la base de données SQL pour un utilisateur."""
        db: Session = SessionLocal()
        try:
            query = db.query(ConnectedWalletModel)
            if user_id is not None:
                query = query.filter(ConnectedWalletModel.user_id == user_id)
            wallets = query.all()
            return [
                {
                    "id": f"w_{w.id}",
                    "provider": w.provider,
                    "external_wallet_id": w.external_wallet_id,
                    "status": w.connection_status,
                    "currency": "XOF",
                }
                for w in wallets
            ]
        finally:
            db.close()

# Instance globale
financial_repository = FinancialRepository()
