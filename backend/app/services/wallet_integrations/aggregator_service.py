"""
Pan-African Open Banking & Mobile Money Aggregator Service (Méthode 2)
Intégration d'Agrégateur d'APIs Financières (Bizao, Mono Africa, Pawapay)
Documentation: https://bizao.io / https://mono.co
"""

import os
import logging
from typing import List, Dict, Any
from datetime import datetime
from .wave_api_service import wave_api_service
from .orange_money_api_service import orange_money_api_service
from .mtn_momo_api_service import mtn_momo_api_service

logger = logging.getLogger("AggregatorAPI")


class AggregatorService:
    """Service d'Agrégation Financière Panafricaine (Méthode 2).

    Permet de centraliser et de synchroniser en une seule requête les soldes et l'historique des mouvements
    de multiples fournisseurs (Wave, Orange, MTN, Moov, Banques) via une passerelle unique.
    """

    def __init__(self):
        self.aggregator_name = os.getenv("AGGREGATOR_PROVIDER", "Bizao Gateway")
        self.api_key = os.getenv("BIZAO_API_KEY", "bizao_sika_live_key")

    def aggregate_all_user_wallets(self, user_id: str = "usr_default") -> List[Dict[str, Any]]:
        """Synchronise l'ensemble des comptes et portefeuilles connectés de l'utilisateur."""
        logger.info(f"[{self.aggregator_name}] Synchronisation des comptes pour l'utilisateur {user_id}")

        wave_data = wave_api_service.fetch_live_balance("live_token")
        orange_data = orange_money_api_service.fetch_live_balance("live_token")
        mtn_data = mtn_momo_api_service.fetch_live_balance("live_token")

        return [
            {
                "id": "w_wave_1",
                "user_id": user_id,
                "provider": "Wave",
                "balance": wave_data["balance"],
                "currency": wave_data["currency"],
                "account_number": wave_data["account_number"],
                "auth_method": "OAUTH2_WAVE",
                "is_active": True,
                "last_synced_at": wave_data["last_synced_at"]
            },
            {
                "id": "w_orange_2",
                "user_id": user_id,
                "provider": "Orange Money",
                "balance": orange_data["balance"],
                "currency": orange_data["currency"],
                "account_number": orange_data["account_number"],
                "auth_method": "ORANGE_DEVELOPER_API",
                "is_active": True,
                "last_synced_at": orange_data["last_synced_at"]
            },
            {
                "id": "w_mtn_3",
                "user_id": user_id,
                "provider": "MTN MoMo",
                "balance": mtn_data["balance"],
                "currency": mtn_data["currency"],
                "account_number": mtn_data["account_number"],
                "auth_method": "MTN_MOMO_API",
                "is_active": True,
                "last_synced_at": mtn_data["last_synced_at"]
            }
        ]

    def fetch_aggregated_account_movements(self, user_id: str = "usr_default", limit: int = 50) -> List[Dict[str, Any]]:
        """Collecte et agrège l'historique complet des mouvements de compte depuis tous les fournisseurs d'APIs."""
        logger.info(f"[{self.aggregator_name}] Collecte des mouvements de tous les comptes pour {user_id}")

        wave_txs = wave_api_service.fetch_live_transactions("live_token", limit=limit)
        orange_txs = orange_money_api_service.fetch_live_transactions("live_token", limit=limit)
        mtn_txs = mtn_momo_api_service.fetch_live_transactions("live_token", limit=limit)

        all_txs = wave_txs + orange_txs + mtn_txs
        all_txs.sort(key=lambda x: x["timestamp"], reverse=True)
        return all_txs[:limit]


aggregator_service = AggregatorService()
