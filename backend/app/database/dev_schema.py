"""
Mise à niveau légère du schéma en développement.

`Base.metadata.create_all()` crée les tables manquantes mais n'ajoute jamais de colonne à une table
existante. En développement (SQLite local), on ajoute ici les colonnes nullables / avec valeur par
défaut introduites depuis. En production, le schéma est géré exclusivement par Alembic.
"""

import logging

from sqlalchemy import inspect, text

logger = logging.getLogger("SikaDevSchema")

_DEV_COLUMNS = {
    "users": {
        "paypal_payer_id": "VARCHAR(64)",
        "country": "VARCHAR(64)",
        "kyc_status": "VARCHAR(20) NOT NULL DEFAULT 'none'",
        "auto_follow_products": "BOOLEAN NOT NULL DEFAULT 1",
    },
    "price_watches": {
        "source": "VARCHAR(8) NOT NULL DEFAULT 'user'",
        "expires_at": "DATETIME",
        "last_notified_at": "DATETIME",
    },
    "paypal_checkouts": {
        "confirmed_by": "VARCHAR(10)",
    },
}


def ensure_dev_columns(engine) -> None:
    inspector = inspect(engine)
    with engine.begin() as conn:
        for table, columns in _DEV_COLUMNS.items():
            if not inspector.has_table(table):
                continue
            existing = {c["name"] for c in inspector.get_columns(table)}
            for name, ddl in columns.items():
                if name not in existing:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))
                    logger.info(f"[DEV SCHEMA] Colonne ajoutée : {table}.{name}")
