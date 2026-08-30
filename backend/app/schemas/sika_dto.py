import re
from pydantic import BaseModel, field_validator
from typing import List, Optional, Dict, Any

class BudgetDTO(BaseModel):
    category: str
    monthly_limit: float
    current_spent: float

class GoalDTO(BaseModel):
    name: str
    target_amount: float
    current_amount: float
    is_completed: bool = False

class FinancialContextDTO(BaseModel):
    user_id: int = 1
    user_firstname: str = "David"
    currency_code: str = "USD"
    currency_symbol: str = "$"
    monthly_income: Optional[float] = None
    budgets: List[BudgetDTO] = []
    goals: List[GoalDTO] = []
    total_budget: float = 0.0
    total_spent: float = 0.0

class SikaQueryDTO(BaseModel):
    query: str
    context: Optional[Dict[str, Any]] = None

    @field_validator("query")
    @classmethod
    def sanitize_query(cls, v: str) -> str:
        if not v or not v.strip():
            return v
        # Anti-XSS and Command Injection Sanitization
        sanitized = re.sub(r'<[^>]*>', '', v)  # Remove HTML tags
        sanitized = re.sub(r'script|javascript:|eval\(', '', sanitized, flags=re.IGNORECASE)
        return sanitized[:1000].strip()


class SikaResponseDTO(BaseModel):
    query: str
    message: str
    intent: Optional[str] = "chat"
    sentiment: Optional[str] = "positive"
    suggestions: List[str] = []
    provider: str = "VERTEX_AI"
    status: Optional[str] = "PROCESSED"
    action_id: Optional[str] = None
    requires_confirmation: Optional[bool] = False
    requires_biometric: Optional[bool] = False
    requires_security_validation: Optional[bool] = False
    should_speak: Optional[bool] = True
    speech_text: Optional[str] = None
    action_data: Optional[Dict[str, Any]] = None
    agent_steps: List[Dict[str, Any]] = []

class AuthLoginRequest(BaseModel):
    email: str
    password: str

class AuthRegisterRequest(BaseModel):
    name: str
    email: str
    password: str

class AuthGoogleRequest(BaseModel):
    email: Optional[str] = None
    name: Optional[str] = None
    id_token: Optional[str] = None

class AuthForgotPasswordRequest(BaseModel):
    email: str

class AuthResetPasswordRequest(BaseModel):
    email: str
    otp: str
    new_password: str

class TTSRequest(BaseModel):
    text: Optional[str] = None
    speech_text: Optional[str] = None
    voice_name: str = "fr-FR-Neural2-C"
    speaking_rate: float = 1.05

class AgentProcessRequest(BaseModel):
    query: str

class AgentConfirmRequest(BaseModel):
    action_id: str

class AgentCancelRequest(BaseModel):
    action_id: str
    reason: str = "USER_CANCELLED"
