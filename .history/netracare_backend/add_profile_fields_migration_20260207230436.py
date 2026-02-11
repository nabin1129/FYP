"""
Database migration script to add new profile fields to User table
Run this script to update the database schema with new user profile fields:
- phone
- address
- emergency_contact
- medical_history
- profile_image_url

Usage: python add_profile_fields_migration.py
"""

from app import app
from db_model import db

def migrate_database():
    with app.app_context():
        try:
            # Add new columns to User table
            db.engine.execute("""
                ALTER TABLE user 
                ADD COLUMN IF NOT EXISTS phone VARCHAR(20),
                ADD COLUMN IF NOT EXISTS address TEXT,
                ADD COLUMN IF NOT EXISTS emergency_contact VARCHAR(20),
                ADD COLUMN IF NOT EXISTS medical_history TEXT,
                ADD COLUMN IF NOT EXISTS profile_image_url VARCHAR(500);
            """)
            print("✅ Migration completed successfully!")
            print("✅ Added columns: phone, address, emergency_contact, medical_history, profile_image_url")
        except Exception as e:
            print(f"❌ Migration failed: {e}")
            print("Note: If columns already exist, this is expected.")

if __name__ == "__main__":
    print("Starting database migration...")
    migrate_database()
