"""add paypal subscriptions

Revision ID: a7d3e9f1c204
Revises: f2c4a6b8d013
Create Date: 2026-10-27 16:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a7d3e9f1c204'
down_revision: Union[str, Sequence[str], None] = 'f2c4a6b8d013'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('paypal_subscriptions',
    sa.Column('subscription_ref', sa.String(length=40), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('plan_key', sa.String(length=64), nullable=False),
    sa.Column('plan_id', sa.String(length=64), nullable=False),
    sa.Column('name', sa.String(length=127), nullable=False),
    sa.Column('price', sa.String(length=20), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('status', sa.String(length=32), nullable=False),
    sa.Column('paypal_subscription_id', sa.String(length=64), nullable=True),
    sa.Column('paypal_status', sa.String(length=32), nullable=False),
    sa.Column('approve_url', sa.String(length=512), nullable=True),
    sa.Column('request_id', sa.String(length=64), nullable=False),
    sa.Column('next_billing_time', sa.String(length=40), nullable=True),
    sa.Column('last_error_code', sa.String(length=80), nullable=True),
    sa.Column('last_error_message', sa.String(length=255), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('subscription_ref')
    )
    op.create_index('ix_paypal_subscriptions_user_id', 'paypal_subscriptions', ['user_id'], unique=False)
    op.create_index('ix_paypal_subscriptions_paypal_subscription_id', 'paypal_subscriptions', ['paypal_subscription_id'], unique=True)
    op.create_index('ix_paypal_subscriptions_user_status', 'paypal_subscriptions', ['user_id', 'status'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_paypal_subscriptions_user_status', table_name='paypal_subscriptions')
    op.drop_index('ix_paypal_subscriptions_paypal_subscription_id', table_name='paypal_subscriptions')
    op.drop_index('ix_paypal_subscriptions_user_id', table_name='paypal_subscriptions')
    op.drop_table('paypal_subscriptions')
