"""
API Routes for Blink and Eye Fatigue Detection
CNN-based drowsiness detection from eye images
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from db_model import db, BlinkFatigueTest, User
from auth_utils import token_required
from blink_fatigue_model import get_model_singleton
from werkzeug.datastructures import FileStorage
import os
from datetime import datetime

# Create namespace
blink_fatigue_ns = Namespace('blink-fatigue', description='Blink and eye fatigue detection operations')

# File upload parser
upload_parser = blink_fatigue_ns.parser()
upload_parser.add_argument('image', location='files', type=FileStorage, required=True,
                          help='Eye image for drowsiness detection')
upload_parser.add_argument('test_duration', location='form', type=float, required=False,
                          help='Test duration in seconds (optional)')

# API Models for documentation
prediction_response_model = blink_fatigue_ns.model('BlinkFatiguePrediction', {
    'prediction': fields.String(description='Predicted class: drowsy or notdrowsy'),
    'confidence': fields.Float(description='Prediction confidence (0-1)'),
    'probabilities': fields.Raw(description='Probabilities for each class'),
    'fatigue_level': fields.String(description='Fatigue level classification'),
    'alert': fields.Boolean(description='Whether alert should be triggered'),
    'timestamp': fields.String(description='Prediction timestamp')
})

test_result_model = blink_fatigue_ns.model('BlinkFatigueTestResult', {
    'id': fields.Integer(description='Test ID'),
    'user_id': fields.Integer(description='User ID'),
    'prediction': fields.String(description='Predicted class'),
    'confidence': fields.Float(description='Confidence score'),
    'probabilities': fields.Raw(description='Class probabilities'),
    'fatigue_level': fields.String(description='Fatigue level'),
    'alert_triggered': fields.Boolean(description='Alert status'),
    'test_duration': fields.Float(description='Test duration in seconds'),
    'created_at': fields.String(description='Test timestamp')
})

test_history_model = blink_fatigue_ns.model('BlinkFatigueHistory', {
    'tests': fields.List(fields.Nested(test_result_model)),
    'total_tests': fields.Integer(description='Total number of tests'),
    'drowsy_count': fields.Integer(description='Number of drowsy detections'),
    'alert_count': fields.Integer(description='Number of alerts triggered')
})


@blink_fatigue_ns.route('/predict')
class BlinkFatiguePrediction(Resource):
    """Predict drowsiness from eye image"""
    
    @blink_fatigue_ns.expect(upload_parser)
    @blink_fatigue_ns.marshal_with(prediction_response_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Analyze eye image for drowsiness detection
        Upload an eye image to get real-time drowsiness prediction
        """
        # Validate file upload
        if 'image' not in request.files:
            blink_fatigue_ns.abort(400, 'No image file provided')
        
        file = request.files['image']
        
        if file.filename == '':
            blink_fatigue_ns.abort(400, 'Empty filename')
        
        # Validate file extension
        allowed_extensions = {'jpg', 'jpeg', 'png'}
        file_ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else ''
        
        if file_ext not in allowed_extensions:
            blink_fatigue_ns.abort(400, f'Invalid file type. Allowed: {allowed_extensions}')
        
        try:
            # Read image bytes
            image_bytes = file.read()
            
            # Get model and make prediction
            model = get_model_singleton()
            prediction_result = model.predict(image_bytes)
            
            return prediction_result
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Prediction failed: {str(e)}')


