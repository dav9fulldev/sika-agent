"""
Tool Models & Contracts pour l'Agent SIKA

Définit les enums de risque, schémas Pydantic et conteneurs de résultats pour le ToolRegistry.
"""

from enum import Enum
from typing import Dict, Any, Optional, List, Callable
from pydantic import BaseModel, Field

class RiskLevel(str, Enum):
    READ_ONLY = "READ_ONLY"                     # Consultation pure
    CONFIRMATION_REQUIRED = "CONFIRMATION_REQUIRED" # Préparation nécessitant validation
    EXECUTION = "EXECUTION"                     # Action d'écriture / simulation d'exécution

class ToolResult(BaseModel):
    """Résultat standardisé retourné par l'exécution d'un Tool."""
    success: bool
    tool_name: str
    risk_level: RiskLevel
    data: Dict[str, Any]
    error_message: Optional[str] = None
    requires_confirmation: bool = False

class ToolDefinition(BaseModel):
    """Définition d'un Tool SIKA pour le ToolRegistry et Gemini."""
    name: str
    description: str
    risk_level: RiskLevel
    input_schema: Dict[str, Any]
    output_schema: Dict[str, Any]
