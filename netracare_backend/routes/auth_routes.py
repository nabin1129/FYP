"""
User Authentication Routes
Registration, Login, Profile Management
"""
from flask import Blueprint, request, jsonify
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import jwt
import re
from functools import wraps
from sqlalchemy.exc import IntegrityError

from db_model import db, User
from core.security import token_required
from core.config import BaseConfig

# Create namespace
auth_ns = Namespace('auth', description='Authentication operations')

# API Models
register_model = auth_ns.model('Register', {
    'username': fields.String(required=True, description='Username'),
    'email': fields.String(required=True, description='Email address'),
    'password': fields.String(required=True, description='Password'),
    'full_name': fields.String(description='Full name')
})

login_model = auth_ns.model('Login', {
    'email': fields.String(required=True, description='Email address'),
    'password': fields.String(required=True, description='Password')
})

profile_update_model = auth_ns.model('ProfileUpdate', {
    'full_name': fields.String(description='Full name'),
    'date_of_birth': fields.Date(description='Date of birth'),
    'gender': fields.String(description='Gender'),
    'phone': fields.String(description='Phone number'),
    'has_glasses': fields.Boolean(description='Wears glasses'),
    'has_eye_disease': fields.Boolean(description='Has eye disease'),
    'eye_disease_details': fields.String(description='Eye disease details'),
    'family_history': fields.String(description='Family medical history'),
    'current_medications': fields.String(description='Current medications'),
    'allergies': fields.String(description='Allergies')
})


