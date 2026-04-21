"""Firebase auth helpers for chat participants."""

from __future__ import annotations

from .auth import ChatActor
from .firebase_client import create_custom_token


def firebase_uid_for_actor(actor: ChatActor) -> str:
    return f"{actor.role}:{actor.actor_id}"


def create_chat_firebase_custom_token(actor: ChatActor, consultation_id: int) -> str | None:
    claims = {
        "role": actor.role,
        "actor_id": actor.actor_id,
        "consultation_id": consultation_id,
        "is_admin": False,
        "chat_access": True,
    }
    return create_custom_token(firebase_uid_for_actor(actor), claims)
