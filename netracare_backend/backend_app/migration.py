"""Database migration hooks used at startup."""

from __future__ import annotations

from database_migration import DatabaseMigration


def ensure_user_schema_migrated() -> None:
    """Run idempotent user table migration before serving requests."""
    try:
        migration = DatabaseMigration()
        migration.run(skip_confirmation=True)
    except Exception as exc:
        # Keep startup resilient even if migration logging fails unexpectedly.
        print(f"Warning: user schema migration check failed: {exc}")
