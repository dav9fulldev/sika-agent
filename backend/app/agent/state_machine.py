"""
State Machine de l'Agent SIKA

Gère l'état courant de l'agent au cours de la boucle Taskmaster.
"""

from enum import Enum

class AgentState(str, Enum):
    IDLE = "IDLE"                           # En attente d'un événement ou d'un prompt
    PERCEIVING = "PERCEIVING"               # Ingestion d'une notification ou voix
    UNDERSTANDING = "UNDERSTANDING"         # Extraction sémantique intention/entités
    UPDATING_CONTEXT = "UPDATING_CONTEXT"   # Mise à jour du contexte financier
    ANALYZING = "ANALYZING"                 # Analyse financière via FinancialBrain
    PLANNING = "PLANNING"                   # Construction du plan d'action
    WAITING_CONFIRMATION = "WAITING_CONFIRMATION"  # Human-in-the-loop (Validation utilisateur)
    EXECUTING = "EXECUTING"                 # Exécution des tools autorisés
    VERIFYING = "VERIFYING"                 # Vérification post-exécution
    TRACKING = "TRACKING"                   # Suivi continu de l'objectif
    INFORMING = "INFORMING"                 # Information synthétique émise à l'utilisateur
    ERROR = "ERROR"                         # Gestion d'erreur
