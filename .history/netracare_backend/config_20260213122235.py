# config.py
import os
import secrets


class Config:
    """Application configuration"""
    # Generate a secure 32-byte key if not provided
    SECRET_KEY = os.getenv("SECRET_KEY", secrets.token_urlsafe(32))
    JWT_EXP_MINUTES = 1440  # 24 hours (1440 minutes) for better user experience


# Also export as module-level variables for backward compatibility
SECRET_KEY = Config.SECRET_KEY
JWT_EXP_MINUTES = Config.JWT_EXP_MINUTES
