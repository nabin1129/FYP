# auth_utils.py
from functools import wraps
from flask import request
import jwt

from db_model import User
from config import SECRET_KEY


def token_required(fn):
    @wraps(fn)
    def wrapper(self, *args, **kwargs):  # ✅ KEEP self
        auth = request.headers.get("Authorization", "")

        if not auth.startswith("Bearer "):
            return {"error": "Authorization token missing"}, 401

        token = auth.split(" ", 1)[1]

        try:
            payload = jwt.decode(
                token,
                SECRET_KEY,
                algorithms=["HS256"],
                options={"require": ["exp", "iat", "sub"]},
            )

            user_id = int(payload["sub"])
            user = User.query.get(user_id)

            if not user:
                return {"error": "User not found"}, 401

            # ✅ PASS self FIRST, then user
            return fn(self, user, *args, **kwargs)

        except jwt.ExpiredSignatureError:
            return {"error": "Token expired"}, 401
        except jwt.InvalidTokenError:
            return {"error": "Invalid token"}, 401

    return wrapper


# -----------------------------
# REQUIRED BY test.py
# -----------------------------
def get_user_from_auth():
    auth = request.headers.get("Authorization", "")

    if not auth.startswith("Bearer "):
        return None

    token = auth.split(" ", 1)[1]

    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=["HS256"],
            options={"require": ["exp", "iat", "sub"]},
        )

        user_id = int(payload["sub"])
        return User.query.get(user_id)

    except jwt.InvalidTokenError:
        return None
