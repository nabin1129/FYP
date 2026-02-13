"""
Blink Fatigue Test Model
Wrapper for existing blink_fatigue_tests table
"""
from datetime import datetime
from models import db


class BlinkFatigueTest(db.Model):
    """Blink and Fatigue detection test results"""
    __tablename__ = 'blink_fatigue_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), index=True)
    
    # Existing columns from your current implementation
    blink_count = db.Column(db.Integer)
    duration_seconds = db.Column(db.Integer)
    drowsiness_probability = db.Column(db.Float)
    confidence_score = db.Column(db.Float)
    fatigue_level = db.Column(db.String(50))
    avg_bpm = db.Column(db.Float)
    classification = db.Column(db.String(50))
    total_blinks = db.Column(db.Integer)
    avg_blinks_per_minute = db.Column(db.Float)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'blink_count': self.blink_count,
            'duration_seconds': self.duration_seconds,
            'drowsiness_probability': self.drowsiness_probability,
            'confidence_score': self.confidence_score,
            'fatigue_level': self.fatigue_level,
            'avg_bpm': self.avg_bpm,
            'classification': self.classification,
            'total_blinks': self.total_blinks,
            'avg_blinks_per_minute': self.avg_blinks_per_minute,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
    
    def __repr__(self):
        return f'<BlinkFatigueTest {self.id} - {self.fatigue_level}>'
