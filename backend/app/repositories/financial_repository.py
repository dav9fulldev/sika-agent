"""
Financial Repository — Accès à la Base de Données SIKA
Gère l'Identité, les Références de Wallets Connectés, les Préférences et la Mémoire Agent.
"""

from typing import List, Dict, Any, Optional
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Session
from datetime import datetime
from ..database import SessionLocal, Base, engine
from ..models.db_models import (
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
            self._seed_initial_data_if_empty()
        except Exception as e:
            print(f"[DB INIT] Notice during table creation: {e}")

    def _seed_initial_data_if_empty(self):
        """Initialise la base de données avec l'utilisateur David YAO et ses références de wallets."""
        db: Session = SessionLocal()
        try:
            wallets_count = db.query(ConnectedWalletModel).count()
            if wallets_count == 0:
                user = db.query(UserModel).filter(UserModel.email == "david.yao@email.com").first()
                if not user:
                    user = UserModel(
                        full_name="David YAO",
                        email="david.yao@email.com",
                        auth_provider="email",
                    )
                    db.add(user)
                    db.commit()
                    db.refresh(user)

                # Connexions de Wallets (Wave, Orange Money, MTN MoMo)
                w1 = ConnectedWalletModel(user_id=user.id, provider="Wave", external_wallet_id="0799053977")
                w2 = ConnectedWalletModel(user_id=user.id, provider="Orange Money", external_wallet_id="0701020304")
                w3 = ConnectedWalletModel(user_id=user.id, provider="MTN MoMo", external_wallet_id="0501020304")
                db.add_all([w1, w2, w3])

                # Préférences utilisateur
                pref = UserPreferenceModel(user_id=user.id, preferred_currency="XOF", preferred_language="fr", monthly_budget=150000.0)
                db.add(pref)

                # Objectif d'épargne
                goal = SavingsGoalModel(user_id=user.id, title="Épargne de précaution", target_amount=80000.0, current_amount=48000.0)
                db.add(goal)

                # Mémoire initiale de l'agent SIKA
                mem1 = AgentMemoryModel(user_id=user.id, memory_type="long_term", key="spending_habit", value="Dépenses plus élevées en fin de semaine")
                mem2 = AgentMemoryModel(user_id=user.id, memory_type="preference", key="primary_wallet", value="Wave")
                db.add_all([mem1, mem2])

                db.commit()
                print("[DB SEED] ✅ Base de données SIKA initialisée avec succès pour David YAO !")
        except Exception as e:
            db.rollback()
            print(f"[DB SEED] Error seeding data: {e}")
        finally:
            db.close()

    def get_wallets(self, user_id: Any = None) -> List[Dict[str, Any]]:
        """Récupère les portefeuilles connectés depuis la base de données SQL."""
        db: Session = SessionLocal()
        try:
            wallets = db.query(ConnectedWalletModel).all()
            if not wallets:
                self._seed_initial_data_if_empty()
                db_fresh: Session = SessionLocal()
                try:
                    wallets = db_fresh.query(ConnectedWalletModel).all()
                finally:
                    db_fresh.close()

            return [
                {
                    "id": f"w_{w.id}",
                    "provider": w.provider,
                    "external_wallet_id": w.external_wallet_id,
                    "status": w.connection_status,
                    "balance": 1858000.0 if w.provider == "Wave" else (15000.0 if w.provider == "Orange Money" else 8000.0),
                    "currency": "XOF",
                }
                for w in wallets
            ]
        finally:
            db.close()

    def get_recent_transactions(self, limit: int = 5) -> List[Dict[str, Any]]:
        """Retourne la structure récente (les transactions réelles sont interrogées via PayMeChap API)."""
        return [
            {"id": "tx_1", "type": "payment", "amount": 4500.0, "category": "Restauration", "recipient": "Fast Food Abidjan", "timestamp": datetime.utcnow().isoformat()},
            {"id": "tx_2", "type": "transfer", "amount": 10000.0, "category": "Famille", "recipient": "Transfert Proche", "timestamp": datetime.utcnow().isoformat()},
        ]

# Instance globale
financial_repository = FinancialRepository()
