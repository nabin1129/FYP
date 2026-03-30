"""
Consultation Model - Consultation Management
Handles consultation booking, history, and messaging
"""
from datetime import datetime
import json
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db


class Consultation(db.Model):
    """Consultation booking and history"""
    __tablename__ = 'consultations'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Participants
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'), nullable=False)
    patient_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Consultation Details
    consultation_type = db.Column(db.String(20), default='video_call')  # video_call, chat
    status = db.Column(db.String(20), default='pending')  # pending, scheduled, in_progress, completed, cancelled
    
    # Scheduling
    requested_at = db.Column(db.DateTime, default=datetime.utcnow)
    scheduled_at = db.Column(db.DateTime)
    started_at = db.Column(db.DateTime)
    ended_at = db.Column(db.DateTime)
    duration_minutes = db.Column(db.Integer, default=30)
    
    # Content
    reason = db.Column(db.Text)
    patient_notes = db.Column(db.Text)
    doctor_notes = db.Column(db.Text)
    diagnosis = db.Column(db.Text)
    prescription = db.Column(db.Text)
    
    # Payment
    fee = db.Column(db.Float, default=0.0)
    is_paid = db.Column(db.Boolean, default=False)
    
    # Attachments - Test results shared during consultation
    shared_test_ids = db.Column(db.Text)  # JSON array of test IDs
    
    # Ratings
    patient_rating = db.Column(db.Integer)
    patient_feedback = db.Column(db.Text)
    
    # Follow-up
    follow_up_required = db.Column(db.Boolean, default=False)
    follow_up_date = db.Column(db.DateTime)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    doctor = db.relationship('Doctor', back_populates='consultations')
    patient = db.relationship('User', backref=db.backref('consultations', lazy='dynamic'))
    messages = db.relationship('ConsultationMessage', back_populates='consultation', lazy='dynamic', cascade='all, delete-orphan')
    
    def get_shared_test_ids(self) -> list:
        """Get shared test IDs as list"""
        return json.loads(self.shared_test_ids) if self.shared_test_ids else []
    
    def set_shared_test_ids(self, test_ids: list):
        """Set shared test IDs from list"""
        self.shared_test_ids = json.dumps(test_ids)
    
    def to_dict(self, include_messages=False) -> dict:
        """Convert to dictionary"""
        data = {
            'id': str(self.id),
            'doctor_id': self.doctor_id,
            'patient_id': self.patient_id,
            'doctorName': self.doctor.name if self.doctor else 'Unknown',
            'type': self._format_type(),
            'status': self.status,
            'date': self._format_date(),
            'scheduled_at': self.scheduled_at.isoformat() if self.scheduled_at else None,
            'duration': f"{self.duration_minutes} min" if self.duration_minutes else 'Not scheduled',
            'reason': self.reason,
            'patient_notes': self.patient_notes,
            'doctor_notes': self.doctor_notes,
            'notes': self.doctor_notes or self.patient_notes or '',
            'diagnosis': self.diagnosis,
            'prescription': self.prescription,
            'fee': self.fee,
            'is_paid': self.is_paid,
            'patient_rating': self.patient_rating,
            'follow_up_required': self.follow_up_required,
            'follow_up_date': self.follow_up_date.isoformat() if self.follow_up_date else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
        
        if include_messages:
            data['messages'] = [m.to_dict() for m in self.messages.order_by(ConsultationMessage.created_at.asc()).all()]
        
        return data
    
    def _format_type(self) -> str:
        """Format consultation type for display"""
        return 'Video Call' if self.consultation_type == 'video_call' else 'Chat'
    
    def _format_date(self) -> str:
        """Format date for display"""
        if self.status == 'pending':
            return f"Requested on {self.requested_at.strftime('%b %d, %Y')}" if self.requested_at else 'Pending'
        elif self.scheduled_at:
            return self.scheduled_at.strftime('%B %d, %Y at %I:%M %p')
        elif self.ended_at:
            return self.ended_at.strftime('%b %d, %Y')
        return 'Not scheduled'
    
    def to_doctor_dict(self) -> dict:
        """Convert to dictionary for doctor view"""
        patient = self.patient
        return {
            'id': str(self.id),
            'patient': {
                'id': str(self.patient_id),
                'name': patient.name if hasattr(patient, 'name') else 'Unknown',
                'email': patient.email,
                'age': patient.age if hasattr(patient, 'age') else None,
            },
            'type': self.consultation_type,  # raw value: 'video_call' or 'chat'
            'status': self.status,
            'scheduled_at': self.scheduled_at.isoformat() if self.scheduled_at else None,
            'duration_minutes': self.duration_minutes,
            'reason': self.reason,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }


class ConsultationMessage(db.Model):
    """Chat messages within a consultation"""
    __tablename__ = 'consultation_messages'
    
    id = db.Column(db.Integer, primary_key=True)
    consultation_id = db.Column(db.Integer, db.ForeignKey('consultations.id'), nullable=False)
    
    # Sender
    sender_type = db.Column(db.String(10), nullable=False)  # 'doctor' or 'patient'
    sender_id = db.Column(db.Integer, nullable=False)
    
    # Message content
    message_type = db.Column(db.String(20), default='text')  # text, image, file, test_result
    content = db.Column(db.Text, nullable=False)
    
    # File attachments
    file_url = db.Column(db.String(500))
    file_name = db.Column(db.String(200))
    
    # Test result reference
    test_type = db.Column(db.String(50))  # visual_acuity, colour_vision, etc.
    test_id = db.Column(db.Integer)
    
    # Status
    is_read = db.Column(db.Boolean, default=False)
    read_at = db.Column(db.DateTime)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    consultation = db.relationship('Consultation', back_populates='messages')
    
    def to_dict(self) -> dict:
        """Convert to dictionary"""
        return {
            'id': str(self.id),
            'consultation_id': self.consultation_id,
            'sender_type': self.sender_type,
            'sender_id': self.sender_id,
            'isFromDoctor': self.sender_type == 'doctor',
            'message_type': self.message_type,
            'content': self.content,
            'file_url': self.file_url,
            'file_name': self.file_name,
            'test_type': self.test_type,
            'test_id': self.test_id,
            'is_read': self.is_read,
            'timestamp': self.created_at.isoformat() if self.created_at else None,
        }
