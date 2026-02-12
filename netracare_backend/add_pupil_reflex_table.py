"""
Database migration to add pupil_reflex_tests table
Run this script to create the table: python add_pupil_reflex_table.py
"""

import os
import sys
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

# Initialize Flask app with minimal config
app = Flask(__name__)
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{os.path.join(BASE_DIR, 'db.sqlite3')}"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# Define only the models we need for this migration
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)

class PupilReflexTest(db.Model):
    """Database model for pupil reflex test records"""
    __tablename__ = 'pupil_reflex_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Test measurements
    reaction_time = db.Column(db.Float, nullable=False)
    constriction_amplitude = db.Column(db.String(50))
    symmetry = db.Column(db.String(50))
    
    # Additional metrics
    left_pupil_size_before = db.Column(db.Float)
    left_pupil_size_after = db.Column(db.Float)
    right_pupil_size_before = db.Column(db.Float)
    right_pupil_size_after = db.Column(db.Float)
    
    # Test metadata
    test_duration = db.Column(db.Float)
    image_filename = db.Column(db.String(255))
    
    # Status
    status = db.Column(db.String(50), default='completed')
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('pupil_reflex_tests', lazy=True))

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
