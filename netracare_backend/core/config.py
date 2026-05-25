"""Application configuration profiles."""

from __future__ import annotations

import os


def load_dotenv_file() -> None:
    """Load a local .env file if `python-dotenv` is available.

    This function is intentionally not called at import time; callers (such
    as the app factory) should decide when to load a `.env` file (for
    example, only in development).
    """
    try:
        from dotenv import load_dotenv
    except Exception:
        return

    try:
        load_dotenv()
    except Exception:
        # Best-effort: do not raise if dotenv fails to parse a file.
        return


class BaseConfig:
    """Base configuration shared by all environments."""

    DEFAULT_SECRET_KEY = "dev-secret-key-change-in-production-min-32-bytes-required"
    SECRET_KEY = os.getenv("SECRET_KEY", DEFAULT_SECRET_KEY)
    JWT_EXP_MINUTES = 1440
    ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin333221")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
    CORS_ALLOWED_ORIGINS = os.getenv("CORS_ALLOWED_ORIGINS", "*")
    SQLALCHEMY_TRACK_MODIFICATIONS = False


class DevelopmentConfig(BaseConfig):
    """Development-friendly config."""

    DEBUG = True


class TestingConfig(BaseConfig):
    """Test environment config."""

    TESTING = True
    DEBUG = False


class ProductionConfig(BaseConfig):
    """Production-safe config."""

    DEBUG = False
    TESTING = False


CONFIG_BY_NAME = {
    "development": DevelopmentConfig,
    "dev": DevelopmentConfig,
    "testing": TestingConfig,
    "test": TestingConfig,
    "production": ProductionConfig,
    "prod": ProductionConfig,
}


def get_config_class():
    """Return the config class selected by environment variable."""
    name = os.getenv("NETRACARE_CONFIG", os.getenv("FLASK_ENV", "development")).lower()
    return CONFIG_BY_NAME.get(name, DevelopmentConfig)
