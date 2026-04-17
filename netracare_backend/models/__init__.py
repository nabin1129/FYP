"""
Models package for Netra Care
Centralized database models following SQLAlchemy best practices
"""

# Import db from existing db_model.py to maintain compatibility
from db_model import db

# Import all models
from .doctor import Doctor, DoctorPatient
from .consultation import Consultation, ConsultationMessage, DoctorSlot
from .notification import Notification

__all__ = [
    'db',
    'Doctor',
    'DoctorPatient',
    'DoctorSlot',
    'Consultation',
    'ConsultationMessage',
    'Notification',
]

