"""Security and token helper utilities."""

import inspect
from functools import wraps
from datetime import datetime, timedelta

import jwt
from flask import request

from core.config import BaseConfig
from db_model import db, User


def token_required(fn):
    # Detect at decoration time whether this wraps a Resource method (has 'self')
    # or a plain Blueprint view function (no 'self').
    _params = list(inspect.signature(fn).parameters.keys())
    _is_method = bool(_params) and _params[0] == "self"

    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")

        if not auth.startswith("Bearer "):
            return {"error": "Authorization token missing"}, 401

        token = auth.split(" ", 1)[1]

        try:
            payload = jwt.decode(
                token,
                BaseConfig.SECRET_KEY,
                algorithms=["HS256"],
                options={
                    "require": ["exp", "iat", "sub"],
                    "verify_exp": True,
                },
                leeway=30,
            )
            user_id = int(payload["sub"])
            user = db.session.get(User, user_id)

            if not user:
                return {"error": "User not found"}, 401

        except jwt.ExpiredSignatureError as e:
            print(f"Token expired: {e}")
            return {"error": "Token expired"}, 401
        except jwt.InvalidTokenError as e:
            print(f"Invalid token error: {e}")
            return {"error": f"Invalid token: {str(e)}"}, 401
        except Exception as e:
            print(f"Unexpected error during token validation: {e}")
            return {"error": "Token validation failed"}, 401

        if _is_method:
            # Resource.method(self, current_user, *extra_args)
            return fn(args[0], user, *args[1:], **kwargs)

        # Blueprint view function(current_user, *url_args)
        return fn(user, *args, **kwargs)

    return wrapper


def get_user_from_auth():
    auth = request.headers.get("Authorization", "")

    if not auth.startswith("Bearer "):
        return None

    token = auth.split(" ", 1)[1]

    try:
        payload = jwt.decode(
            token,
            BaseConfig.SECRET_KEY,
            algorithms=["HS256"],
            options={
                "require": ["exp", "iat", "sub"],
                "verify_exp": True,
            },
            leeway=30,
        )

        user_id = int(payload["sub"])
        return db.session.get(User, user_id)

    except jwt.InvalidTokenError:
        return None


def generate_admin_token(admin_email: str) -> str:
    """Generate JWT token for admin access."""
    payload = {
        "sub": admin_email,
        "type": "admin",
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + timedelta(hours=24),
    }
    return jwt.encode(payload, BaseConfig.SECRET_KEY, algorithm="HS256")


def admin_token_required(fn):
    """Decorator to protect admin-only endpoints (expects self as first arg)."""

    @wraps(fn)
    def wrapper(self, *args, **kwargs):
        auth = request.headers.get("Authorization", "")

        if not auth.startswith("Bearer "):
            return {"message": "Admin authorization token missing"}, 401

        token = auth.split(" ", 1)[1]

        try:
            payload = jwt.decode(
                token,
                BaseConfig.SECRET_KEY,
                algorithms=["HS256"],
                options={"require": ["exp", "iat", "sub"], "verify_exp": True},
                leeway=30,
            )

            if payload.get("type") != "admin":
                return {"message": "Invalid token type for admin route"}, 403

            current_admin = payload.get("sub")
        except jwt.ExpiredSignatureError:
            return {"message": "Admin token expired"}, 401
        except jwt.InvalidTokenError:
            return {"message": "Invalid admin token"}, 401
        except Exception as e:
            print(f"Unexpected admin token validation error: {e}")
            return {"message": "Admin token validation failed"}, 401

        return fn(self, *args, current_admin=current_admin, **kwargs)

    return wrapper
