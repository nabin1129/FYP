"""SocketIO events for realtime consultation chat."""

from __future__ import annotations

from flask import request
from flask_socketio import SocketIO, disconnect, emit, join_room, leave_room

from db_model import db

from .auth import ChatActor, ChatAuthError, resolve_actor_from_token
from .service import (
    ChatServiceError,
    consultation_room_id,
    create_message,
    ensure_consultation_access,
    mark_messages_read,
)

ACTIVE_CONNECTIONS: dict[str, dict] = {}


def _actor_from_state(state: dict) -> ChatActor:
    return ChatActor(role=state["role"], actor_id=state["actor_id"])



def _socket_error(message: str, code: str = "chat_error") -> None:
    emit("chat_error", {"code": code, "message": message})



def register_chat_socket_events(socketio: SocketIO) -> None:
    """Bind chat event handlers to the shared SocketIO instance."""

    @socketio.on("connect")
    def on_connect(auth):
        try:
            token = (auth or {}).get("token")
            actor = resolve_actor_from_token(token)
            ACTIVE_CONNECTIONS[request.sid] = {
                "role": actor.role,
                "actor_id": actor.actor_id,
                "rooms": set(),
            }
            emit("connected", {"role": actor.role, "actor_id": actor.actor_id})
        except ChatAuthError as exc:
            emit("chat_error", {"code": "auth_error", "message": str(exc)})
            disconnect()

    @socketio.on("disconnect")
    def on_disconnect():
        state = ACTIVE_CONNECTIONS.pop(request.sid, None)
        if not state:
            return
        for room_id in state["rooms"]:
            leave_room(room_id)

    @socketio.on("join_room")
    def on_join_room(data):
        try:
            state = ACTIVE_CONNECTIONS.get(request.sid)
            if not state:
                _socket_error("Unauthenticated socket", "auth_error")
                disconnect()
                return

            consultation_id = int((data or {}).get("consultation_id") or 0)
            if not consultation_id:
                _socket_error("consultation_id is required", "validation_error")
                return

            actor = (
                resolve_actor_from_token((data or {}).get("token", ""))
                if (data or {}).get("token")
                else _actor_from_state(state)
            )

            consultation = ensure_consultation_access(actor, consultation_id)
            room_id = consultation_room_id(consultation.id)
            join_room(room_id)
            state["rooms"].add(room_id)
            emit(
                "room_joined",
                {"room_id": room_id, "consultation_id": consultation.id, "status": consultation.status},
            )
        except (ValueError, TypeError):
            _socket_error("consultation_id must be an integer", "validation_error")
        except ChatServiceError as exc:
            _socket_error(str(exc), "authorization_error")
        except Exception as exc:
            _socket_error(f"Unable to join room: {str(exc)}")

    @socketio.on("send_message")
    def on_send_message(data):
        try:
            state = ACTIVE_CONNECTIONS.get(request.sid)
            if not state:
                _socket_error("Unauthenticated socket", "auth_error")
                disconnect()
                return

            consultation_id = int((data or {}).get("consultation_id") or 0)
            if not consultation_id:
                _socket_error("consultation_id is required", "validation_error")
                return

            actor = _actor_from_state(state)
            consultation = ensure_consultation_access(actor, consultation_id)
            message = create_message(
                actor,
                consultation,
                content=(data or {}).get("content", ""),
                message_type=(data or {}).get("message_type", "text"),
            )

            room_id = consultation_room_id(consultation.id)
            payload = message.to_dict()
            temp_id = (data or {}).get("temp_id")
            if temp_id:
                payload["temp_id"] = str(temp_id)

            socketio.emit("new_message", payload, room=room_id)
            emit("message_sent", payload)
        except (ValueError, TypeError):
            _socket_error("Invalid message payload", "validation_error")
        except ChatServiceError as exc:
            _socket_error(str(exc), "domain_error")
        except Exception as exc:
            db.session.rollback()
            _socket_error(f"Failed to send message: {str(exc)}")

    @socketio.on("typing_start")
    def on_typing_start(data):
        state = ACTIVE_CONNECTIONS.get(request.sid)
        consultation_id = int((data or {}).get("consultation_id") or 0)
        if not state or not consultation_id:
            return

        room_id = consultation_room_id(consultation_id)
        emit(
            "typing",
            {
                "consultation_id": consultation_id,
                "sender_role": state["role"],
                "is_typing": True,
            },
            room=room_id,
            include_self=False,
        )

    @socketio.on("typing_stop")
    def on_typing_stop(data):
        state = ACTIVE_CONNECTIONS.get(request.sid)
        consultation_id = int((data or {}).get("consultation_id") or 0)
        if not state or not consultation_id:
            return

        room_id = consultation_room_id(consultation_id)
        emit(
            "typing",
            {
                "consultation_id": consultation_id,
                "sender_role": state["role"],
                "is_typing": False,
            },
            room=room_id,
            include_self=False,
        )

    @socketio.on("mark_read")
    def on_mark_read(data):
        try:
            state = ACTIVE_CONNECTIONS.get(request.sid)
            if not state:
                return

            consultation_id = int((data or {}).get("consultation_id") or 0)
            if not consultation_id:
                return

            actor = _actor_from_state(state)
            consultation = ensure_consultation_access(actor, consultation_id)
            message_ids = (data or {}).get("message_ids") or []
            updated_ids = mark_messages_read(actor, consultation, message_ids)

            if not updated_ids:
                return

            room_id = consultation_room_id(consultation.id)
            payload = {
                "consultation_id": consultation.id,
                "message_ids": updated_ids,
                "reader_role": state["role"],
            }
            socketio.emit("messages_read", payload, room=room_id)
        except Exception:
            db.session.rollback()
