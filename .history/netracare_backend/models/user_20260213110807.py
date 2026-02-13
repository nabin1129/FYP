"""
User Model - Enhanced with Medical History
Handles user authentication, profile, and medical information
"""
from datetime import datetime
from models import db
from werkzeug.security import generate_password_hash, check_password_hash


class User(db.Model):
    """User model with comprehensive medical history"""
    __tablename__ = 'users'
    
    # Primary Key
    id = db.Column(db.Integer, primary_key=True)
    
    # Authentication
    username = db.Column(db.String(80), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    
    # Personal Information
    full_name = db.Column(db.String(100))
    date_of_birth = db.Column(db.Date)
    gender = db.Column(db.String(10))
    phone = db.Column(db.String(20))
    
    # Medical History
    has_glasses = db.Column(db.Boolean, default=False)
    has_eye_disease = db.Column(db.Boolean, default=False)
    eye_disease_details = db.Column(db.Text)
    family_history = db.Column(db.Text)
    current_medications = db.Column(db.Text)
    allergies = db.Column(db.Text)
    
    # Settings
    preferred_language = db.Column(db.String(10), default='en')
    notification_enabled = db.Column(db.Boolean, default=True)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    # Relationships
    visual_acuity_tests = db.relationship('VisualAcuityTest', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    colour_vision_tests = db.relationship('ColourVisionTest', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    pupil_reflex_tests = db.relationship('PupilReflexTest', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    blink_fatigue_tests = db.relationship('BlinkFatigueTest', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    eye_tracking_sessions = db.relationship('EyeTrackingSession', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    distance_calibrations = db.relationship('DistanceCalibration', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    ai_reports = db.relationship('AIReport', backref='user', lazy='dynamic', cascade='all, delete-orphan')
    
    def set_password(self, password):
        """Hash and set password"""
        self.password_hash = generate_password_hash(password)
    
    def check_password(self, password):
        """Verify password"""
        return check_password_hash(self.password_hash, password)
    
    def to_dict(self, include_sensitive=False):
        """Convert to dictionary"""
        data = {
            'id': self.id,
            'username': self.username,
            'email': self.email,
            'full_name': self.full_name,
            'date_of_birth': self.date_of_birth.isoformat() if self.date_of_birth else None,
            'gender': self.gender,
            'phone': self.phone,
            'has_glasses': self.has_glasses,
            'has_eye_disease': self.has_eye_disease,
            'preferred_language': self.preferred_language,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'last_login': self.last_login.isoformat() if self.last_login else None,
        }
        
        if include_sensitive:
            data.update({
                'eye_disease_details': self.eye_disease_details,
                'family_history': self.family_history,
                'current_medications': self.current_medications,
                'allergies': self.allergies,
            })
        
        return data
    
    def __repr__(self):
        return f'<User {self.username}>'
