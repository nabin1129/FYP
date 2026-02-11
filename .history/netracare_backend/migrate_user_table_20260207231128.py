"""
Simple database migration script to add new profile fields to User table
This script works directly with SQLite without requiring all app dependencies.

Usage: python migrate_user_table.py
"""

import sqlite3
import os

def migrate_database():
    # Database path
    db_path = os.path.join(os.path.dirname(__file__), 'db.sqlite3')
    
    if not os.path.exists(db_path):
        print(f"❌ Database not found at: {db_path}")
        return
    
    print(f"📁 Database: {db_path}")
    print("="*50)
    
    # Connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Get existing columns
    cursor.execute("PRAGMA table_info(user)")
    existing_columns = [row[1] for row in cursor.fetchall()]
    print(f"Existing columns: {', '.join(existing_columns)}\n")
    
    # Columns to add
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
        if column_name in existing_columns:
            skipped_columns.append(column_name)
            print(f"⏭️  Column '{column_name}' already exists, skipping...")
        else:
            try:
                cursor.execute(f"ALTER TABLE user ADD COLUMN {column_name} {column_type}")
                conn.commit()
                added_columns.append(column_name)
                print(f"✅ Added column: {column_name}")
            except Exception as e:
                print(f"❌ Error adding column {column_name}: {e}")
                conn.rollback()
    
    conn.close()
    
    print("\n" + "="*50)
    if added_columns:
        print(f"✅ Successfully added {len(added_columns)} column(s):")
        for col in added_columns:
            print(f"   - {col}")
    
    if skipped_columns:
        print(f"⏭️  Skipped {len(skipped_columns)} existing column(s):")
        for col in skipped_columns:
            print(f"   - {col}")
    
    if not added_columns and not skipped_columns:
        print("ℹ️  No changes needed.")
    
    print("="*50)
    print("✅ Migration completed!")
    print("\n🚀 You can now restart your Flask server.")

if __name__ == "__main__":
    print("Starting database migration...")
    print("="*50)
    migrate_database()
