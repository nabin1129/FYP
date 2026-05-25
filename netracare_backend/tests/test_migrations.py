import os
import sqlite3
import tempfile

import pytest

from alembic import command
from alembic.config import Config


def test_alembic_upgrade_and_tables_exist():
    with tempfile.TemporaryDirectory() as td:
        db_path = os.path.join(td, "test_db.sqlite")
        db_url = f"sqlite:///{db_path}"
        os.environ["SQLALCHEMY_DATABASE_URI"] = db_url

        cfg = Config("netracare_backend/alembic.ini")
        cfg.set_main_option("sqlalchemy.url", db_url)
        cfg.set_main_option("script_location", "netracare_backend/alembic")

        # Apply migrations
        command.upgrade(cfg, "head")

        # Basic verification: tables exist
        con = sqlite3.connect(db_path)
        cur = con.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = {r[0] for r in cur.fetchall()}
        con.close()
        assert "user" in tables
        assert "clinical_reports" in tables


def test_transactional_rollback(tmp_path, monkeypatch):
    # Create a DB via alembic upgrade
    db_file = tmp_path / "txn_test_db.sqlite"
    db_url = f"sqlite:///{db_file}"
    os.environ["SQLALCHEMY_DATABASE_URI"] = db_url

    cfg = Config("netracare_backend/alembic.ini")
    cfg.set_main_option("sqlalchemy.url", db_url)
    cfg.set_main_option("script_location", "netracare_backend/alembic")
    command.upgrade(cfg, "head")

    # Import app factory and db after setting env var
    from backend_app.factory import create_app
    from db_model import User, db
    from core.db_utils import transactional_session

    app = create_app()
    app.config["SQLALCHEMY_DATABASE_URI"] = db_url

    with app.app_context():
        # ensure session bound
        db.session.flush()

        # use transactional helper and force an exception
        try:
            with transactional_session() as session:
                u = User(name="txn-test", email="txn@example.com", password_hash="x")
                session.add(u)
                session.flush()
                raise RuntimeError("force rollback")
        except RuntimeError:
            pass

        # User should not exist after rollback
        found = User.query.filter_by(email="txn@example.com").first()
        assert found is None
