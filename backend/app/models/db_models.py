"""
SQLAlchemy Data Models pour la Base de Données SIKA
"""

# pyrefly: ignore [missing-import]
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import relationship
from datetime import datetime
from ..database import Base

class UserModel(Base):
    __tablename__ = "users"

    id = Column(String(50), primary_key=True, index=True, default="usr_default")
    name = Column(String(100), nullable=False, default="David YAO")
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=True)
    is_premium = Column(Boolean, default=True)
    preferred_currency = Column(String(10), default="XOF")
    preferred_language = Column(String(10), default="fr")
    created_at = Column(DateTime, default=datetime.utcnow)

    wallets = relationship("WalletModel", back_populates="user", cascade="all, delete-orphan")
    goals = relationship("SavingsGoalModel", back_populates="user", cascade="all, delete-orphan")
    habits = relationship("UserHabitModel", back_populates="user", cascade="all, delete-orphan")

class WalletModel(Base):
    __tablename__ = "wallets"

    id = Column(String(50), primary_key=True, index=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=False)
    provider = Column(String(50), nullable=False) # Wave, Orange Money, MTN MoMo
    balance = Column(Float, nullable=False, default=0.0)
    currency = Column(String(10), default="XOF")
    account_number = Column(String(50), nullable=True)
    
    # Méthodes 1 & 3 : APIs Directes OAuth2 et Moteur de Perception SMS/Push
    auth_method = Column(String(50), default="OAUTH2_WAVE") # OAUTH2_WAVE, ORANGE_DEVELOPER_API, MTN_MOMO_API, PERCEIVE_SMS_PUSH
    account_identifier = Column(String(100), nullable=True) # Numéro de téléphone ou ID de compte
    access_token = Column(String(255), nullable=True) # Jeton OAuth2 de session API
    refresh_token = Column(String(255), nullable=True)
    is_active = Column(Boolean, default=True)
    last_synced_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("UserModel", back_populates="wallets")
    transactions = relationship("TransactionModel", back_populates="wallet", cascade="all, delete-orphan")

class TransactionModel(Base):
    __tablename__ = "transactions"

    id = Column(String(50), primary_key=True, index=True)
    wallet_id = Column(String(50), ForeignKey("wallets.id"), nullable=False)
    type = Column(String(20), nullable=False) # payment, transfer, deposit, withdrawal
    amount = Column(Float, nullable=False)
    currency = Column(String(10), default="XOF")
    category = Column(String(50), default="Autre")
    recipient = Column(String(100), nullable=True)
    description = Column(String(255), nullable=True)
    status = Column(String(20), default="completed")
    timestamp = Column(DateTime, default=datetime.utcnow)

    wallet = relationship("WalletModel", back_populates="transactions")

class SavingsGoalModel(Base):
    __tablename__ = "savings_goals"

    id = Column(String(50), primary_key=True, index=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=False)
    title = Column(String(100), nullable=False)
    target_amount = Column(Float, nullable=False)
    current_amount = Column(Float, default=0.0)
    currency = Column(String(10), default="XOF")
    deadline = Column(DateTime, nullable=True)

    user = relationship("UserModel", back_populates="goals")

class UserHabitModel(Base):
    __tablename__ = "user_habits"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=False)
    category = Column(String(50), nullable=False)
    average_spent = Column(Float, default=0.0)
    frequency_per_week = Column(Integer, default=1)
    preferred_time = Column(String(50), default="12:00-14:00")
    updated_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("UserModel", back_populates="habits")

class MemorySnapshotModel(Base):
    __tablename__ = "memory_snapshots"

    id = Column(String(50), primary_key=True, index=True)
    user_id = Column(String(50), nullable=False)
    snapshot_data = Column(Text, nullable=False) # JSON d'état
    created_at = Column(DateTime, default=datetime.utcnow)
