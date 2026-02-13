"""
Pupil Reflex Test Model
Flash-based pupil response with Nystagmus detection
"""
from datetime import datetime
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db


class PupilReflexTest(db.Model):
    """Pupil Reflex Test with AI-based Nystagmus detection"""
    __tablename__ = 'pupil_reflex_tests'
    
    # Primary Key
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    
    # Left Eye Pupil Data
    left_pupil_initial_size = db.Column(db.Float)  # mm diameter
    left_pupil_constricted_size = db.Column(db.Float)
    left_pupil_reaction_time = db.Column(db.Float)  # milliseconds
    left_constriction_percentage = db.Column(db.Float)
    
    # Right Eye Pupil Data
    right_pupil_initial_size = db.Column(db.Float)
    right_pupil_constricted_size = db.Column(db.Float)
    right_pupil_reaction_time = db.Column(db.Float)
    right_constriction_percentage = db.Column(db.Float)
    
    # Reflex Analysis
    normal_reflex_left = db.Column(db.Boolean, default=True)
    normal_reflex_right = db.Column(db.Boolean, default=True)
    reflex_symmetry = db.Column(db.Boolean, default=True)
    
    # Nystagmus Detection (AI-based)
    nystagmus_detected = db.Column(db.Boolean, default=False, index=True)
    nystagmus_type = db.Column(db.String(50))  # 'horizontal', 'vertical', 'rotary', 'mixed'
    nystagmus_severity = db.Column(db.String(20))  # 'mild', 'moderate', 'severe'
    nystagmus_frequency = db.Column(db.Float)  # oscillations per second
    nystagmus_confidence = db.Column(db.Float)  # AI confidence score
    
    # Abnormalities
    abnormal_reflex = db.Column(db.Boolean, default=False)
    abnormality_details = db.Column(db.Text)
    requires_neurologist = db.Column(db.Boolean, default=False)
    
    # Video Analysis
    video_path = db.Column(db.String(255))
    video_duration = db.Column(db.Float)  # seconds
    frames_analyzed = db.Column(db.Integer)
    fps = db.Column(db.Integer)
    
    # Test Environment
    flash_intensity = db.Column(db.String(20))  # 'low', 'medium', 'high'
    ambient_light = db.Column(db.String(20))
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'left_pupil_initial_size': self.left_pupil_initial_size,
            'left_pupil_constricted_size': self.left_pupil_constricted_size,
            'left_pupil_reaction_time': self.left_pupil_reaction_time,
            'left_constriction_percentage': self.left_constriction_percentage,
            'right_pupil_initial_size': self.right_pupil_initial_size,
            'right_pupil_constricted_size': self.right_pupil_constricted_size,
            'right_pupil_reaction_time': self.right_pupil_reaction_time,
            'right_constriction_percentage': self.right_constriction_percentage,
            'normal_reflex_left': self.normal_reflex_left,
            'normal_reflex_right': self.normal_reflex_right,
            'reflex_symmetry': self.reflex_symmetry,
            'nystagmus_detected': self.nystagmus_detected,
            'nystagmus_type': self.nystagmus_type,
            'nystagmus_severity': self.nystagmus_severity,
            'nystagmus_frequency': self.nystagmus_frequency,
            'nystagmus_confidence': self.nystagmus_confidence,
            'abnormal_reflex': self.abnormal_reflex,
            'abnormality_details': self.abnormality_details,
            'requires_neurologist': self.requires_neurologist,
            'video_path': self.video_path,
            'video_duration': self.video_duration,
            'frames_analyzed': self.frames_analyzed,
            'fps': self.fps,
            'flash_intensity': self.flash_intensity,
            'ambient_light': self.ambient_light,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
    
    def __repr__(self):
        return f'<PupilReflexTest {self.id} - Nystagmus: {self.nystagmus_detected}>'
