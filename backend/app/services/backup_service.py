"""
Service de Sauvegarde, Snapshot et Backup de Mémoire IA (Fine-tuning & Dataset Backup)

Gère l'export de l'historique financier et des profils comportementaux
pour l'entraînement et la persistance en base de données.
"""

from typing import Dict, Any, List
import json
import logging
from datetime import datetime
from .user_learning_service import user_learning_service
from ..agent.tools.mock_data import MOCK_WALLETS, MOCK_TRANSACTIONS

logger = logging.getLogger("SikaBackupService")

class BackupService:
    """Gère la création de snapshots et le backup des données d'apprentissage IA."""

    def __init__(self):
        self._backups: List[Dict[str, Any]] = []

    def create_backup_snapshot(self, user_id: str = "default_user") -> Dict[str, Any]:
        """Génère un snapshot de sauvegarde complet de l'état du client."""
        profile = user_learning_service.get_user_profile(user_id)

        snapshot = {
            "snapshot_id": f"backup_{int(datetime.now().timestamp())}",
            "created_at": datetime.now().isoformat(),
            "user_id": user_id,
            "user_profile": profile,
            "financial_state": {
                "wallets": MOCK_WALLETS,
                "recent_transactions": MOCK_TRANSACTIONS,
            },
            "training_dataset_records": [
                {
                    "input": f"Dépense récente dans {t['category']} de {t['amount']} FCFA",
                    "detected_intent": t['type'],
                    "category": t['category'],
                    "timestamp": t['timestamp']
                }
                for t in MOCK_TRANSACTIONS
            ],
            "status": "COMPLETED"
        }

        self._backups.append(snapshot)
        logger.info(f"[BACKUP] Snapshot sauvegardé avec succès ID={snapshot['snapshot_id']}")
        return snapshot

    def get_latest_backup(self, user_id: str = "default_user") -> Dict[str, Any]:
        """Retourne le dernier backup enregistré pour un utilisateur."""
        for b in reversed(self._backups):
            if b["user_id"] == user_id:
                return b
        return self.create_backup_snapshot(user_id)

# Instance singleton
backup_service = BackupService()
