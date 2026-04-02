"""Application configuration profiles."""

from __future__ import annotations

import os

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


class BaseConfig:
    """Base configuration shared by all environments."""

    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production-min-32-bytes-required")
    JWT_EXP_MINUTES = 1440
    ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin333221")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
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
