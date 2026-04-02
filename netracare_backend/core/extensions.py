"""Framework extension initialization."""

from __future__ import annotations

from db_model import db


def init_extensions(app) -> None:
    """Initialize Flask extensions."""
    db.init_app(app)
