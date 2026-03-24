"""
Migration: Add reset_otp and reset_otp_expiry columns to User table.
Run this once to update an existing database.
"""

import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "db.sqlite3")


def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Check existing columns
    cursor.execute("PRAGMA table_info(user)")
    columns = {row[1] for row in cursor.fetchall()}

    if "reset_otp" not in columns:
        cursor.execute("ALTER TABLE user ADD COLUMN reset_otp VARCHAR(6)")
        print("✅ Added reset_otp column")
    else:
        print("ℹ️  reset_otp column already exists")

    if "reset_otp_expiry" not in columns:
        cursor.execute("ALTER TABLE user ADD COLUMN reset_otp_expiry DATETIME")
        print("✅ Added reset_otp_expiry column")
    else:
        print("ℹ️  reset_otp_expiry column already exists")

    conn.commit()
    conn.close()
    print("\n🎉 Migration complete!")


if __name__ == "__main__":
    migrate()
