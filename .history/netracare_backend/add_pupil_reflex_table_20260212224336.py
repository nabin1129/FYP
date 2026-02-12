"""
Database migration to add pupil_reflex_tests table
Run this script to create the table: python add_pupil_reflex_table.py
"""

from app import app, db
from db_model import PupilReflexTest

def add_pupil_reflex_table():
    """Add pupil_reflex_tests table to database"""
    with app.app_context():
        print("Creating pupil_reflex_tests table...")
        
        # Create the table
        db.create_all()
        
        print("✅ pupil_reflex_tests table created successfully!")
        print("\nTable structure:")
        print("- id (Primary Key)")
        print("- user_id (Foreign Key)")
        print("- reaction_time (Float)")
        print("- constriction_amplitude (String)")
        print("- symmetry (String)")
        print("- left_pupil_size_before (Float)")
        print("- left_pupil_size_after (Float)")
        print("- right_pupil_size_before (Float)")
        print("- right_pupil_size_after (Float)")
        print("- test_duration (Float)")
        print("- image_filename (String)")
        print("- status (String)")
        print("- created_at (DateTime)")
        print("- updated_at (DateTime)")

if __name__ == '__main__':
    add_pupil_reflex_table()
