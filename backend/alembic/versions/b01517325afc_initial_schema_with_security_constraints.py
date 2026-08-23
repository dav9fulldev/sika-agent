"""initial_schema_with_security_constraints

Revision ID: b01517325afc
Revises: 
Create Date: 2026-08-21 08:31:12.116897

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b01517325afc'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Table users
    op.create_table(
        'users',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('email', sa.String(length=100), nullable=False),
        sa.Column('password_hash', sa.String(length=255), nullable=True),
        sa.Column('full_name', sa.String(length=100), nullable=False, server_default='David YAO'),
        sa.Column('google_id', sa.String(length=100), nullable=True),
        sa.Column('auth_provider', sa.String(length=20), nullable=False, server_default='email'),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)

    # 2. Table connected_wallets (avec FK CASCADE et CHECK constraint)
    op.create_table(
        'connected_wallets',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('provider', sa.String(length=50), nullable=False),
        sa.Column('external_wallet_id', sa.String(length=100), nullable=True),
        sa.Column('connection_status', sa.String(length=20), nullable=False, server_default='connected'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "connection_status IN ('connected', 'disconnected', 'pending')",
            name='chk_connected_wallet_status_valid'
        ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_connected_wallets_id'), 'connected_wallets', ['id'], unique=False)
    op.create_index(op.f('ix_connected_wallets_user_id'), 'connected_wallets', ['user_id'], unique=False)

    # 3. Table sika_actions (avec FK CASCADE, CHECK constraint et index composites)
    op.create_table(
        'sika_actions',
        sa.Column('action_id', sa.String(length=100), nullable=False),
        sa.Column('idempotency_key', sa.String(length=100), nullable=True),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('action_type', sa.String(length=50), nullable=False, server_default='TRANSFER'),
        sa.Column('status', sa.String(length=50), nullable=False, server_default='WAITING_CONFIRMATION'),
        sa.Column('payload_json', sa.Text(), nullable=True),
        sa.Column('result_json', sa.Text(), nullable=True),
        sa.Column('cancelled_reason', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint(
            "status IN ('WAITING_CONFIRMATION', 'EXECUTING', 'EXECUTED', 'CANCELLED', 'EXPIRED', 'FAILED', 'UNKNOWN_RESULT')",
            name='chk_sika_action_status_valid'
        ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('action_id')
    )
    op.create_index(op.f('ix_sika_actions_action_id'), 'sika_actions', ['action_id'], unique=False)
    op.create_index(op.f('ix_sika_actions_idempotency_key'), 'sika_actions', ['idempotency_key'], unique=False)
    op.create_index(op.f('ix_sika_actions_user_id'), 'sika_actions', ['user_id'], unique=False)
    op.create_index('ix_sika_actions_user_status', 'sika_actions', ['user_id', 'status'], unique=False)
    op.create_index('ix_sika_actions_user_created', 'sika_actions', ['user_id', 'created_at'], unique=False)

    # 4. Table savings_goals (avec FK CASCADE et CHECK montants non-négatifs)
    op.create_table(
        'savings_goals',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=100), nullable=False),
        sa.Column('target_amount', sa.Float(), nullable=False),
        sa.Column('current_amount', sa.Float(), nullable=False, server_default='0.0'),
        sa.Column('deadline', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.CheckConstraint('target_amount >= 0', name='chk_savings_goal_target_non_negative'),
        sa.CheckConstraint('current_amount >= 0', name='chk_savings_goal_current_non_negative'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_savings_goals_id'), 'savings_goals', ['id'], unique=False)
    op.create_index(op.f('ix_savings_goals_user_id'), 'savings_goals', ['user_id'], unique=False)

    # 5. Table agent_memories (avec FK CASCADE)
    op.create_table(
        'agent_memories',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('memory_type', sa.String(length=50), nullable=False, server_default='long_term'),
        sa.Column('key', sa.String(length=100), nullable=False),
        sa.Column('value', sa.Text(), nullable=False),
        sa.Column('confidence_score', sa.Float(), nullable=True, server_default='1.0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_agent_memories_id'), 'agent_memories', ['id'], unique=False)
    op.create_index(op.f('ix_agent_memories_user_id'), 'agent_memories', ['user_id'], unique=False)

    # 6. Table user_preferences (avec FK CASCADE et unicité user_id)
    op.create_table(
        'user_preferences',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('preferred_currency', sa.String(length=10), nullable=True, server_default='XOF'),
        sa.Column('preferred_language', sa.String(length=10), nullable=True, server_default='fr'),
        sa.Column('monthly_budget', sa.Float(), nullable=True, server_default='150000.0'),
        sa.Column('savings_preference', sa.String(length=50), nullable=True, server_default='moderate'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
    )
    op.create_index(op.f('ix_user_preferences_id'), 'user_preferences', ['id'], unique=False)
    op.create_index(op.f('ix_user_preferences_user_id'), 'user_preferences', ['user_id'], unique=True)

    # 7. Table sika_action_events (Audit Trail immuable append-only)
    op.create_table(
        'sika_action_events',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('action_id', sa.String(length=100), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('previous_status', sa.String(length=50), nullable=True),
        sa.Column('new_status', sa.String(length=50), nullable=False),
        sa.Column('event_type', sa.String(length=50), nullable=False, server_default='STATE_CHANGE'),
        sa.Column('reason', sa.Text(), nullable=True),
        sa.Column('metadata_json', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_sika_action_events_action_id'), 'sika_action_events', ['action_id'], unique=False)
    op.create_index(op.f('ix_sika_action_events_user_id'), 'sika_action_events', ['user_id'], unique=False)

    # 8. Table sika_sessions (Persistance des états conversationnels multi-tours)
    op.create_table(
        'sika_sessions',
        sa.Column('user_id', sa.String(length=50), nullable=False),
        sa.Column('state', sa.String(length=50), nullable=False, server_default='IDLE'),
        sa.Column('active_action_id', sa.String(length=100), nullable=True),
        sa.Column('session_data_json', sa.Text(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('user_id')
    )
    op.create_index(op.f('ix_sika_sessions_user_id'), 'sika_sessions', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_table('sika_sessions')
    op.drop_table('sika_action_events')
    op.drop_table('user_preferences')
    op.drop_table('agent_memories')
    op.drop_table('savings_goals')
    op.drop_table('sika_actions')
    op.drop_table('connected_wallets')
    op.drop_table('users')
