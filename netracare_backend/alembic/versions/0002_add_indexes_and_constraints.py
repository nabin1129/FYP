"""add indexes and tighten timestamps

Revision ID: 0002_add_indexes_and_constraints
Revises: 0001_initial
Create Date: 2026-05-25 00:10:00.000000
"""

from alembic import op
import sqlalchemy as sa

revision = "0002_add_indexes_and_constraints"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create indexes on foreign keys
    op.create_index("ix_eye_tracking_tests_user_id", "eye_tracking_tests", ["user_id"])
    op.create_index(
        "ix_visual_acuity_tests_user_id", "visual_acuity_tests", ["user_id"]
    )
    op.create_index(
        "ix_camera_eye_tracking_sessions_user_id",
        "camera_eye_tracking_sessions",
        ["user_id"],
    )
    op.create_index(
        "ix_colour_vision_tests_user_id", "colour_vision_tests", ["user_id"]
    )
    op.create_index(
        "ix_blink_fatigue_tests_user_id", "blink_fatigue_tests", ["user_id"]
    )
    op.create_index(
        "ix_distance_calibrations_user_id", "distance_calibrations", ["user_id"]
    )
    op.create_index("ix_pupil_reflex_tests_user_id", "pupil_reflex_tests", ["user_id"])
    op.create_index(
        "ix_clinical_reports_patient_id", "clinical_reports", ["patient_id"]
    )

    # Tighten created_at columns to non-nullable using batch operations (SQLite-safe)
    tables = [
        "eye_tracking_tests",
        "visual_acuity_tests",
        "camera_eye_tracking_sessions",
        "colour_vision_tests",
        "blink_fatigue_tests",
        "distance_calibrations",
        "pupil_reflex_tests",
        "clinical_reports",
    ]

    for t in tables:
        with op.batch_alter_table(t, recreate="always") as batch_op:
            try:
                batch_op.alter_column(
                    "created_at", existing_type=sa.DateTime(), nullable=False
                )
            except Exception:
                # If column doesn't exist or cannot be altered, skip gracefully.
                pass


def downgrade() -> None:
    for name in [
        "ix_eye_tracking_tests_user_id",
        "ix_visual_acuity_tests_user_id",
        "ix_camera_eye_tracking_sessions_user_id",
        "ix_colour_vision_tests_user_id",
        "ix_blink_fatigue_tests_user_id",
        "ix_distance_calibrations_user_id",
        "ix_pupil_reflex_tests_user_id",
        "ix_clinical_reports_patient_id",
    ]:
        try:
            op.drop_index(name, table_name=None)
        except Exception:
            pass

    # Revert created_at nullability where possible
    for t in [
        "eye_tracking_tests",
        "visual_acuity_tests",
        "camera_eye_tracking_sessions",
        "colour_vision_tests",
        "blink_fatigue_tests",
        "distance_calibrations",
        "pupil_reflex_tests",
        "clinical_reports",
    ]:
        with op.batch_alter_table(t, recreate="always") as batch_op:
            try:
                batch_op.alter_column(
                    "created_at", existing_type=sa.DateTime(), nullable=True
                )
            except Exception:
                pass
