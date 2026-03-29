# config.py
import os

# Load .env file if present
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


class Config:
    """Application configuration"""
    # Use a consistent secret key (32+ bytes for security)
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-change-in-production-min-32-bytes-required")
    JWT_EXP_MINUTES = 1440  # 24 hours (1440 minutes) for better user experience
    ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "admin")
    ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "admin333221")
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")


# Also export as module-level variables for backward compatibility
SECRET_KEY = Config.SECRET_KEY
JWT_EXP_MINUTES = Config.JWT_EXP_MINUTES
ADMIN_EMAIL = Config.ADMIN_EMAIL
ADMIN_PASSWORD = Config.ADMIN_PASSWORD
GEMINI_API_KEY = Config.GEMINI_API_KEY
