"""add paypal vault tokens and checkout payment method

Revision ID: b3e8d2f4a915
Revises: a7d3e9f1c204
Create Date: 2026-10-28 11:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3e8d2f4a915'
down_revision: Union[str, Sequence[str], None] = 'a7d3e9f1c204'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('paypal_vault_tokens',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('status', sa.String(length=20), nullable=False),
    sa.Column('setup_token_id', sa.String(length=64), nullable=False),
    sa.Column('payment_token_id', sa.String(length=64), nullable=True),
    sa.Column('customer_id', sa.String(length=64), nullable=True),
    sa.Column('payer_email_masked', sa.String(length=127), nullable=True),
    sa.Column('request_id', sa.String(length=64), nullable=False),
    sa.Column('last_error_code', sa.String(length=80), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('payment_token_id'),
    )
    op.create_index('ix_paypal_vault_tokens_user_id', 'paypal_vault_tokens', ['user_id'])
    op.create_index('ix_paypal_vault_tokens_setup_token_id', 'paypal_vault_tokens', ['setup_token_id'], unique=True)
    op.create_index('ix_paypal_vault_user_status', 'paypal_vault_tokens', ['user_id', 'status'])
    op.add_column('paypal_checkouts', sa.Column('payment_method', sa.String(length=20), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('paypal_checkouts', 'payment_method')
    op.drop_index('ix_paypal_vault_user_status', table_name='paypal_vault_tokens')
    op.drop_index('ix_paypal_vault_tokens_setup_token_id', table_name='paypal_vault_tokens')
    op.drop_index('ix_paypal_vault_tokens_user_id', table_name='paypal_vault_tokens')
    op.drop_table('paypal_vault_tokens')
