"""add profile fields to user

Revision ID: 0003_add_profile_fields
Revises: 0002_add_indexes_and_constraints
Create Date: 2026-05-25 00:20:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_add_profile_fields"
down_revision = "0002_add_indexes_and_constraints"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add first_name, last_name and user_type to user table if missing
    with op.batch_alter_table("user", recreate="always") as batch_op:
        try:
            batch_op.add_column(sa.Column("first_name", sa.String(length=120), nullable=True))
        except Exception:
            pass
        try:
            batch_op.add_column(sa.Column("last_name", sa.String(length=120), nullable=True))
        except Exception:
            pass
        try:
            batch_op.add_column(sa.Column("user_type", sa.String(length=50), nullable=True))
        except Exception:
            pass


def downgrade() -> None:
    with op.batch_alter_table("user", recreate="always") as batch_op:
        try:
            batch_op.drop_column("user_type")
        except Exception:
            pass
        try:
            batch_op.drop_column("last_name")
        except Exception:
            pass
        try:
            batch_op.drop_column("first_name")
        except Exception:
            pass
