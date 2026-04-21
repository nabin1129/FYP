"""Medical Record Model - persistent doctor-recorded patient documents.

This table stores formal medical records separately from consultation messages so
records can be queried, audited, and managed cleanly by doctor, patient, and admin
workflows.
"""
from datetime import datetime

from db_model import db


class MedicalRecord(db.Model):
    """Persistent medical record created by a doctor for a patient."""

    __tablename__ = 'medical_records'

    id = db.Column(db.Integer, primary_key=True)
    doctor_id = db.Column(db.Integer, db.ForeignKey('doctors.id'), nullable=False, index=True)
    patient_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False, index=True)

    record_type = db.Column(db.String(50), nullable=False, index=True)  # scan_report, prescription, lab_report, clinical_note, test_result
    title = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(50), default='general', index=True)

    file_url = db.Column(db.String(500))
    file_name = db.Column(db.String(255))
    file_size = db.Column(db.Integer)
    mime_type = db.Column(db.String(100))

    status = db.Column(db.String(20), default='active', index=True)  # draft, active, archived, deleted
    created_by_id = db.Column(db.Integer, db.ForeignKey('doctors.id'), nullable=False)
    updated_by_id = db.Column(db.Integer, db.ForeignKey('doctors.id'))
    deleted_by_id = db.Column(db.Integer, db.ForeignKey('doctors.id'))
    deleted_at = db.Column(db.DateTime)

    created_at = db.Column(db.DateTime, default=datetime.utcnow, index=True)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    doctor = db.relationship('Doctor', foreign_keys=[doctor_id], backref=db.backref('medical_records', lazy='dynamic'))
    patient = db.relationship('User', foreign_keys=[patient_id], backref=db.backref('medical_records', lazy='dynamic'))
    creator = db.relationship('Doctor', foreign_keys=[created_by_id], backref=db.backref('created_medical_records', lazy='dynamic'))
    updater = db.relationship('Doctor', foreign_keys=[updated_by_id], backref=db.backref('updated_medical_records', lazy='dynamic'))
    deleter = db.relationship('Doctor', foreign_keys=[deleted_by_id], backref=db.backref('deleted_medical_records', lazy='dynamic'))

    def to_dict(self) -> dict:
        """Convert record to API-friendly dictionary."""
        return {
            'id': self.id,
            'doctor_id': self.doctor_id,
            'patient_id': self.patient_id,
            'doctorName': self.doctor.name if self.doctor else 'Unknown Doctor',
            'patientName': self.patient.name if self.patient else 'Unknown Patient',
            'record_type': self.record_type,
            'type': self.record_type,
            'title': self.title,
            'description': self.description,
            'category': self.category,
            'file_url': self.file_url,
            'file_name': self.file_name,
            'fileName': self.file_name,
            'file_size': self.file_size,
            'mime_type': self.mime_type,
            'status': self.status,
            'source': 'doctor',
            'created_by_id': self.created_by_id,
            'updated_by_id': self.updated_by_id,
            'deleted_by_id': self.deleted_by_id,
            'deleted_at': self.deleted_at.isoformat() if self.deleted_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'date': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }
