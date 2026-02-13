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
            if User.query.filter_by(username=data['username']).first():
                return {'message': 'Username already exists'}, 400
            
            if User.query.filter_by(email=data['email']).first():
                return {'message': 'Email already exists'}, 400
            
            # Create new user
            user = User(
                username=data['username'],
                email=data['email'],
                full_name=data.get('full_name')
            )
            user.set_password(data['password'])
            
            db.session.add(user)
            db.session.commit()
            
            return {
                'message': 'User registered successfully',
                'user': user.to_dict()
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
            
            if not user or not user.check_password(data['password']):
                return {'message': 'Invalid email or password'}, 401
            
            # Update last login
            user.last_login = datetime.utcnow()
            db.session.commit()
            
            # Generate JWT token
            token = jwt.encode({
                'user_id': user.id,
                'exp': datetime.utcnow() + timedelta(days=7)
            }, Config.SECRET_KEY, algorithm='HS256')
            
            return {
                'message': 'Login successful',
                'token': token,
                'user': user.to_dict()
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
                'user': current_user.to_dict(include_sensitive=True)
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
            
            # Update fields
            if 'full_name' in data:
                current_user.full_name = data['full_name']
            if 'date_of_birth' in data:
                current_user.date_of_birth = datetime.strptime(data['date_of_birth'], '%Y-%m-%d').date()
            if 'gender' in data:
                current_user.gender = data['gender']
            if 'phone' in data:
                current_user.phone = data['phone']
            if 'has_glasses' in data:
                current_user.has_glasses = data['has_glasses']
            if 'has_eye_disease' in data:
                current_user.has_eye_disease = data['has_eye_disease']
            if 'eye_disease_details' in data:
                current_user.eye_disease_details = data['eye_disease_details']
            if 'family_history' in data:
                current_user.family_history = data['family_history']
            if 'current_medications' in data:
                current_user.current_medications = data['current_medications']
            if 'allergies' in data:
                current_user.allergies = data['allergies']
            
            current_user.updated_at = datetime.utcnow()
            db.session.commit()
            
            return {
                'message': 'Profile updated successfully',
                'user': current_user.to_dict(include_sensitive=True)
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Profile update failed: {str(e)}'}, 500


@auth_ns.route('/test-history')
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
