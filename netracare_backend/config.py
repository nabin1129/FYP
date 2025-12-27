# config.py
import os

# config.py
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")
JWT_EXP_MINUTES = 60
