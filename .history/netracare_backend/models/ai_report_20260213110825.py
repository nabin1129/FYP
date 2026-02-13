"""
AI Report Model
Comprehensive eye health report generation
"""
from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
import json

db = SQLAlchemy()


class AIReport(db.Model):
    """AI-generated comprehensive eye health reports"""
    __tablename__ = 'ai_reports'
    
    # Primary Key
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False, index=True)
    
    # Report Metadata
    report_date = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    report_type = db.Column(db.String(50), default='comprehensive')  # 'comprehensive', 'specific', 'followup'
    report_number = db.Column(db.String(50), unique=True)  # e.g., "NTR-2026-0001"
    
    # Test References
    visual_acuity_test_id = db.Column(db.Integer, db.ForeignKey('visual_acuity_tests.id'))
    eye_tracking_session_id = db.Column(db.Integer, db.ForeignKey('camera_eye_tracking_sessions.id'))
    blink_fatigue_test_id = db.Column(db.Integer, db.ForeignKey('blink_fatigue_tests.id'))
    colour_vision_test_id = db.Column(db.Integer, db.ForeignKey('colour_vision_tests.id'))
    pupil_reflex_test_id = db.Column(db.Integer, db.ForeignKey('pupil_reflex_tests.id'))
    
    # Overall Assessment
    overall_health_score = db.Column(db.Float)  # 0-100 scale
    risk_level = db.Column(db.String(20))  # 'low', 'medium', 'high', 'critical'
    
    # Detected Conditions (JSON Array)
    detected_conditions = db.Column(db.Text)  # JSON string
    
    # AI-Generated Content
    ai_summary = db.Column(db.Text)  # Natural language summary
    detailed_analysis = db.Column(db.Text)
    recommendations = db.Column(db.Text)  # JSON string
    
    # Visual Defects Detected
    has_refractive_error = db.Column(db.Boolean, default=False)
    has_color_deficiency = db.Column(db.Boolean, default=False)
    has_fatigue = db.Column(db.Boolean, default=False)
    has_tracking_issues = db.Column(db.Boolean, default=False)
    has_nystagmus = db.Column(db.Boolean, default=False)
    
    # Consultation Required
    requires_consultation = db.Column(db.Boolean, default=False)
    urgency_level = db.Column(db.String(20))  # 'routine', 'soon', 'urgent', 'emergency'
    specialist_type = db.Column(db.String(50))  # 'optometrist', 'ophthalmologist', 'neurologist'
    
    # Report Files & Data
    pdf_path = db.Column(db.String(255))
    charts_data = db.Column(db.Text)  # JSON string
    
    # Doctor Review Section (for future)
    reviewed_by_doctor = db.Column(db.Boolean, default=False)
    doctor_id = db.Column(db.Integer)
    doctor_notes = db.Column(db.Text)
    doctor_diagnosis = db.Column(db.Text)
    doctor_prescription = db.Column(db.Text)
    doctor_reviewed_at = db.Column(db.DateTime)
    followup_required = db.Column(db.Boolean, default=False)
    followup_date = db.Column(db.Date)
    
    # Report Status
    status = db.Column(db.String(20), default='pending')  # 'pending', 'reviewed', 'archived'
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    visual_acuity_test = db.relationship('VisualAcuityTest', foreign_keys=[visual_acuity_test_id])
    colour_vision_test = db.relationship('ColourVisionTest', foreign_keys=[colour_vision_test_id])
    pupil_reflex_test = db.relationship('PupilReflexTest', foreign_keys=[pupil_reflex_test_id])
    
    def set_detected_conditions(self, conditions_list):
        """Set detected conditions from list"""
        self.detected_conditions = json.dumps(conditions_list)
    
    def get_detected_conditions(self):
        """Get detected conditions as list"""
        return json.loads(self.detected_conditions) if self.detected_conditions else []
    
    def set_recommendations(self, recommendations_list):
        """Set recommendations from list"""
        self.recommendations = json.dumps(recommendations_list)
    
    def get_recommendations(self):
        """Get recommendations as list"""
        return json.loads(self.recommendations) if self.recommendations else []
    
    def set_charts_data(self, charts_dict):
        """Set charts data from dictionary"""
        self.charts_data = json.dumps(charts_dict)
    
    def get_charts_data(self):
        """Get charts data as dictionary"""
        return json.loads(self.charts_data) if self.charts_data else {}
    
    def to_dict(self):
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'report_date': self.report_date.isoformat() if self.report_date else None,
            'report_type': self.report_type,
            'report_number': self.report_number,
            'overall_health_score': self.overall_health_score,
            'risk_level': self.risk_level,
            'detected_conditions': self.get_detected_conditions(),
            'ai_summary': self.ai_summary,
            'detailed_analysis': self.detailed_analysis,
            'recommendations': self.get_recommendations(),
            'has_refractive_error': self.has_refractive_error,
            'has_color_deficiency': self.has_color_deficiency,
            'has_fatigue': self.has_fatigue,
            'has_tracking_issues': self.has_tracking_issues,
            'has_nystagmus': self.has_nystagmus,
            'requires_consultation': self.requires_consultation,
            'urgency_level': self.urgency_level,
            'specialist_type': self.specialist_type,
            'pdf_path': self.pdf_path,
            'charts_data': self.get_charts_data(),
            'reviewed_by_doctor': self.reviewed_by_doctor,
            'doctor_notes': self.doctor_notes,
            'status': self.status,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
    
    def __repr__(self):
        return f'<AIReport {self.report_number} - {self.risk_level}>'
