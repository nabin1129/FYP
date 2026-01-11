from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
import json

db = SQLAlchemy()

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120))
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    age = db.Column(db.Integer)
    sex = db.Column(db.String(20))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class EyeTrackingTest(db.Model):
    """Database model for eye tracking test records"""
    __tablename__ = 'eye_tracking_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    test_name = db.Column(db.String(255), nullable=False)
    test_duration = db.Column(db.Float, nullable=False)  # in seconds
    
    # Metrics
    gaze_accuracy = db.Column(db.Float)  # percentage
    fixation_stability_score = db.Column(db.Float)  # 0-100
    saccade_consistency_score = db.Column(db.Float)  # 0-100
    overall_performance_score = db.Column(db.Float)  # 0-100
    performance_classification = db.Column(db.String(50))  # Excellent, Good, Fair, Poor
    
    # Pupil metrics (stored as JSON)
    left_pupil_metrics = db.Column(db.Text)  # JSON string
    right_pupil_metrics = db.Column(db.Text)  # JSON string
    
    # Raw data (stored as JSON for detailed analysis)
    raw_data = db.Column(db.Text)  # JSON string containing all data points
    
    # Screen resolution
    screen_width = db.Column(db.Integer)
    screen_height = db.Column(db.Integer)
    
    # Status and timestamps
    status = db.Column(db.String(50), default='completed')  # pending, completed, failed
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('eye_tracking_tests', lazy=True))
    
    def set_pupil_metrics(self, left_metrics: dict, right_metrics: dict) -> None:
        """Store pupil metrics as JSON"""
        self.left_pupil_metrics = json.dumps(left_metrics)
        self.right_pupil_metrics = json.dumps(right_metrics)
    
    def get_pupil_metrics(self) -> dict:
        """Retrieve pupil metrics from JSON"""
        return {
            'left_pupil': json.loads(self.left_pupil_metrics) if self.left_pupil_metrics else None,
            'right_pupil': json.loads(self.right_pupil_metrics) if self.right_pupil_metrics else None
        }
    
    def set_raw_data(self, data_points: list) -> None:
        """Store raw eye tracking data as JSON"""
        self.raw_data = json.dumps(data_points)
    
    def get_raw_data(self) -> list:
        """Retrieve raw eye tracking data from JSON"""
        return json.loads(self.raw_data) if self.raw_data else []
    
    def to_dict(self) -> dict:
        """Convert test record to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'test_name': self.test_name,
            'test_duration': self.test_duration,
            'gaze_accuracy': self.gaze_accuracy,
            'fixation_stability_score': self.fixation_stability_score,
            'saccade_consistency_score': self.saccade_consistency_score,
            'overall_performance_score': self.overall_performance_score,
            'performance_classification': self.performance_classification,
            'pupil_metrics': self.get_pupil_metrics(),
            'screen_width': self.screen_width,
            'screen_height': self.screen_height,
            'status': self.status,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
