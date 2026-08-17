"""
Service d'Apprentissage Continu et Gestion des Habitudes Financières (AI Long-Term Memory)

Permet à l'agent SIKA de:
1. Suivre et analyser les habitudes d'achat du client (David YAO).
2. Détecter les régularités (catégories récurrentes, montants moyens, horaires).
3. Ajuster dynamiquement les recommandations financières et le niveau d'alerte.
"""

from typing import Dict, Any, List, Optional
import json
import logging
from datetime import datetime

logger = logging.getLogger("SikaUserLearningService")

class UserLearningService:
    """Gère la mémoire comportementale et l'apprentissage des habitudes du client."""

    def __init__(self):
        # Profil client récursif en mémoire (simulant la persistance DB long-terme)
        self._user_profiles: Dict[str, Dict[str, Any]] = {
            "default_user": {
                "user_id": "default_user",
                "name": "David YAO",
                "status": "Premium",
                "primary_currency": "FCFA",
                "preferred_payment_method": "Wave",
                "habits": {
                    "restauration": {
                        "category": "Restauration",
                        "average_spent": 4500.0,
                        "frequency_per_week": 4,
                        "preferred_time": "12:00-14:00",
                        "risk_level": "medium",
                    },
                    "transport": {
                        "category": "Transport",
                        "average_spent": 2000.0,
                        "frequency_per_week": 5,
                        "preferred_time": "08:00-19:00",
                        "risk_level": "low",
                    },
                },
                "savings_behavior": {
                    "monthly_goal": 80000.0,
                    "current_saved": 48000.0,
                    "target_completion": 0.60,
                    "risk_tolerance": "Conservative",
                },
                "interaction_insights": [
                    "Répond positivement aux alertes proactives de budget.",
                    "Préfère les transferts vers les proches via Wave.",
                    "Consulte principalement l'onglet Insights le soir."
                ],
                "last_updated": datetime.now().isoformat(),
            }
        }

    def get_user_profile(self, user_id: str = "default_user") -> Dict[str, Any]:
        """Retourne le profil comportemental et les habitudes d'un utilisateur."""
        profile = self._user_profiles.get(user_id, self._user_profiles["default_user"])
        return profile

    def update_user_habit(
        self,
        user_id: str,
        category: str,
        amount: float,
        frequency_per_week: int = 1,
        time_slot: str = "journée"
    ) -> Dict[str, Any]:
        """Enregistre ou met à jour une habitude d'achat identifiée."""
        profile = self.get_user_profile(user_id)
        cat_key = category.lower().replace(" ", "_")

        existing_habit = profile["habits"].get(cat_key, {})
        old_avg = existing_habit.get("average_spent", amount)
        # Moyenne glissante
        new_avg = round((old_avg + amount) / 2.0, 2)

        profile["habits"][cat_key] = {
            "category": category,
            "average_spent": new_avg,
            "frequency_per_week": frequency_per_week,
            "preferred_time": time_slot,
            "last_spent": amount,
            "updated_at": datetime.now().isoformat()
        }
        profile["last_updated"] = datetime.now().isoformat()
        logger.info(f"[LEARNING] Habitude mise à jour pour {user_id} - Catégorie: {category}, Moyenne: {new_avg}")
        return profile["habits"][cat_key]

    def add_interaction_insight(self, user_id: str, insight: str) -> List[str]:
        """Enrichit la mémoire comportementale avec une nouvelle observation sur les préférences du client."""
        profile = self.get_user_profile(user_id)
        if insight not in profile["interaction_insights"]:
            profile["interaction_insights"].append(insight)
            profile["last_updated"] = datetime.now().isoformat()
        return profile["interaction_insights"]

# Instance singleton
user_learning_service = UserLearningService()
