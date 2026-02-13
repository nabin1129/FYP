"""
Database migration script to add nystagmus detection columns to pupil_reflex_tests table.
This script adds six new columns to support comprehensive nystagmus detection results.
"""

import sqlite3
import os

def migrate_database():
    """Add nystagmus detection columns to pupil_reflex_tests table"""
    
    # Get database path
    db_path = os.path.join(os.path.dirname(__file__), 'db.sqlite3')
    
    if not os.path.exists(db_path):
        print(f"❌ Database not found at: {db_path}")
        return False
    
    try:
        # Connect to database
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        print("🔄 Starting migration: Adding nystagmus detection columns...")
        
        # Check if columns already exist
        cursor.execute("PRAGMA table_info(pupil_reflex_tests)")
        existing_columns = [row[1] for row in cursor.fetchall()]
        
        columns_to_add = [
            ('nystagmus_detected', 'BOOLEAN DEFAULT 0'),
            ('nystagmus_type', 'VARCHAR(50)'),
            ('nystagmus_severity', 'VARCHAR(50)'),
            ('nystagmus_confidence', 'FLOAT'),
            ('diagnosis', 'TEXT'),
            ('recommendations', 'TEXT'),
        ]
        
        added_count = 0
        for column_name, column_type in columns_to_add:
            if column_name not in existing_columns:
                print(f"  Adding column: {column_name} ({column_type})")
                cursor.execute(
                    f"ALTER TABLE pupil_reflex_tests ADD COLUMN {column_name} {column_type}"
                )
                added_count += 1
            else:
                print(f"  ✓ Column already exists: {column_name}")
        
        # Commit changes
        conn.commit()
        
        # Verify columns were added
        cursor.execute("PRAGMA table_info(pupil_reflex_tests)")
        all_columns = cursor.fetchall()
        
        print("\n✅ Migration completed successfully!")
        print(f"   Added {added_count} new columns")
        print(f"   Total columns in table: {len(all_columns)}")
        
        print("\nCurrent table schema:")
        for col in all_columns:
            print(f"  - {col[1]} ({col[2]})")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Migration failed: {str(e)}")
        if 'conn' in locals():
            conn.rollback()
            conn.close()
        return False

if __name__ == '__main__':
    print("=" * 60)
    print("Pupil Reflex Tests - Nystagmus Columns Migration")
    print("=" * 60)
    
    success = migrate_database()
    
    if success:
        print("\n✅ Database migration successful!")
        print("   You can now save complete nystagmus detection results.")
    else:
        print("\n❌ Database migration failed!")
        print("   Please check the error messages above.")
    
    print("=" * 60)
