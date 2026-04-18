"""Application settings helpers."""

from __future__ import annotations

from pathlib import Path

from core.config import BaseConfig, get_config_class


BASE_DIR = Path(__file__).resolve().parents[1]
DB_PATH = BASE_DIR / "db.sqlite3"


def apply_app_config(app) -> None:
    """Apply standard Flask config values."""
    app.config.from_object(get_config_class())
    app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{DB_PATH}"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

    # Production-like environments must not use known default secrets.
    is_production_like = not app.config.get("DEBUG", False) and not app.config.get(
        "TESTING", False
    )
    if is_production_like:
        secret = str(app.config.get("SECRET_KEY", ""))
        if not secret or secret == BaseConfig.DEFAULT_SECRET_KEY or len(secret) < 32:
            raise RuntimeError(
                "Invalid SECRET_KEY for production. Configure a non-default key "
                "with at least 32 characters."
            )


def _parse_allowed_origins(raw_origins: str):
    cleaned = [origin.strip() for origin in (raw_origins or "").split(",") if origin.strip()]
    return cleaned or ["*"]


def apply_cors(app) -> None:
    """Apply CORS policy for Flutter and API clients."""
    from flask_cors import CORS

    origins = _parse_allowed_origins(app.config.get("CORS_ALLOWED_ORIGINS", "*"))

    CORS(
        app,
        resources={
            r"/*": {
                "origins": origins,
                "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
                "allow_headers": ["Content-Type", "Authorization"],
            }
        },
    )
