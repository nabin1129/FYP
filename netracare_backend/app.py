"""Legacy bootstrap module.

This thin entrypoint preserves the historical `python app.py` startup flow,
while the actual wiring now lives in the professional app factory package.
"""

from backend_app.factory import create_app
from db_model import db
from core.socketio_ext import socketio
from backend_app.migration import (
    ensure_consultation_schema_migrated,
    ensure_medical_record_schema_migrated,
    ensure_visual_acuity_schema_migrated,
    ensure_user_schema_migrated,
)


app = create_app()


if __name__ == "__main__":
    with app.app_context():
        # Run repository migrations on real startup (not during tests).
        ensure_user_schema_migrated()
        ensure_consultation_schema_migrated()
        ensure_medical_record_schema_migrated()
        ensure_visual_acuity_schema_migrated()

        # Ensure tables exist for ad-hoc local runs
        db.create_all()

    socketio.run(app, debug=True, use_reloader=False, allow_unsafe_werkzeug=True)
