"""
Module central des modèles SQLAlchemy de SIKA.

L'import de tous les modèles ici permet à SQLAlchemy de connaître
l'ensemble des tables et des relations avant leur création.
"""

from .user import UserModel
from .connected_wallet import ConnectedWalletModel
from .user_preference import UserPreferenceModel
from .savings_goal import SavingsGoalModel
from .agent_memory import AgentMemoryModel
from .sika_action import SikaActionModel
from .sika_session import SikaSessionModel

__all__ = [
    "UserModel",
    "ConnectedWalletModel",
    "UserPreferenceModel",
    "SavingsGoalModel",
    "AgentMemoryModel",
    "SikaActionModel",
    "SikaSessionModel",
]

