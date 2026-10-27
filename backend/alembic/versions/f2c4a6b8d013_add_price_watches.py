"""add price watches and shopping webhook events (Channel3)

Revision ID: f2c4a6b8d013
Revises: e5a8c3d1f907
Create Date: 2026-10-27 15:10:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f2c4a6b8d013'
down_revision: Union[str, Sequence[str], None] = 'e5a8c3d1f907'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table('price_watches',
    sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
    sa.Column('user_id', sa.Integer(), nullable=False),
    sa.Column('product_id', sa.String(length=64), nullable=False),
    sa.Column('title', sa.String(length=200), nullable=False),
    sa.Column('image_url', sa.String(length=512), nullable=True),
    sa.Column('target_price', sa.String(length=20), nullable=True),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('subscription_id', sa.String(length=64), nullable=True),
    sa.Column('status', sa.String(length=12), nullable=False),
    sa.Column('last_price', sa.String(length=20), nullable=True),
    sa.Column('last_merchant', sa.String(length=120), nullable=True),
    sa.Column('last_event', sa.String(length=40), nullable=True),
    sa.Column('triggered_at', sa.DateTime(), nullable=True),
    sa.Column('seen_at', sa.DateTime(), nullable=True),
    sa.Column('created_at', sa.DateTime(), nullable=False),
    sa.Column('updated_at', sa.DateTime(), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index('ix_price_watches_user_id', 'price_watches', ['user_id'], unique=False)
    op.create_index('ix_price_watches_product_id', 'price_watches', ['product_id'], unique=False)
    op.create_index('ix_price_watches_subscription_id', 'price_watches', ['subscription_id'], unique=False)
    op.create_index('ix_price_watches_user_status', 'price_watches', ['user_id', 'status'], unique=False)
    op.create_table('shopping_webhook_events',
    sa.Column('event_id', sa.String(length=80), nullable=False),
    sa.Column('event_type', sa.String(length=40), nullable=False),
    sa.Column('outcome', sa.String(length=80), nullable=True),
    sa.Column('received_at', sa.DateTime(), nullable=False),
    sa.PrimaryKeyConstraint('event_id')
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_table('shopping_webhook_events')
    op.drop_index('ix_price_watches_user_status', table_name='price_watches')
    op.drop_index('ix_price_watches_subscription_id', table_name='price_watches')
    op.drop_index('ix_price_watches_product_id', table_name='price_watches')
    op.drop_index('ix_price_watches_user_id', table_name='price_watches')
    op.drop_table('price_watches')
