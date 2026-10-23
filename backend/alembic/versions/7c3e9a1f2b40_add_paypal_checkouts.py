"""add paypal checkouts (SIKA Pay)

Revision ID: 7c3e9a1f2b40
Revises: 28e2f76cd60a
Create Date: 2026-10-23 23:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '7c3e9a1f2b40'
down_revision: Union[str, Sequence[str], None] = '28e2f76cd60a'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

STATUSES = (
    "AWAITING_USER_CONFIRMATION", "CREATING_ORDER", "AWAITING_PAYPAL_APPROVAL", "APPROVED", "CAPTURING",
    "COMPLETED", "PENDING", "DECLINED", "CANCELLED", "EXPIRED", "FAILED", "UNKNOWN_RESULT",
)


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('paypal_checkouts',
    sa.Column('checkout_id', sa.String(length=64), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('status', sa.String(length=40), nullable=False),
    sa.Column('sku', sa.String(length=64), nullable=False),
    sa.Column('item_name', sa.String(length=127), nullable=False),
    sa.Column('item_description', sa.String(length=255), nullable=True),
    sa.Column('quantity', sa.Integer(), nullable=False),
    sa.Column('unit_amount', sa.String(length=20), nullable=False),
    sa.Column('total_amount', sa.String(length=20), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('merchant_name', sa.String(length=127), nullable=False),
    sa.Column('budget_limit', sa.String(length=20), nullable=True),
    sa.Column('budget_currency', sa.String(length=3), nullable=True),
    sa.Column('user_request', sa.Text(), nullable=True),
    sa.Column('details_hash', sa.String(length=64), nullable=False),
    sa.Column('create_request_id', sa.String(length=64), nullable=False),
    sa.Column('capture_request_id', sa.String(length=64), nullable=False),
    sa.Column('paypal_order_id', sa.String(length=64), nullable=True),
    sa.Column('paypal_order_status', sa.String(length=40), nullable=True),
    sa.Column('approve_url', sa.String(length=512), nullable=True),
    sa.Column('capture_id', sa.String(length=64), nullable=True),
    sa.Column('capture_status', sa.String(length=40), nullable=True),
    sa.Column('captured_amount', sa.String(length=20), nullable=True),
    sa.Column('captured_currency', sa.String(length=3), nullable=True),
    sa.Column('paypal_debug_id', sa.String(length=64), nullable=True),
    sa.Column('last_error_code', sa.String(length=80), nullable=True),
    sa.Column('last_error_message', sa.String(length=255), nullable=True),
    sa.Column('expires_at', sa.DateTime(), nullable=False),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.Column('result_json', sa.Text(), nullable=True),
    sa.CheckConstraint("status IN (" + ", ".join(f"'{s}'" for s in STATUSES) + ")", name='chk_paypal_checkout_status_valid'),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('checkout_id')
    )
    op.create_index('ix_paypal_checkouts_checkout_id', 'paypal_checkouts', ['checkout_id'], unique=False)
    op.create_index('ix_paypal_checkouts_user_id', 'paypal_checkouts', ['user_id'], unique=False)
    op.create_index('ix_paypal_checkouts_paypal_order_id', 'paypal_checkouts', ['paypal_order_id'], unique=True)
    op.create_index('ix_paypal_checkouts_user_status', 'paypal_checkouts', ['user_id', 'status'], unique=False)
    op.create_index('ix_paypal_checkouts_user_created', 'paypal_checkouts', ['user_id', 'created_at'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_paypal_checkouts_user_created', table_name='paypal_checkouts')
    op.drop_index('ix_paypal_checkouts_user_status', table_name='paypal_checkouts')
    op.drop_index('ix_paypal_checkouts_paypal_order_id', table_name='paypal_checkouts')
    op.drop_index('ix_paypal_checkouts_user_id', table_name='paypal_checkouts')
    op.drop_index('ix_paypal_checkouts_checkout_id', table_name='paypal_checkouts')
    op.drop_table('paypal_checkouts')
