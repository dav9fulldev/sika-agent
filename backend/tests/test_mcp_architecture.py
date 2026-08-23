# pyrefly: ignore [missing-import]
import pytest
from sqlalchemy.orm import Session
from app.database import engine, Base
from app.models import UserModel, ConnectedWalletModel
from app.agent.mcp_server import (
    MCPFinancialData,
    MCPMarketIndicators,
    MCPUserProfile,
    investment_advisor,
    price_prediction,
    portfolio_strategist,
)


from app.models import (
    UserModel, ConnectedWalletModel, SikaActionModel,
    SavingsGoalModel, AgentMemoryModel, UserPreferenceModel,
    SikaActionEventModel, SikaSessionModel
)

def _reset_db_safely():
    with Session(engine) as db:
        for model in [SikaActionEventModel, SikaSessionModel, SikaActionModel, ConnectedWalletModel, SavingsGoalModel, AgentMemoryModel, UserPreferenceModel, UserModel]:
            try:
                db.query(model).delete(synchronize_session=False)
                db.commit()
            except Exception:
                db.rollback()

@pytest.fixture(autouse=True)
def setup_mcp_data():
    Base.metadata.create_all(bind=engine)
    _reset_db_safely()
    with Session(engine) as db:
        user = UserModel(
            id=1,
            email="usr_default@sika.app",
            full_name="David YAO",
            auth_provider="email"
        )
        db.add(user)
        db.commit()

        wallet = ConnectedWalletModel(
            user_id=1,
            provider="Wave CI",
            external_wallet_id="0700000001",
            connection_status="connected"
        )
        db.add(wallet)
        db.commit()
    yield
    _reset_db_safely()


def test_mcp_servers():
    wallets = MCPFinancialData.get_user_wallets("1")
    assert len(wallets) > 0

    indicators = MCPMarketIndicators.get_indicators()
    assert "inflation_rate" in indicators

    profile = MCPUserProfile.get_profile("1")
    assert profile["name"] == "David YAO"


def test_specialized_agents():
    advice = investment_advisor.advise("1")
    assert advice["agent"] == "InvestmentAdvisor"

    pred = price_prediction.predict_spending("1")
    assert pred["agent"] == "PricePrediction"

    strat = portfolio_strategist.strategize("1")
    assert strat["agent"] == "PortfolioStrategist"
