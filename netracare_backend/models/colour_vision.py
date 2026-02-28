"""
Colour Vision Test Model
Ishihara-based colorblindness detection
"""
from datetime import datetime
import json
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db


class ColourVisionTest(db.Model):
    """Colour Vision Test (Ishihara plates)"""
    __tablename__ = 'colour_vision_tests'
    
    # Primary Key
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    
    # Test Configuration
    total_plates = db.Column(db.Integer, default=24)
    test_duration = db.Column(db.Integer)  # seconds
    
    # Results
    correct_answers = db.Column(db.Integer)
    accuracy_percentage = db.Column(db.Float)
    
    # Deficiency Detection
    colorblind_type = db.Column(db.String(30))  # 'normal', 'red_green', 'blue_yellow', 'monochromacy'
    severity = db.Column(db.String(20))  # 'mild', 'moderate', 'severe'
    
    # Specific Deficiencies
    protanopia = db.Column(db.Boolean, default=False)  # Red deficiency
    deuteranopia = db.Column(db.Boolean, default=False)  # Green deficiency
    tritanopia = db.Column(db.Boolean, default=False)  # Blue deficiency
    protanomaly = db.Column(db.Boolean, default=False)  # Weak red
    deuteranomaly = db.Column(db.Boolean, default=False)  # Weak green
    tritanomaly = db.Column(db.Boolean, default=False)  # Weak blue
    
    # Detailed Answers (JSON)
    answers_log = db.Column(db.Text)  # JSON string
    
    # AI Analysis
    confidence_score = db.Column(db.Float)
    recommendations = db.Column(db.Text)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    
    def set_answers_log(self, answers_list):
        """Set answers log from list"""
        self.answers_log = json.dumps(answers_list)
    
    def get_answers_log(self):
        """Get answers log as list"""
        return json.loads(self.answers_log) if self.answers_log else []
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'total_plates': self.total_plates,
            'correct_answers': self.correct_answers,
            'accuracy_percentage': self.accuracy_percentage,
            'colorblind_type': self.colorblind_type,
            'severity': self.severity,
            'protanopia': self.protanopia,
            'deuteranopia': self.deuteranopia,
            'tritanopia': self.tritanopia,
            'protanomaly': self.protanomaly,
            'deuteranomaly': self.deuteranomaly,
            'tritanomaly': self.tritanomaly,
            'confidence_score': self.confidence_score,
            'recommendations': self.recommendations,
            'test_duration': self.test_duration,
            'answers_log': self.get_answers_log(),
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
    
    def __repr__(self):
        return f'<ColourVisionTest {self.id} - {self.colorblind_type}>'
