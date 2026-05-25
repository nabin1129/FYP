"""Alembic environment for NetraCare.

This file configures Alembic to autogenerate migrations from the
SQLAlchemy metadata defined in `db_model.py`.
"""

from __future__ import annotations

import os
import sys
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context

# allow imports from package root
ROOT = os.path.dirname(os.path.dirname(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from core.settings import DB_PATH  # type: ignore
from db_model import db  # type: ignore

# this is the Alembic Config object, which provides access to the values
# within the .ini file in use.
config = context.config

# Interpret the config file for python logging.
if config.config_file_name is not None:
    try:
        fileConfig(config.config_file_name)
    except Exception:
        pass


def get_sqlalchemy_url() -> str:
    # Prefer explicit env var set by the application or CI.
    url = os.getenv("SQLALCHEMY_DATABASE_URI")
    if url:
        return url
    # Fallback to the default sqlite path used by the app.
    return f"sqlite:///{DB_PATH}"


target_metadata = db.metadata


def run_migrations_offline() -> None:
    url = get_sqlalchemy_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = get_sqlalchemy_url()

    connectable = engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
