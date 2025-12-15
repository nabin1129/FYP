# auth_utils.py
from functools import wraps
from flask import request
import jwt

from db_model import User
from config import SECRET_KEY


def token_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")

        if not auth.startswith("Bearer "):
            return {"error": "Authorization token missing"}, 401

        token = auth.split(" ", 1)[1]

        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            user = User.query.get(payload["sub"])

            if not user:
                return {"error": "User not found"}, 401

            return fn(user, *args, **kwargs)

        except jwt.ExpiredSignatureError:
            return {"error": "Token expired"}, 401
        except jwt.InvalidTokenError:
            return {"error": "Invalid token"}, 401

    return wrapper


def get_user_from_auth():
    """Extract user from Authorization header. Returns User object or None."""
    auth = request.headers.get("Authorization", "")

    if not auth.startswith("Bearer "):
        return None

    token = auth.split(" ", 1)[1]

    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        user = User.query.get(payload["sub"])
        return user
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None
