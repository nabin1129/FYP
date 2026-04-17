"""Legacy bootstrap module.

This thin entrypoint preserves the historical `python app.py` startup flow,
while the actual wiring now lives in the professional app factory package.
"""

from backend_app.factory import create_app
from db_model import db
from core.socketio_ext import socketio


app = create_app()


if __name__ == "__main__":
    with app.app_context():
        db.create_all()

    socketio.run(app, debug=True, use_reloader=False, allow_unsafe_werkzeug=True)
