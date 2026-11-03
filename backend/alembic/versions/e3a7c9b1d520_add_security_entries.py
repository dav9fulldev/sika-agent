"""add security entries (database security store, replaces Redis)

Revision ID: e3a7c9b1d520
Revises: d8b2e5c1a347
Create Date: 2026-11-03 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e3a7c9b1d520'
down_revision: Union[str, Sequence[str], None] = 'd8b2e5c1a347'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('security_entries',
    sa.Column('key', sa.String(length=80), nullable=False),
    sa.Column('value', sa.String(length=128), nullable=True),
    sa.Column('count', sa.Integer(), nullable=False),
    sa.Column('expires_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('key')
    )
    op.create_index('ix_security_entries_expires_at', 'security_entries', ['expires_at'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_security_entries_expires_at', table_name='security_entries')
    op.drop_table('security_entries')
