"""
Distance Calibration Model
ARCore/ARKit-based distance measurement for visual acuity tests
"""
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
import json

db = SQLAlchemy()


class DistanceCalibration(db.Model):
    """Distance calibration using AR or manual methods"""
    __tablename__ = 'distance_calibrations'
    
    # Primary Key
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), index=True)
    
    # Calibration Method
    calibration_method = db.Column(db.String(30), nullable=False)  # 'arcore', 'arkit', 'manual', 'credit_card'
    platform = db.Column(db.String(20))  # 'android', 'ios'
    
    # Distance Measurement
    measured_distance_cm = db.Column(db.Float, nullable=False)
    target_distance_cm = db.Column(db.Float, default=100.0)  # Usually 1 meter
    calibration_accuracy = db.Column(db.Float)  # percentage
    
    # Device Information
    device_model = db.Column(db.String(100))
    screen_size_inches = db.Column(db.Float)
    camera_resolution = db.Column(db.String(20))
    
    # Reference Object (for manual calibration)
    reference_object = db.Column(db.String(50))  # 'credit_card', 'ruler', 'a4_paper'
    reference_object_size_cm = db.Column(db.Float)
    
    # AR Session Data
    ar_session_data = db.Column(db.Text)  # JSON data
    tracking_quality = db.Column(db.String(20))
    
    # Validation
    is_validated = db.Column(db.Boolean, default=False)
    validation_timestamp = db.Column(db.DateTime)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    expires_at = db.Column(db.DateTime)  # Calibration validity period
    
    def set_ar_session_data(self, data_dict):
        """Set AR session data from dictionary"""
        self.ar_session_data = json.dumps(data_dict)
    
    def get_ar_session_data(self):
        """Get AR session data as dictionary"""
        return json.loads(self.ar_session_data) if self.ar_session_data else {}
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'calibration_method': self.calibration_method,
            'platform': self.platform,
            'measured_distance_cm': self.measured_distance_cm,
            'target_distance_cm': self.target_distance_cm,
            'calibration_accuracy': self.calibration_accuracy,
            'device_model': self.device_model,
            'screen_size_inches': self.screen_size_inches,
            'camera_resolution': self.camera_resolution,
            'reference_object': self.reference_object,
            'reference_object_size_cm': self.reference_object_size_cm,
            'tracking_quality': self.tracking_quality,
            'is_validated': self.is_validated,
            'validation_timestamp': self.validation_timestamp.isoformat() if self.validation_timestamp else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'expires_at': self.expires_at.isoformat() if self.expires_at else None,
        }
    
    def __repr__(self):
        return f'<DistanceCalibration {self.id} - {self.calibration_method}>'
