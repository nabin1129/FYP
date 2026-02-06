"""
Database Migration Script
Adds distance_calibrations table to existing NetraCare database
Author: NetraCare Team
Date: January 26, 2026
"""

from flask import Flask
from db_model import db, DistanceCalibration
from config import SECRET_KEY
import os

# Initialize Flask app
app = Flask(__name__)
app.config["SECRET_KEY"] = SECRET_KEY
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{os.path.join(BASE_DIR, 'db.sqlite3')}"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db.init_app(app)

def migrate_database():
    """Create distance_calibrations table"""
    with app.app_context():
        print("🔧 Starting database migration...")
        
        # Create all tables (will only create missing ones)
        db.create_all()
        
        print("✅ Migration complete!")
        print("\nCreated table: distance_calibrations")
        print("\nColumns:")
        print("  - id (PRIMARY KEY)")
        print("  - user_id (FOREIGN KEY → user.id)")
        print("  - calibrated_at (DATETIME)")
        print("  - reference_distance (FLOAT)")
        print("  - baseline_ipd_pixels (FLOAT)")
        print("  - baseline_face_width_pixels (FLOAT)")
        print("  - focal_length (FLOAT)")
        print("  - real_world_ipd (FLOAT)")
        print("  - tolerance_cm (FLOAT)")
        print("  - device_model (VARCHAR)")
        print("  - camera_resolution (VARCHAR)")
        print("  - is_active (BOOLEAN)")
        print("  - created_at (DATETIME)")
        print("  - updated_at (DATETIME)")
        
        # Verify table exists
        inspector = db.inspect(db.engine)
        tables = inspector.get_table_names()
        
        if 'distance_calibrations' in tables:
            print("\n✅ Table 'distance_calibrations' verified")
            
            # Show table info
            columns = inspector.get_columns('distance_calibrations')
            print(f"\nTotal columns: {len(columns)}")
        else:
            print("\n❌ ERROR: Table not created")

if __name__ == "__main__":
    migrate_database()