# Helper Functions for Validation
def validate_email_format(email: str) -> bool:
    """Validate email format using regex"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.com$'
    return re.match(pattern, email) is not None


def validate_full_name(name: str) -> bool:
    """Validate full name with 2 to 4 words and single spaces only."""
    pattern = r'^[A-Za-z]+(?: [A-Za-z]+){1,3}$'
    return re.match(pattern, name) is not None


def validate_password_strength(password: str) -> tuple:
    """
    Validate password strength.
    Returns (is_valid, error_message)
    """
    if len(password) < 8:
        return False, "Password must be at least 8 characters"
    if not re.search(r'[a-z]', password):
        return False, "Password must contain a lowercase letter"
    if not re.search(r'[A-Z]', password):
        return False, "Password must contain an uppercase letter"
    if not re.search(r'\d', password):
        return False, "Password must contain a number"
    if not re.search(r'[@$!%*?&]', password):
        return False, "Password must contain a special character (@$!%*?&)"
    return True, ""


@auth_ns.route('/register')
class Register(Resource):
    """User registration endpoint"""
    
    @auth_ns.expect(register_model)
    def post(self):
        """Register a new user"""
        try:
            data = request.get_json()
            
            # Normalize and validate input
            email = data.get('email', '').strip().lower()
            password = data.get('password', '').strip()
            name = data.get('full_name', '') or data.get('username', '')
            name = name.strip() if name else ''
            
            # Validate all required fields
            if not email or not password or not name:
                return {
                    'message': 'Name, email and password are required'
                }, 400
            
            # Validate input lengths
            if len(email) > 254:
                return {'message': 'Email too long (max 254 characters)'}, 400
            if len(password) > 128:
                return {'message': 'Password too long (max 128 characters)'}, 400
            if len(name) > 100:
                return {'message': 'Name too long (max 100 characters)'}, 400

            if not validate_full_name(name):
                return {
                    'message': 'Name must contain 2 to 4 words with single spaces only'
                }, 400
            
            # Validate email format
            if not validate_email_format(email):
                return {'message': 'Email must be a valid .com address'}, 400
            
            # Validate password strength
            is_strong, error_msg = validate_password_strength(password)
            if not is_strong:
                return {'message': error_msg}, 400
            
            # Check if user exists (case-insensitive)
            if User.query.filter_by(email=email).first():
                return {'message': 'Email already registered'}, 409
            
            # Create new user
            user = User(
                name=name,
                email=email,
                password_hash=generate_password_hash(password)
            )
            
            db.session.add(user)
            try:
                db.session.commit()
            except IntegrityError:
                db.session.rollback()
                return {'message': 'Email already registered'}, 409
            
            return {
                'message': 'User registered successfully',
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email,
                    'created_at': user.created_at.isoformat() if user.created_at else None
                }
            }, 201
            
        except Exception as e:
            db.session.rollback()
            # Log the full error server-side, return generic message to client
            return {
                'message': 'Registration failed. Please try again.'
            }, 500


@auth_ns.route('/login')
class Login(Resource):
    """User login endpoint"""
    
    @auth_ns.expect(login_model)
    def post(self):
        """Login with email and password"""
        try:
            data = request.get_json()
            
            # Normalize email
            email = data.get('email', '').strip().lower()
            password = data.get('password', '')
            
            # Validate required fields
            if not email or not password:
                return {
                    'message': 'Email and password are required'
                }, 400
            
            # Validate input length
            if len(email) > 254 or len(password) > 128:
                return {'message': 'Invalid input'}, 400

            if not validate_email_format(email):
                return {'message': 'Email must be a valid .com address'}, 400
            
            # Find user
            user = User.query.filter_by(email=email).first()
            
            # Check password (whether user exists or not)
            if not user or not check_password_hash(user.password_hash, password):
                return {
                    'message': 'Invalid email or password'
                }, 401
            
            # Generate JWT token
            token = jwt.encode({
                'user_id': user.id,
                'exp': datetime.utcnow() + timedelta(days=7)
            }, BaseConfig.SECRET_KEY, algorithm='HS256')
            
            return {
                'message': 'Login successful',
                'token': token,
                'user': {
                    'id': user.id,
                    'name': user.name,
                    'email': user.email
                }
            }, 200
            
        except Exception as e:
            return {
                'message': 'Login failed. Please try again.'
            }, 500


@auth_ns.route('/profile')
class Profile(Resource):
    """User profile management"""
    
    @auth_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get current user profile"""
        try:
            return {
                'user': {
                    'id': current_user.id,
                    'name': current_user.name,
                    'email': current_user.email,
                    'age': current_user.age,
                    'sex': current_user.sex,
                    'phone': current_user.phone,
                    'address': current_user.address,
                    'emergency_contact': current_user.emergency_contact,
                    'medical_history': current_user.medical_history,
                    'created_at': current_user.created_at.isoformat() if current_user.created_at else None
                }
            }, 200
        except Exception as e:
            return {'message': f'Failed to get profile: {str(e)}'}, 500
    
    @auth_ns.doc(security='Bearer')
    @auth_ns.expect(profile_update_model)
    @token_required
    def put(self, current_user):
        """Update user profile"""
        try:
            data = request.get_json()
            
            # Update fields (adapting to existing User model)
            if 'full_name' in data:
                current_user.name = data['full_name']
            if 'date_of_birth' in data:
                current_user.age = datetime.utcnow().year - datetime.strptime(data['date_of_birth'], '%Y-%m-%d').year
            if 'gender' in data:
                current_user.sex = data['gender']
            if 'phone' in data:
                current_user.phone = data['phone']
            if 'eye_disease_details' in data or 'family_history' in data or 'current_medications' in data:
                # Combine into medical_history field
                medical_parts = []
                if data.get('eye_disease_details'):
                    medical_parts.append(f"Eye Disease: {data['eye_disease_details']}")
                if data.get('family_history'):
                    medical_parts.append(f"Family History: {data['family_history']}")
                if data.get('current_medications'):
                    medical_parts.append(f"Medications: {data['current_medications']}")
                if data.get('allergies'):
                    medical_parts.append(f"Allergies: {data['allergies']}")
                current_user.medical_history = "; ".join(medical_parts)
            
            db.session.commit()
            
            return {
                'message': 'Profile updated successfully',
                'user': {
                    'id': current_user.id,
                    'name': current_user.name,
                    'email': current_user.email,
                    'medical_history': current_user.medical_history
                }
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to update profile: {str(e)}'}, 500


class TestHistory(Resource):
    """Get user's test history"""
    
    @auth_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get all tests for current user"""
        try:
            history = {
                'visual_acuity_tests': [test.to_dict() for test in current_user.visual_acuity_tests.all()],
                'colour_vision_tests': [test.to_dict() for test in current_user.colour_vision_tests.all()],
                'pupil_reflex_tests': [test.to_dict() for test in current_user.pupil_reflex_tests.all()],
                'blink_fatigue_tests': [test.to_dict() for test in current_user.blink_fatigue_tests.all()],
                'eye_tracking_sessions': [test.to_dict() for test in current_user.eye_tracking_sessions.all()],
                'ai_reports': [report.to_dict() for report in current_user.ai_reports.all()]
            }
            
            return {
                'message': 'Test history retrieved successfully',
                'history': history
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to get test history: {str(e)}'}, 500

