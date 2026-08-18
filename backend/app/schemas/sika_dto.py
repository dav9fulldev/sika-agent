from pydantic import BaseModel
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

class SikaConfirmTransactionDTO(BaseModel):
    amount: float
    category: str
    description: Optional[str] = "Dépense via Sika"

class SikaResponseDTO(BaseModel):
    query: str
    message: str
    intent: Optional[str] = "chat"
    sentiment: Optional[str] = "positive"
    suggestions: List[str] = []
    provider: str = "OPENAI"
