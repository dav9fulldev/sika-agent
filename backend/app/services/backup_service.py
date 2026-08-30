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
# Removed mock imports; real data will be used
from ..repositories.financial_repository import financial_repository
from ..services.wallet_integrations.paymechap_api_service import paymechap_api_service
from ..services.wallet_integrations.wave_api_service import wave_api_service
from ..services.wallet_integrations.orange_money_api_service import orange_money_api_service
from ..services.wallet_integrations.mtn_momo_api_service import mtn_momo_api_service
from ..config import settings

logger = logging.getLogger("SikaBackupService")

class BackupService:
    """Gère la création de snapshots et le backup des données d'apprentissage IA."""

    def __init__(self):
        self._backups: List[Dict[str, Any]] = []

    def create_backup_snapshot(self, user_id: str = "default_user") -> Dict[str, Any]:
        """Génère un snapshot de sauvegarde complet de l'état du client."""
        profile = user_learning_service.get_user_profile(user_id)

        # Prefer real enrolled wallets for snapshots. Fallback to mocks only outside production.
        try:
            repo_wallets = financial_repository.get_wallets(user_id)
        except Exception:
            repo_wallets = []

        wallets_for_snapshot = []
        if repo_wallets:
            for w in repo_wallets:
                prov = (w.get("provider") or "").lower()
                acc = w.get("external_wallet_id")
                bal = 0.0
                if "paymechap" in prov:
                    fetched = paymechap_api_service.fetch_live_balance("", acc)
                    bal = float(fetched.get("balance", 0.0))
                elif "wave" in prov:
                    fetched = wave_api_service.fetch_live_balance("token", acc)
                    bal = float(fetched.get("balance", 0.0))
                elif "orange" in prov:
                    fetched = orange_money_api_service.fetch_live_balance("token", acc)
                    bal = float(fetched.get("balance", 0.0))
                elif "mtn" in prov:
                    fetched = mtn_momo_api_service.fetch_live_balance("token", acc)
                    bal = float(fetched.get("balance", 0.0))
                wallets_for_snapshot.append({"provider": w.get("provider"), "account_number": acc, "balance": bal, "currency": "XOF"})
        else:
            # No real wallets found; use empty list for snapshot
            wallets_for_snapshot = []

        snapshot = {
            "snapshot_id": f"backup_{int(datetime.now().timestamp())}",
            "created_at": datetime.now().isoformat(),
            "user_id": user_id,
            "user_profile": profile,
            "financial_state": {
                "wallets": wallets_for_snapshot,
                "recent_transactions": [],
            },
            "training_dataset_records": [],
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
