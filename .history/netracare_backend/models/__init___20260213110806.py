"""
Models package for Netra Care
Centralized database models following SQLAlchemy best practices
"""
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

# Import all models for easy access
from .user import User
from .visual_acuity import VisualAcuityTest
from .colour_vision import ColourVisionTest
from .pupil_reflex import PupilReflexTest
from .distance_calibration import DistanceCalibration
from .ai_report import AIReport
from .blink_fatigue import BlinkFatigueTest
from .eye_tracking import EyeTrackingSession

__all__ = [
    'db',
    'User',
    'VisualAcuityTest',
    'ColourVisionTest',
    'PupilReflexTest',
    'DistanceCalibration',
    'AIReport',
    'BlinkFatigueTest',
    'EyeTrackingSession',
]
