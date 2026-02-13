"""
Visual Acuity Test Routes
Snellen Chart, Tumbling E, Landolt C tests
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from datetime import datetime

from db_model import db
from models.visual_acuity import VisualAcuityTest
from auth_utils import token_required

# Create namespace
visual_acuity_ns = Namespace('visual-acuity', description='Visual acuity test operations')

# API Models
test_config_model = visual_acuity_ns.model('VisualAcuityConfig', {
    'test_type': fields.String(required=True, description='Test type: snellen, tumbling_e, landolt_c'),
    'test_distance': fields.Float(default=1.0, description='Test distance in meters'),
    'device_calibrated': fields.Boolean(default=False),
    'calibration_method': fields.String(description='arcore, arkit, manual'),
    'screen_size_inches': fields.Float(description='Device screen size'),
    'device_model': fields.String(description='Device model'),
    'ambient_light_level': fields.String(description='low, medium, high')
})

test_result_model = visual_acuity_ns.model('VisualAcuityResult', {
    'test_type': fields.String(required=True),
    'left_eye_score': fields.String(description='e.g., 20/20'),
    'right_eye_score': fields.String(description='e.g., 20/30'),
    'both_eyes_score': fields.String(description='e.g., 20/20'),
    'correct_answers': fields.Integer(required=True),
    'total_questions': fields.Integer(required=True),
    'smallest_line_read': fields.Integer(description='Line number read'),
    'test_duration': fields.Integer(description='Test duration in seconds'),
    'test_distance': fields.Float(default=1.0),
    'device_calibrated': fields.Boolean(default=False),
    'calibration_method': fields.String(),
    'user_distance_cm': fields.Float(description='Actual user distance')
})


@visual_acuity_ns.route('/submit')
class VisualAcuitySubmit(Resource):
    """Submit visual acuity test results"""
    
    @visual_acuity_ns.doc(security='Bearer')
    @visual_acuity_ns.expect(test_result_model)
    @token_required
    def post(self, current_user):
        """Submit visual acuity test results with AI analysis"""
        try:
            data = request.get_json()
            
            # Calculate accuracy
            accuracy = (data['correct_answers'] / data['total_questions']) * 100 if data['total_questions'] > 0 else 0
            
            # AI Analysis (simplified for now - will be enhanced with actual AI)
            condition_detected = 'normal'
            severity = 'none'
            confidence_score = 0.0
            recommended_action = 'Continue regular eye checkups'
            
            if accuracy < 50:
                condition_detected = 'severe_blurry'
                severity = 'severe'
                confidence_score = 0.85
                recommended_action = 'Consult ophthalmologist immediately'
            elif accuracy < 70:
                condition_detected = 'moderate_blurry'
                severity = 'moderate'
                confidence_score = 0.75
                recommended_action = 'Schedule eye examination soon'
            elif accuracy < 85:
                condition_detected = 'mild_blurry'
                severity = 'mild'
                confidence_score = 0.65
                recommended_action = 'Consider scheduling an eye checkup'
            else:
                confidence_score = 0.90
            
            # Create test record
            test = VisualAcuityTest(
                user_id=current_user.id,
                test_type=data['test_type'],
                test_distance=data.get('test_distance', 1.0),
                device_calibrated=data.get('device_calibrated', False),
                calibration_method=data.get('calibration_method'),
                screen_size_inches=data.get('screen_size_inches'),
                device_model=data.get('device_model'),
                left_eye_score=data.get('left_eye_score'),
                right_eye_score=data.get('right_eye_score'),
                both_eyes_score=data.get('both_eyes_score'),
                correct_answers=data['correct_answers'],
                total_questions=data['total_questions'],
                accuracy_percentage=accuracy,
                smallest_line_read=data.get('smallest_line_read'),
                condition_detected=condition_detected,
                severity=severity,
                confidence_score=confidence_score,
                recommended_action=recommended_action,
                ambient_light_level=data.get('ambient_light_level'),
                user_distance_cm=data.get('user_distance_cm'),
                test_duration=data.get('test_duration')
            )
            
            db.session.add(test)
            db.session.commit()
            
            return {
                'message': 'Visual acuity test submitted successfully',
                'test': test.to_dict()
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Test submission failed: {str(e)}'}, 500


@visual_acuity_ns.route('/history')
class VisualAcuityHistory(Resource):
    """Get user's visual acuity test history"""
    
    @visual_acuity_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get all visual acuity tests for current user"""
        try:
            tests = VisualAcuityTest.query.filter_by(user_id=current_user.id).order_by(VisualAcuityTest.created_at.desc()).all()
            
            return {
                'message': 'Visual acuity test history retrieved',
                'tests': [test.to_dict() for test in tests],
                'total_tests': len(tests)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to get test history: {str(e)}'}, 500


@visual_acuity_ns.route('/<int:test_id>')
class VisualAcuityDetail(Resource):
    """Get specific visual acuity test details"""
    
    @visual_acuity_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, test_id):
        """Get specific test details"""
        try:
            test = VisualAcuityTest.query.filter_by(id=test_id, user_id=current_user.id).first()
            
            if not test:
                return {'message': 'Test not found'}, 404
            
            return {
                'message': 'Test details retrieved',
                'test': test.to_dict()
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to get test details: {str(e)}'}, 500
