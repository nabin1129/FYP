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
from sqlalchemy import text

def migrate_database():
    with app.app_context():
        columns_to_add = [
            ("phone", "VARCHAR(20)"),
            ("address", "TEXT"),
            ("emergency_contact", "VARCHAR(20)"),
            ("medical_history", "TEXT"),
            ("profile_image_url", "VARCHAR(500)")
        ]
        
        added_columns = []
        skipped_columns = []
        
        for column_name, column_type in columns_to_add:
            try:
                # Check if column exists
                result = db.session.execute(text(f"PRAGMA table_info(user)"))
                columns = [row[1] for row in result]
                
                if column_name in columns:
                    skipped_columns.append(column_name)
                    print(f"⏭️  Column '{column_name}' already exists, skipping...")
                else:
                    # Add column
                    db.session.execute(text(f"ALTER TABLE user ADD COLUMN {column_name} {column_type}"))
                    db.session.commit()
                    added_columns.append(column_name)
                    print(f"✅ Added column: {column_name}")
            except Exception as e:
                print(f"❌ Error adding column {column_name}: {e}")
                db.session.rollback()
        
        print("\n" + "="*50)
        if added_columns:
            print(f"✅ Successfully added {len(added_columns)} column(s):")
            for col in added_columns:
                print(f"   - {col}")
        
        if skipped_columns:
            print(f"⏭️  Skipped {len(skipped_columns)} existing column(s):")
            for col in skipped_columns:
                print(f"   - {col}")
        
        print("="*50)
        print("✅ Migration completed!")

if __name__ == "__main__":
    print("Starting database migration...")
    print("="*50)
    migrate_database()
