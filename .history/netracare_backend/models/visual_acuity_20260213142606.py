"""
Visual Acuity Test Model
Supports Snellen, Tumbling E, and Landolt C tests
"""
from datetime import datetime
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db


class VisualAcuityTest(db.Model):
    """Visual Acuity Test results with AI analysis"""
    __tablename__ = 'visual_acuity_tests'
    
    # Primary Key
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    
    # Test Configuration
    test_type = db.Column(db.String(20), nullable=False)  # 'snellen', 'tumbling_e', 'landolt_c'
    test_distance = db.Column(db.Float, default=1.0)  # meters
    device_calibrated = db.Column(db.Boolean, default=False)
    calibration_method = db.Column(db.String(30))  # 'arcore', 'arkit', 'manual'
    screen_size_inches = db.Column(db.Float)
    device_model = db.Column(db.String(100))
    
    # Test Results per Eye
    left_eye_score = db.Column(db.String(10))  # e.g., "20/20", "6/6"
    right_eye_score = db.Column(db.String(10))
    both_eyes_score = db.Column(db.String(10))
    
    # Detailed Metrics
    correct_answers = db.Column(db.Integer)
    total_questions = db.Column(db.Integer)
    accuracy_percentage = db.Column(db.Float)
    smallest_line_read = db.Column(db.Integer)  # Line number (1-11 for Snellen)
    
    # AI Analysis
    condition_detected = db.Column(db.String(50))  # 'normal', 'myopia', 'hyperopia', 'blurry'
    severity = db.Column(db.String(20))  # 'mild', 'moderate', 'severe'
    confidence_score = db.Column(db.Float)
    recommended_action = db.Column(db.Text)
    
    # Testing Environment
    ambient_light_level = db.Column(db.String(20))  # 'low', 'medium', 'high'
    user_distance_cm = db.Column(db.Float)
    
    # Metadata
    test_duration = db.Column(db.Integer)  # seconds
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'test_type': self.test_type,
            'test_distance': self.test_distance,
            'device_calibrated': self.device_calibrated,
            'left_eye_score': self.left_eye_score,
            'right_eye_score': self.right_eye_score,
            'both_eyes_score': self.both_eyes_score,
            'correct_answers': self.correct_answers,
            'total_questions': self.total_questions,
            'accuracy_percentage': self.accuracy_percentage,
            'smallest_line_read': self.smallest_line_read,
            'condition_detected': self.condition_detected,
            'severity': self.severity,
            'confidence_score': self.confidence_score,
            'recommended_action': self.recommended_action,
            'test_duration': self.test_duration,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
    
    def __repr__(self):
        return f'<VisualAcuityTest {self.id} - {self.test_type}>'
