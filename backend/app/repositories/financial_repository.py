"""
Financial Repository — Accès aux Données SQL Réelles pour SIKA
"""

from typing import List, Dict, Any, Optional
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Session
from datetime import datetime
from ..database import SessionLocal, Base, engine
from ..models.db_models import (
    UserModel,
    WalletModel,
    TransactionModel,
    SavingsGoalModel,
    UserHabitModel,
    MemorySnapshotModel,
)

class FinancialRepository:
    """Gère les opérations de lecture et d'écriture SQL sur la base de données."""

    def __init__(self):
        # Initialise automatiquement les tables au premier démarrage
        try:
            Base.metadata.create_all(bind=engine)
            self._seed_initial_data_if_empty()
        except Exception as e:
            print(f"[DB INIT] Notice during table creation: {e}")

    def _seed_initial_data_if_empty(self):
        """Initialise la base de données avec l'utilisateur David YAO et ses 3 portefeuilles s'ils sont vides."""
        db: Session = SessionLocal()
        try:
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

                # 3 Portefeuilles réels (Wave, Orange Money, MTN MoMo)
                w1 = WalletModel(id="w_wave", user_id=user.id, provider="Wave", balance=15000.0, currency="XOF")
                w2 = WalletModel(id="w_om", user_id=user.id, provider="Orange Money", balance=22000.0, currency="XOF")
                w3 = WalletModel(id="w_mtn", user_id=user.id, provider="MTN MoMo", balance=8000.0, currency="XOF")
                db.add_all([w1, w2, w3])

                # Dépenses initiales
                t1 = TransactionModel(id="tx_1", wallet_id="w_wave", type="payment", amount=4500.0, category="Restauration", recipient="L'Abidjanaise Fast Food")
                t2 = TransactionModel(id="tx_2", wallet_id="w_om", type="transfer", amount=10000.0, category="Famille", recipient="Maman Kouamé")
                t3 = TransactionModel(id="tx_3", wallet_id="w_wave", type="payment", amount=2000.0, category="Transport", recipient="Yango Ride")
                db.add_all([t1, t2, t3])

                # Objectif d'épargne
                goal = SavingsGoalModel(id="goal_1", user_id=user.id, title="Épargne de précaution", target_amount=80000.0, current_amount=48000.0)
                db.add(goal)

                db.commit()
                print("[DB SEED] ✅ Base de données initialisée avec succès avec l'utilisateur David YAO !")
        except Exception as e:
            db.rollback()
            print(f"[DB SEED] Error seeding data: {e}")
        finally:
            db.close()

    def get_wallets(self, user_id: str = "usr_default") -> List[Dict[str, Any]]:
        """Récupère les portefeuilles réels de la base de données SQL."""
        db: Session = SessionLocal()
        try:
            wallets = db.query(WalletModel).filter(WalletModel.user_id == user_id).all() if user_id and str(user_id).isdigit() else db.query(WalletModel).all()
            if not wallets:
                wallets = db.query(WalletModel).all()
            return [
                {
                    "id": w.id,
                    "provider": w.provider,
                    "balance": w.balance,
                    "currency": w.currency,
                }
                for w in wallets
            ]
        finally:
            db.close()

    def get_recent_transactions(self, limit: int = 5) -> List[Dict[str, Any]]:
        """Récupère les transactions récentes depuis la base de données SQL."""
        db: Session = SessionLocal()
        try:
            txs = db.query(TransactionModel).order_by(TransactionModel.timestamp.desc()).limit(limit).all()
            return [
                {
                    "id": t.id,
                    "type": t.type,
                    "amount": t.amount,
                    "category": t.category,
                    "recipient": t.recipient,
                    "timestamp": t.timestamp.isoformat(),
                }
                for t in txs
            ]
        finally:
            db.close()

# Instance globale
financial_repository = FinancialRepository()
