"""
Model Context Protocol (MCP) & Multi-Agent Architecture pour SIKA

Implémente la structure officielle du schéma d'architecture SIKA:
1. MCP Financial Data (Données de portefeuilles, transactions Wave/Orange/MTN)
2. MCP Market Indicators (Indicateurs et analyses financières)
3. MCP User Profile (Profils Supabase, habitudes et mémoire long terme)

Et les 3 Agents IA Spécialisés:
- Investment Advisor Agent
- Price Prediction Agent
- Portfolio Strategist Agent
"""

from typing import Dict, Any, List
import logging
from ..services.user_learning_service import user_learning_service
from ..repositories.financial_repository import financial_repository
from .tools.financial_tools import get_spending_summary, get_financial_context

logger = logging.getLogger("SikaMCPArchitecture")

class MCPFinancialData:
    """Serveur MCP pour les données financières des portefeuilles et marchés."""

    @staticmethod
    def get_user_wallets(user_id: str = "usr_default") -> List[Dict[str, Any]]:
        return financial_repository.get_wallets(user_id)

    @staticmethod
    def get_recent_transactions(limit: int = 5) -> List[Dict[str, Any]]:
        return financial_repository.get_recent_transactions(limit)

class MCPMarketIndicators:
    """Serveur MCP pour les indicateurs de marché et prédictions de risques."""

    @staticmethod
    def get_indicators() -> Dict[str, Any]:
        return {
            "inflation_rate": 0.042,
            "regional_currency": "XOF",
            "market_risk_index": "LOW",
            "suggested_savings_rate": 0.20
        }

class MCPUserProfile:
    """Serveur MCP pour le profil Supabase, les habitudes et la mémoire client."""

    @staticmethod
    def get_profile(user_id: str = "usr_default") -> Dict[str, Any]:
        return user_learning_service.get_user_profile(user_id)

# ============================================================================
# AGENTS SPÉCIALISÉS DU SCHÉMA SIKA
# ============================================================================

class InvestmentAdvisorAgent:
    """Agent IA Spécialisé: Conseil en Investissement et Épargne."""

    def advise(self, user_id: str = "usr_default") -> Dict[str, Any]:
        profile = MCPUserProfile.get_profile(user_id)
        savings = profile.get("savings_behavior", {})
        return {
            "agent": "InvestmentAdvisor",
            "recommendation": f"Pour atteindre votre objectif de {savings.get('monthly_goal', 80000)} FCFA, privilégiez un versement automatique hebdo de 5 000 FCFA.",
            "risk_profile": savings.get("risk_tolerance", "Conservative")
        }

class PricePredictionAgent:
    """Agent IA Spécialisé: Prédiction des prix et détection des variations."""

    def predict_spending(self, user_id: str = "usr_default") -> Dict[str, Any]:
        summary = get_spending_summary(30)
        return {
            "agent": "PricePrediction",
            "predicted_end_of_month_spend": summary.data.get("total_spent", 0) * 1.1,
            "confidence_score": 0.92
        }

class PortfolioStrategistAgent:
    """Agent IA Spécialisé: Stratège de Portefeuille & Rééquilibrage Multi-Comptes."""

    def strategize(self, user_id: str = "usr_default") -> Dict[str, Any]:
        wallets = MCPFinancialData.get_user_wallets(user_id)
        total = sum(w["balance"] for w in wallets)
        return {
            "agent": "PortfolioStrategist",
            "total_portfolio": total,
            "rebalance_needed": any(w["balance"] < 10000 for w in wallets),
            "recommendation": "Maintenir au moins 30% du solde global sur le compte principal Wave pour les dépenses quotidiennes."
        }

# Instances globales des 3 Agents du Schéma
investment_advisor = InvestmentAdvisorAgent()
price_prediction = PricePredictionAgent()
portfolio_strategist = PortfolioStrategistAgent()
