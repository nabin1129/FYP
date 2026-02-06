# config.py
import os


class Config:
    """Application configuration"""
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")
    JWT_EXP_MINUTES = 1440  # 24 hours (1440 minutes) for better user experience


# Also export as module-level variables for backward compatibility
SECRET_KEY = Config.SECRET_KEY
JWT_EXP_MINUTES = Config.JWT_EXP_MINUTES
