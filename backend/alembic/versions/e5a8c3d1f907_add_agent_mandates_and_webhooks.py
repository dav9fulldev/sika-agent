"""add agent mandates, paypal webhook events and checkout confirmed_by

Revision ID: e5a8c3d1f907
Revises: 9d4b2c7e1a55
Create Date: 2026-10-27 11:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e5a8c3d1f907'
down_revision: Union[str, Sequence[str], None] = '9d4b2c7e1a55'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('agent_mandates',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('max_per_purchase', sa.String(length=20), nullable=False),
    sa.Column('daily_limit', sa.String(length=20), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('expires_at', sa.DateTime(), nullable=False),
    sa.Column('revoked_at', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_agent_mandates_user_id', 'agent_mandates', ['user_id'], unique=False)
    op.create_index('ix_agent_mandates_user_created', 'agent_mandates', ['user_id', 'created_at'], unique=False)
    op.create_table('paypal_webhook_events',
    sa.Column('event_id', sa.String(length=64), nullable=False),
    sa.Column('event_type', sa.String(length=80), nullable=False),
    sa.Column('resource_id', sa.String(length=64), nullable=True),
    sa.Column('outcome', sa.String(length=80), nullable=True),
    sa.Column('received_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('event_id')
    )
    op.add_column('paypal_checkouts', sa.Column('confirmed_by', sa.String(length=10), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('paypal_checkouts', 'confirmed_by')
    op.drop_table('paypal_webhook_events')
    op.drop_index('ix_agent_mandates_user_created', table_name='agent_mandates')
    op.drop_index('ix_agent_mandates_user_id', table_name='agent_mandates')
    op.drop_table('agent_mandates')
