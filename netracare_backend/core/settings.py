"""Application settings helpers."""

from __future__ import annotations

from pathlib import Path

from core.config import get_config_class


BASE_DIR = Path(__file__).resolve().parents[1]
DB_PATH = BASE_DIR / "db.sqlite3"


def apply_app_config(app) -> None:
    """Apply standard Flask config values."""
    app.config.from_object(get_config_class())
    app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{DB_PATH}"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False


def apply_cors(app) -> None:
    """Apply CORS policy for Flutter and API clients."""
    from flask_cors import CORS

    CORS(
        app,
        resources={
            r"/*": {
                "origins": ["*"],
                "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
                "allow_headers": ["Content-Type", "Authorization"],
            }
        },
    )
