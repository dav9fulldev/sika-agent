"""
Module central des modèles SQLAlchemy de SIKA.

L'import de tous les modèles ici permet à SQLAlchemy de connaître
l'ensemble des tables et des relations avant leur création.
"""

from .user import UserModel
from .connected_wallet import ConnectedWalletModel
from .sika_action import SikaActionModel
from .payment_method import PaymentMethodModel
from .sika_action_event import SikaActionEventModel
from .sika_session import SikaSessionModel
from .user_preference import UserPreferenceModel
from .agent_memory import AgentMemoryModel
from .savings_goal import SavingsGoalModel
from .payment_method import PaymentMethodModel
from .paypal_checkout import PayPalCheckoutModel
from .agent_mandate import AgentMandateModel
from .paypal_webhook_event import PayPalWebhookEventModel
from .price_watch import PriceWatchModel, ShoppingWebhookEventModel

__all__ = [
    "PayPalCheckoutModel",
    "UserModel",
    "ConnectedWalletModel",
    "SikaActionModel",
    "SikaActionEventModel",
    "SikaSessionModel",
    "UserPreferenceModel",
    "AgentMemoryModel",
    "SavingsGoalModel",
    "PaymentMethodModel"
]
