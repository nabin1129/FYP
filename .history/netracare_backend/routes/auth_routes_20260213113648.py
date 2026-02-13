"""
User Authentication Routes
Registration, Login, Profile Management
"""
from flask import Blueprint, request, jsonify
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import jwt
from functools import wraps

from db_model import db, User
from auth_utils import token_required
from config import Config

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


@auth_ns.route('/register')
class Register(Resource):
    """User registration endpoint"""
    
    @auth_ns.expect(register_model)
    def post(self):
        """Register a new user"""
        try:
            data = request.get_json()
            
            # Validate input
            if not data.get('username') or not data.get('email') or not data.get('password'):
                return {'message': 'Username, email and password are required'}, 400
            
            # Check if user exists
            if User.query.filter_by(email=data['email']).first():
                return {'message': 'Email already exists'}, 400
            
            # Create new user (adapting to existing User model schema)
            user = User(
                name=data.get('full_name') or data['username'],  # Use 'name' field instead of 'username'
                email=data['email'],
                password_hash=generate_password_hash(data['password'])
            )
            
            db.session.add(user)
            db.session.commit()
            
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
            return {'message': f'Registration failed: {str(e)}'}, 500


@auth_ns.route('/login')
class Login(Resource):
    """User login endpoint"""
    
    @auth_ns.expect(login_model)
    def post(self):
        """Login with email and password"""
        try:
            data = request.get_json()
            
            if not data.get('email') or not data.get('password'):
                return {'message': 'Email and password are required'}, 400
            
            # Find user
            user = User.query.filter_by(email=data['email']).first()
            
            if not user or not check_password_hash(user.password_hash, data['password']):
                return {'message': 'Invalid email or password'}, 401
            
            # Generate JWT token
            token = jwt.encode({
                'user_id': user.id,
                'exp': datetime.utcnow() + timedelta(days=7)
            }, Config.SECRET_KEY, algorithm='HS256')
            
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
            return {'message': f'Login failed: {str(e)}'}, 500


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
            # Use existing relationships from db_model
            history = {
                'visual_acuity_tests': [],
                'colour_vision_tests': [],
                'pupil_reflex_tests': [],
                'blink_fatigue_tests': [],
                'eye_tracking_sessions': [],
                'message': 'Test history feature available. Detailed history will be added in next phase.'}
            
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
