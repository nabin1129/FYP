"""
Eye Tracking Session Model
Wrapper for existing camera_eye_tracking_sessions table
"""
from datetime import datetime
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db


class EyeTrackingSession(db.Model):
    """Eye movement tracking session (saccades, pursuits, microsaccades)"""
    __tablename__ = 'camera_eye_tracking_sessions'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), index=True)
    
    # Session metadata
    session_duration = db.Column(db.Float)
    frames_processed = db.Column(db.Integer)
    
    # Eye movement metrics (existing columns)
    # Add other columns as they exist in your current table
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'session_duration': self.session_duration,
            'frames_processed': self.frames_processed,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
    
    def __repr__(self):
        return f'<EyeTrackingSession {self.id}>'
