"""Database migration hooks used at startup."""

from __future__ import annotations

import os
import sqlite3

from database_migration import DatabaseMigration


def ensure_user_schema_migrated() -> None:
    """Run idempotent user table migration before serving requests."""
    try:
        migration = DatabaseMigration()
        migration.run(skip_confirmation=True)
    except Exception as exc:
        # Keep startup resilient even if migration logging fails unexpectedly.
        print(f"Warning: user schema migration check failed: {exc}")


def ensure_consultation_schema_migrated() -> None:
    """Run idempotent consultation slot schema updates for existing databases."""
    db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'db.sqlite3')

    if not os.path.exists(db_path):
        return

    conn = None
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS doctor_slots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                doctor_id INTEGER NOT NULL,
                slot_start_at DATETIME NOT NULL,
                location VARCHAR(255),
                is_active BOOLEAN DEFAULT 1,
                is_booked BOOLEAN DEFAULT 0,
                created_at DATETIME,
                updated_at DATETIME,
                FOREIGN KEY (doctor_id) REFERENCES doctors(id)
            )
            """
        )
        cursor.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_doctor_slot_start ON doctor_slots(doctor_id, slot_start_at)"
        )

        cursor.execute("PRAGMA table_info(consultations)")
        consultation_columns = [row[1] for row in cursor.fetchall()]
        if 'doctor_slot_id' not in consultation_columns:
            cursor.execute("ALTER TABLE consultations ADD COLUMN doctor_slot_id INTEGER")
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_consultations_doctor_slot_id ON consultations(doctor_slot_id)"
            )

        conn.commit()
    except Exception as exc:
        print(f"Warning: consultation schema migration check failed: {exc}")
    finally:
        if conn:
            conn.close()


def ensure_visual_acuity_schema_migrated() -> None:
    """Add the visual acuity variant column if it is missing."""
    db_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'db.sqlite3')

    if not os.path.exists(db_path):
        return

    conn = None
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        cursor.execute("PRAGMA table_info(visual_acuity_tests)")
        columns = [row[1] for row in cursor.fetchall()]
        if 'test_variant' not in columns:
            cursor.execute(
                "ALTER TABLE visual_acuity_tests ADD COLUMN test_variant VARCHAR(50) DEFAULT 'snellen'"
            )

        conn.commit()
    except Exception as exc:
        print(f"Warning: visual acuity schema migration check failed: {exc}")
    finally:
        if conn:
            conn.close()
