"""add dashboard login codes (web dashboard, single-use)

Revision ID: d8b2e5c1a347
Revises: c6f1a9d2e470
Create Date: 2026-10-31 20:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd8b2e5c1a347'
down_revision: Union[str, Sequence[str], None] = 'c6f1a9d2e470'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('dashboard_login_codes',
    sa.Column('code_hash', sa.String(length=64), nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('expires_at', sa.DateTime(), nullable=False),
    sa.Column('used_at', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('code_hash')
    )
    op.create_index('ix_dashboard_login_codes_user_id', 'dashboard_login_codes', ['user_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_dashboard_login_codes_user_id', table_name='dashboard_login_codes')
    op.drop_table('dashboard_login_codes')
