# pyrefly: ignore [missing-import]
import pytest
from app.agent.mcp_server import (
    MCPFinancialData,
    MCPMarketIndicators,
    MCPUserProfile,
    investment_advisor,
    price_prediction,
    portfolio_strategist,
)

def test_mcp_servers():
    wallets = MCPFinancialData.get_user_wallets("usr_default")
    assert len(wallets) > 0

    indicators = MCPMarketIndicators.get_indicators()
    assert "inflation_rate" in indicators

    profile = MCPUserProfile.get_profile("usr_default")
    assert profile["name"] == "David YAO"

def test_specialized_agents():
    advice = investment_advisor.advise("usr_default")
    assert advice["agent"] == "InvestmentAdvisor"

    pred = price_prediction.predict_spending("usr_default")
    assert pred["agent"] == "PricePrediction"

    strat = portfolio_strategist.strategize("usr_default")
    assert strat["agent"] == "PortfolioStrategist"
