"""Shared Flask-SocketIO instance and bootstrap."""

from __future__ import annotations

from flask_socketio import SocketIO

socketio = SocketIO(cors_allowed_origins="*", async_mode="threading")



def init_socketio(app) -> None:
    """Initialize SocketIO and register chat handlers."""
    socketio.init_app(app)

    from features.chat.socket_events import register_chat_socket_events

    register_chat_socket_events(socketio)
