# config.py
import os


class Config:
    """Application configuration"""
    # Use a consistent secret key (32+ bytes for security)
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production-min-32-bytes-required")
    JWT_EXP_MINUTES = 1440  # 24 hours (1440 minutes) for better user experience


# Also export as module-level variables for backward compatibility
SECRET_KEY = Config.SECRET_KEY
JWT_EXP_MINUTES = Config.JWT_EXP_MINUTES