@blink_fatigue_ns.route('/test/submit')
class BlinkFatigueTestSubmission(Resource):
    """Submit and save blink fatigue test results"""
    
    @blink_fatigue_ns.expect(upload_parser)
    @blink_fatigue_ns.marshal_with(test_result_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Submit blink fatigue test and save results
        Processes image, makes prediction, and stores result in database
        """
        # Validate file upload
        if 'image' not in request.files:
            blink_fatigue_ns.abort(400, 'No image file provided')
        
        file = request.files['image']
        
        if file.filename == '':
            blink_fatigue_ns.abort(400, 'Empty filename')
        
        # Get optional test duration
        test_duration = request.form.get('test_duration', type=float)
        
        try:
            # Read image bytes
            image_bytes = file.read()
            
            # Get model and make prediction
            model = get_model_singleton()
            prediction_result = model.predict(image_bytes)
            
            # Create database record
            test_record = BlinkFatigueTest(
                user_id=current_user.id,
                prediction=prediction_result['prediction'],
                confidence=prediction_result['confidence'],
                drowsy_probability=prediction_result['probabilities']['drowsy'],
                notdrowsy_probability=prediction_result['probabilities']['notdrowsy'],
                fatigue_level=prediction_result['fatigue_level'],
                alert_triggered=prediction_result['alert'],
                test_duration=test_duration
            )
            
            db.session.add(test_record)
            db.session.commit()
            
            return test_record.to_dict()
            
        except Exception as e:
            db.session.rollback()
            blink_fatigue_ns.abort(500, f'Test submission failed: {str(e)}')


@blink_fatigue_ns.route('/history')
class BlinkFatigueHistory(Resource):
    """Get user's blink fatigue test history"""
    
    @blink_fatigue_ns.marshal_with(test_history_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """
        Retrieve user's blink fatigue test history
        Returns all past tests with statistics
        """
        try:
            # Fetch all tests for current user
            tests = BlinkFatigueTest.query.filter_by(user_id=current_user.id).order_by(
                BlinkFatigueTest.created_at.desc()
            ).all()
            
            # Calculate statistics
            drowsy_count = sum(1 for t in tests if t.prediction == 'drowsy')
            alert_count = sum(1 for t in tests if t.alert_triggered)
            
            return {
                'tests': [test.to_dict() for test in tests],
                'total_tests': len(tests),
                'drowsy_count': drowsy_count,
                'alert_count': alert_count
            }
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Failed to retrieve history: {str(e)}')


@blink_fatigue_ns.route('/history/<int:test_id>')
class BlinkFatigueTestDetail(Resource):
    """Get specific test details"""
    
    @blink_fatigue_ns.marshal_with(test_result_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, test_id):
        """
        Retrieve specific blink fatigue test by ID
        Returns detailed test results
        """
        try:
            test = BlinkFatigueTest.query.filter_by(
                id=test_id, 
                user_id=current_user.id
            ).first()
            
            if not test:
                blink_fatigue_ns.abort(404, 'Test not found')
            
            return test.to_dict()
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Failed to retrieve test: {str(e)}')


@blink_fatigue_ns.route('/stats')
class BlinkFatigueStats(Resource):
    """Get user's fatigue statistics"""
    
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """
        Get aggregated fatigue statistics for user
        Returns trends and patterns in fatigue detection
        """
        try:
            tests = BlinkFatigueTest.query.filter_by(user_id=current_user.id).all()
            
            if not tests:
                return {
                    'total_tests': 0,
                    'average_confidence': 0,
                    'drowsy_percentage': 0,
                    'alert_percentage': 0,
                    'fatigue_distribution': {},
                    'recent_trend': 'No data'
                }
            
            # Calculate statistics
            total_tests = len(tests)
            avg_confidence = sum(t.confidence for t in tests) / total_tests
            drowsy_count = sum(1 for t in tests if t.prediction == 'drowsy')
            alert_count = sum(1 for t in tests if t.alert_triggered)
            
            # Fatigue level distribution
            fatigue_distribution = {}
            for test in tests:
                level = test.fatigue_level
                fatigue_distribution[level] = fatigue_distribution.get(level, 0) + 1
            
            # Recent trend (last 5 tests)
            recent_tests = sorted(tests, key=lambda x: x.created_at, reverse=True)[:5]
            recent_drowsy = sum(1 for t in recent_tests if t.prediction == 'drowsy')
            
            if recent_drowsy >= 4:
                trend = 'High fatigue pattern detected'
            elif recent_drowsy >= 2:
                trend = 'Moderate fatigue detected'
            else:
                trend = 'Alert and well-rested'
            
            return {
                'total_tests': total_tests,
                'average_confidence': round(avg_confidence, 4),
                'drowsy_percentage': round((drowsy_count / total_tests) * 100, 2),
                'alert_percentage': round((alert_count / total_tests) * 100, 2),
                'fatigue_distribution': fatigue_distribution,
                'recent_trend': trend,
                'last_test_date': tests[-1].created_at.isoformat() if tests else None
            }
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Failed to retrieve stats: {str(e)}')
