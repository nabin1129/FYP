"""
Migration script to add new columns to blink_fatigue_tests table
"""
import sqlite3
import os

# Get the database path
db_path = os.path.join(os.path.dirname(__file__), 'db.sqlite3')

def migrate():
    """Add new columns to blink_fatigue_tests table"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    try:
        # Check if columns exist
        cursor.execute("PRAGMA table_info(blink_fatigue_tests)")
        columns = [col[1] for col in cursor.fetchall()]
        
        # Add total_blinks column if it doesn't exist
        if 'total_blinks' not in columns:
            cursor.execute("""
                ALTER TABLE blink_fatigue_tests 
                ADD COLUMN total_blinks INTEGER
            """)
            print("✓ Added total_blinks column")
        else:
            print("- total_blinks column already exists")
        
        # Add avg_blinks_per_minute column if it doesn't exist
        if 'avg_blinks_per_minute' not in columns:
            cursor.execute("""
                ALTER TABLE blink_fatigue_tests 
                ADD COLUMN avg_blinks_per_minute FLOAT
            """)
            print("✓ Added avg_blinks_per_minute column")
        else:
            print("- avg_blinks_per_minute column already exists")
        
        conn.commit()
        print("\n✓ Migration completed successfully!")
        
    except Exception as e:
        conn.rollback()
        print(f"\n✗ Migration failed: {e}")
        raise
    finally:
        conn.close()

if __name__ == '__main__':
    migrate()
