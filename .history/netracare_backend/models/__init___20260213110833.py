"""
Models package for Netra Care
Centralized database models following SQLAlchemy best practices
"""

# Import db from existing db_model.py to maintain compatibility
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
from db_model import db

__all__ = ['db']

