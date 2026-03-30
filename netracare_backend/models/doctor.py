"""
Doctor Model - Professional Doctor Management
Handles doctor profiles, specializations, and patient relationships
"""
from datetime import datetime
import json
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db


class Doctor(db.Model):
    """Doctor model with professional credentials"""
    __tablename__ = 'doctors'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Authentication (can use same User model or separate)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True, unique=True)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    
    # Personal Information
    name = db.Column(db.String(150), nullable=False)
    phone = db.Column(db.String(20))
    profile_image_url = db.Column(db.String(500))
    
    # Professional Credentials
    nhpc_number = db.Column(db.String(50), unique=True, nullable=False)  # Nepal Health Professional Council
    qualification = db.Column(db.String(200), nullable=False)  # MBBS, MD/MS Ophthalmology
    specialization = db.Column(db.String(100), default='Ophthalmology')
    experience_years = db.Column(db.Integer, default=0)
    
    # Work Information
    working_place = db.Column(db.String(200))  # Hospital/Clinic name
    address = db.Column(db.Text)
    
    # Availability
    is_available = db.Column(db.Boolean, default=True)
    availability_schedule = db.Column(db.Text)  # JSON: {"monday": ["09:00-12:00", "14:00-17:00"], ...}
    consultation_fee = db.Column(db.Float, default=0.0)
    
    # Statistics
    rating = db.Column(db.Float, default=0.0)
    total_consultations = db.Column(db.Integer, default=0)
    total_patients = db.Column(db.Integer, default=0)
    
    # Status
    is_verified = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    force_password_change = db.Column(db.Boolean, default=False)  # True for admin-created accounts
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login = db.Column(db.DateTime)
    
    # Relationships
    patients = db.relationship('DoctorPatient', back_populates='doctor', lazy='dynamic')
    consultations = db.relationship('Consultation', back_populates='doctor', lazy='dynamic')
    
    def get_availability_schedule(self) -> dict:
        """Get availability schedule as dictionary"""
        return json.loads(self.availability_schedule) if self.availability_schedule else {}
    
    def set_availability_schedule(self, schedule: dict):
        """Set availability schedule from dictionary"""
        self.availability_schedule = json.dumps(schedule)
    
    def to_dict(self, include_sensitive=False) -> dict:
        """Convert to dictionary"""
        data = {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'phone': self.phone,
            'profile_image_url': self.profile_image_url,
            'nhpc_number': self.nhpc_number,
            'qualification': self.qualification,
            'specialization': self.specialization,
            'experience': f"{self.experience_years} years",
            'experience_years': self.experience_years,
            'working_place': self.working_place,
            'address': self.address,
            'is_available': self.is_available,
            'availability': 'Available Today' if self.is_available else 'Not Available',
            'consultation_fee': self.consultation_fee,
            'rating': self.rating,
            'total_consultations': self.total_consultations,
            'total_patients': self.total_patients,
            'is_verified': self.is_verified,
            'force_password_change': self.force_password_change,
            'created_at': self.created_at.isoformat() if self.created_at else None,
        }
        
        if include_sensitive:
            data['availability_schedule'] = self.get_availability_schedule()
        
        return data
    
    def to_public_dict(self) -> dict:
        """Public profile for patients"""
        return {
            'id': str(self.id),
            'name': self.name,
            'specialization': self.specialization,
            'qualification': self.qualification,
            'experience': f"{self.experience_years} years",
            'rating': self.rating,
            'availability': 'Available Today' if self.is_available else 'Not Available',
            'nextSlot': self._get_next_slot(),
            'image': self.profile_image_url or f'https://i.pravatar.cc/150?img={self.id}',
            'nhpcNumber': self.nhpc_number,
            'workingPlace': self.working_place,
            'contactPhone': self.phone,
            'contactEmail': self.email,
            'address': self.address,
        }
    
    def _get_next_slot(self) -> str:
        """Calculate next available slot (simplified)"""
        if not self.is_available:
            return 'Not Available'
        
        # In a real implementation, this would check the schedule
        schedule = self.get_availability_schedule()
        if schedule:
            import datetime as dt
            today = dt.datetime.now().strftime('%A').lower()
            if today in schedule and schedule[today]:
                return schedule[today][0].split('-')[0]
        
        return '10:00 AM'  # Default fallback


class DoctorPatient(db.Model):
    """Many-to-many relationship between doctors and patients"""
    __tablename__ = 'doctor_patients'
    
    id = db.Column(db.Integer, primary_key=True)
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'), nullable=False)
    patient_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Relationship status
    status = db.Column(db.String(20), default='active')  # active, inactive, pending
    
    # Patient health data (cached for doctor dashboard)
    health_score = db.Column(db.Integer, default=0)
    trend = db.Column(db.String(20), default='stable')  # up, down, stable
    health_status = db.Column(db.String(20), default='good')  # good, attention, critical
    
    # Notes
    doctor_notes = db.Column(db.Text)
    
    # Timestamps
    linked_at = db.Column(db.DateTime, default=datetime.utcnow)
    last_consultation = db.Column(db.DateTime)
    last_test_date = db.Column(db.DateTime)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    doctor = db.relationship('Doctor', back_populates='patients')
    patient = db.relationship('User', backref=db.backref('assigned_doctors', lazy='dynamic'))
    
    # Unique constraint
    __table_args__ = (
        db.UniqueConstraint('doctor_id', 'patient_id', name='unique_doctor_patient'),
    )
    
    def to_dict(self) -> dict:
        """Convert to dictionary"""
        return {
            'id': self.id,
            'doctor_id': self.doctor_id,
            'patient_id': self.patient_id,
            'status': self.status,
            'health_score': self.health_score,
            'trend': self.trend,
            'health_status': self.health_status,
            'doctor_notes': self.doctor_notes,
            'linked_at': self.linked_at.isoformat() if self.linked_at else None,
            'last_consultation': self.last_consultation.isoformat() if self.last_consultation else None,
            'last_test_date': self.last_test_date.isoformat() if self.last_test_date else None,
        }
    
    def get_patient_summary(self) -> dict:
        """Get patient summary for doctor dashboard"""
        patient = self.patient
        return {
            'id': str(self.patient_id),
            'name': patient.name if hasattr(patient, 'name') else 'Unknown',
            'email': patient.email,
            'age': patient.age if hasattr(patient, 'age') else None,
            'sex': patient.sex if hasattr(patient, 'sex') else None,
            'phone': patient.phone if hasattr(patient, 'phone') else None,
            'healthScore': self.health_score,
            'trend': self.trend,
            'status': self.health_status,
            'lastTestDate': self.last_test_date.isoformat() if self.last_test_date else None,
            'profileImageUrl': patient.profile_image_url if hasattr(patient, 'profile_image_url') else None,
        }
