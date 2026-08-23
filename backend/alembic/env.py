import sys
from logging.config import fileConfig
from pathlib import Path
from sqlalchemy import engine_from_config, pool
from alembic import context

# Ajout du chemin backend au sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.database import Base
from app.config import settings
# Import de tous les modèles pour la détection autogenerate
from app.models import (
    UserModel,
    SikaActionModel,
    ConnectedWalletModel,
    SavingsGoalModel,
    AgentMemoryModel,
    UserPreferenceModel,
    SikaActionEventModel,
    SikaSessionModel,
)


# Configuration Alembic
config = context.config

# Logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Métadonnées cibles pour Alembic
target_metadata = Base.metadata


def get_url():
    """Récupère l'URL de connexion depuis app.config.settings ou alembic.ini."""
    return settings.DATABASE_URL or config.get_main_option("sqlalchemy.url")


def run_migrations_offline() -> None:
    """Exécution des migrations en mode offline (génération SQL sans connexion)."""
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        render_as_batch=True
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Exécution des migrations en mode online avec connexion à la base."""
    configuration = config.get_section(config.config_ini_section, {})
    configuration["sqlalchemy.url"] = get_url()

    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=True
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
