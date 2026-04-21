"""Authentication helpers for chat REST and socket handlers."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

import jwt
from flask import request

from core.config import BaseConfig
from db_model import db, User
from models.doctor import Doctor


@dataclass
class ChatActor:
    """Resolved actor identity for chat access control."""

    role: str
    actor_id: int
    user: Optional[User] = None
    doctor: Optional[Doctor] = None


class ChatAuthError(Exception):
    """Raised when chat token is invalid or missing."""



def _decode_token(token: str) -> dict:
    return jwt.decode(token, BaseConfig.SECRET_KEY, algorithms=["HS256"], leeway=30)



def resolve_actor_from_token(token: str) -> ChatActor:
    """Resolve a chat actor from either patient or doctor JWT."""
    if not token:
        raise ChatAuthError("Token is required")

    try:
        payload = _decode_token(token)
    except jwt.ExpiredSignatureError as exc:
        raise ChatAuthError("Token expired") from exc
    except jwt.InvalidTokenError as exc:
        raise ChatAuthError("Invalid token") from exc

    if payload.get("type") == "admin":
        raise ChatAuthError("Admin tokens are not allowed for chat")

    if payload.get("type") == "doctor":
        doctor_id = payload.get("doctor_id")
        if not doctor_id:
            raise ChatAuthError("Invalid doctor token")
        doctor = db.session.get(Doctor, int(doctor_id))
        if not doctor or not doctor.is_active:
            raise ChatAuthError("Doctor not found or inactive")
        return ChatActor(role="doctor", actor_id=doctor.id, doctor=doctor)

    user_id = payload.get("sub")
    if not user_id:
        raise ChatAuthError("Invalid user token")

    try:
        user_id_int = int(user_id)
    except (TypeError, ValueError) as exc:
        raise ChatAuthError("Invalid user token") from exc

    user = db.session.get(User, user_id_int)
    if not user:
        raise ChatAuthError("User not found")

    return ChatActor(role="patient", actor_id=user.id, user=user)



def extract_bearer_from_request() -> str:
    """Extract bearer token from request headers."""
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise ChatAuthError("Authorization token missing")
    return auth_header.split(" ", 1)[1]
