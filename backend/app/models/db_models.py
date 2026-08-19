"""
SQLAlchemy Data Models pour la Base de Données SIKA

Architecture SIKA Database :
1. USERS & AUTHENTICATION (users, connected_wallets)
2. SIKA DATA & PREFERENCES (user_preferences, savings_goals)
3. AGENT MEMORY & INSIGHTS (agent_memories)

Note : Les données financières en temps réel (soldes, mouvements) restent hébergées
au niveau des APIs partenaires (PayMeChap / Wave / Orange Money / MTN MoMo).
"""

# pyrefly: ignore [missing-import]
from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, ForeignKey, Text
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import relationship
from datetime import datetime
from ..database import Base

class UserModel(Base):
    """Table centrale des utilisateurs SIKA (Gestion de l'Identité)."""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    email = Column(String(100), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=True)
    full_name = Column(String(100), nullable=False, default="David YAO")
    google_id = Column(String(100), nullable=True)
    auth_provider = Column(String(20), nullable=False, default="email") # 'email' ou 'google'
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    connected_wallets = relationship("ConnectedWalletModel", back_populates="user", cascade="all, delete-orphan")
    preferences = relationship("UserPreferenceModel", back_populates="user", uselist=False, cascade="all, delete-orphan")
    goals = relationship("SavingsGoalModel", back_populates="user", cascade="all, delete-orphan")
    memories = relationship("AgentMemoryModel", back_populates="user", cascade="all, delete-orphan")


class ConnectedWalletModel(Base):
    """Lien de référence entre l'Utilisateur SIKA et ses comptes partenaires (sans duplication des transactions)."""
    __tablename__ = "connected_wallets"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    provider = Column(String(50), nullable=False) # Wave, Orange Money, MTN MoMo
    external_wallet_id = Column(String(100), nullable=True) # Numéro de compte / ID Partenaire
    connection_status = Column(String(20), default="connected") # connected, disconnected, pending
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("UserModel", back_populates="connected_wallets")


class UserPreferenceModel(Base):
    """Préférences et règles budgétaires configurées par l'utilisateur."""
    __tablename__ = "user_preferences"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, unique=True)
    preferred_currency = Column(String(10), default="XOF")
    preferred_language = Column(String(10), default="fr")
    monthly_budget = Column(Float, nullable=True, default=150000.0)
    savings_preference = Column(String(50), default="moderate") # conservative, moderate, aggressive
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("UserModel", back_populates="preferences")


class SavingsGoalModel(Base):
    """Objectifs d'épargne définis par l'utilisateur dans l'application SIKA."""
    __tablename__ = "savings_goals"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String(100), nullable=False)
    target_amount = Column(Float, nullable=False)
    current_amount = Column(Float, default=0.0)
    deadline = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("UserModel", back_populates="goals")


class AgentMemoryModel(Base):
    """Mémoire progressive et intelligence de l'Agent SIKA (Court-terme, Long-terme, Insights, Habitudes)."""
    __tablename__ = "agent_memories"

    id = Column(Integer, primary_key=True, autoincrement=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    memory_type = Column(String(50), nullable=False, default="long_term") # short_term, long_term, insight, habit
    key = Column(String(100), nullable=False)
    value = Column(Text, nullable=False) # Information mémorisée
    confidence_score = Column(Float, default=1.0)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("UserModel", back_populates="memories")

