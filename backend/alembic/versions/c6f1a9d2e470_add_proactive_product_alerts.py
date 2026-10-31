"""add proactive product alerts: auto-follow, notifications and push devices

Revision ID: c6f1a9d2e470
Revises: b3e8d2f4a915
Create Date: 2026-10-31 18:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c6f1a9d2e470'
down_revision: Union[str, Sequence[str], None] = 'b3e8d2f4a915'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('price_watches', sa.Column('source', sa.String(length=8), nullable=False, server_default='user'))
    op.add_column('price_watches', sa.Column('expires_at', sa.DateTime(), nullable=True))
    op.add_column('price_watches', sa.Column('last_notified_at', sa.DateTime(), nullable=True))
    op.add_column('users', sa.Column('auto_follow_products', sa.Boolean(), nullable=False, server_default=sa.true()))
    op.create_table('user_notifications',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('kind', sa.String(length=24), nullable=False),
    sa.Column('product_id', sa.String(length=64), nullable=True),
    sa.Column('title', sa.String(length=200), nullable=False),
    sa.Column('merchant', sa.String(length=120), nullable=True),
    sa.Column('price', sa.String(length=20), nullable=True),
    sa.Column('previous_price', sa.String(length=20), nullable=True),
    sa.Column('currency', sa.String(length=3), nullable=True),
    sa.Column('image_url', sa.String(length=512), nullable=True),
    sa.Column('read_at', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_user_notifications_user_id', 'user_notifications', ['user_id'], unique=False)
    op.create_index('ix_user_notifications_user_created', 'user_notifications', ['user_id', 'created_at'], unique=False)
    op.create_table('push_devices',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('token', sa.Text(), nullable=False),
    sa.Column('token_hash', sa.String(length=64), nullable=False),
    sa.Column('platform', sa.String(length=12), nullable=False),
    sa.Column('language', sa.String(length=2), nullable=False),
    sa.Column('tz_offset_minutes', sa.Integer(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('token_hash')
    )
    op.create_index('ix_push_devices_user_id', 'push_devices', ['user_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index('ix_push_devices_user_id', table_name='push_devices')
    op.drop_table('push_devices')
    op.drop_index('ix_user_notifications_user_created', table_name='user_notifications')
    op.drop_index('ix_user_notifications_user_id', table_name='user_notifications')
    op.drop_table('user_notifications')
    op.drop_column('users', 'auto_follow_products')
    op.drop_column('price_watches', 'last_notified_at')
    op.drop_column('price_watches', 'expires_at')
    op.drop_column('price_watches', 'source')
