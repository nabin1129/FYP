"""
Migration script to add new columns to pupil_reflex_tests table
Adds: eye_tested, test_type, test_date columns
Updates: Makes reaction_time nullable
"""
from app import app, db
from sqlalchemy import text
from datetime import datetime

def migrate_pupil_reflex_table():
    """Add new columns to pupil_reflex_tests table"""
    with app.app_context():
        try:
            # Check if columns already exist
            inspector = db.inspect(db.engine)
            existing_columns = [col['name'] for col in inspector.get_columns('pupil_reflex_tests')]
            
            print("Existing columns:", existing_columns)
            
            with db.engine.connect() as conn:
                # Add eye_tested column if not exists
                if 'eye_tested' not in existing_columns:
                    conn.execute(text("""
                        ALTER TABLE pupil_reflex_tests 
                        ADD COLUMN eye_tested VARCHAR(20) DEFAULT 'both'
                    """))
                    conn.commit()
                    print("✓ Added eye_tested column")
                
                # Add test_type column if not exists
                if 'test_type' not in existing_columns:
                    conn.execute(text("""
                        ALTER TABLE pupil_reflex_tests 
                        ADD COLUMN test_type VARCHAR(50) DEFAULT 'pupil_reflex'
                    """))
                    conn.commit()
                    print("✓ Added test_type column")
                
                # Add test_date column if not exists
                if 'test_date' not in existing_columns:
                    conn.execute(text("""
                        ALTER TABLE pupil_reflex_tests 
                        ADD COLUMN test_date DATETIME
                    """))
                    conn.commit()
                    print("✓ Added test_date column")
                    
                    # Set test_date to created_at for existing records
                    conn.execute(text("""
                        UPDATE pupil_reflex_tests 
                        SET test_date = created_at 
                        WHERE test_date IS NULL
                    """))
                    conn.commit()
                    print("✓ Set test_date for existing records")
            
            print("\n✅ Migration completed successfully!")
            
        except Exception as e:
            print(f"❌ Migration failed: {str(e)}")
            db.session.rollback()

if __name__ == '__main__':
    print("Starting pupil_reflex_tests table migration...")
    migrate_pupil_reflex_table()
