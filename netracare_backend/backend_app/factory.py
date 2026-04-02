"""Flask app factory for NetraCare backend."""

from __future__ import annotations

from flask import Flask

from core.settings import apply_app_config, apply_cors
from core.extensions import init_extensions
from backend_app.api_registry import build_api
from backend_app.web_routes import register_web_routes
from backend_app.migration import ensure_user_schema_migrated
from features.distance_calibration.routes import distance_bp


def create_app() -> Flask:
    """Create and configure Flask application."""
    app = Flask(__name__)

    apply_cors(app)
    apply_app_config(app)
    init_extensions(app)

    build_api(app)
    app.register_blueprint(distance_bp)
    register_web_routes(app)

    # Keep migration behavior consistent with previous startup flow.
    with app.app_context():
        ensure_user_schema_migrated()

    return app

