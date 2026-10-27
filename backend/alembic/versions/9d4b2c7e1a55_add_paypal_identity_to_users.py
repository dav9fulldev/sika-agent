"""add paypal identity and kyc status to users

Revision ID: 9d4b2c7e1a55
Revises: 7c3e9a1f2b40
Create Date: 2026-10-27 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '9d4b2c7e1a55'
down_revision: Union[str, Sequence[str], None] = '7c3e9a1f2b40'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('users', sa.Column('paypal_payer_id', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('country', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('kyc_status', sa.String(length=20), nullable=False, server_default='none'))
    op.create_index('ix_users_paypal_payer_id', 'users', ['paypal_payer_id'], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_users_paypal_payer_id', table_name='users')
    op.drop_column('users', 'kyc_status')
    op.drop_column('users', 'country')
    op.drop_column('users', 'paypal_payer_id')
