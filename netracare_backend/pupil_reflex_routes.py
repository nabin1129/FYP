"""
API Routes for Pupil Reflex Tests
Handles pupil light reflex test submissions and history
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from db_model import db, PupilReflexTest, User
from auth_utils import token_required
from werkzeug.datastructures import FileStorage
import os
from datetime import datetime

# Create namespace
pupil_reflex_ns = Namespace('pupil-reflex', description='Pupil reflex test operations')

# File upload parser
upload_parser = pupil_reflex_ns.parser()
upload_parser.add_argument('image', location='files', type=FileStorage, required=False,
                          help='Optional eye image from test')
upload_parser.add_argument('reaction_time', location='form', type=float, required=True,
                          help='Pupil reaction time in seconds')
upload_parser.add_argument('constriction_amplitude', location='form', type=str, required=True,
                          help='Constriction amplitude: Normal, Weak, or Strong')
upload_parser.add_argument('symmetry', location='form', type=str, required=True,
                          help='Pupil symmetry: Equal or Unequal')
upload_parser.add_argument('test_duration', location='form', type=float, required=False,
                          help='Total test duration in seconds')
upload_parser.add_argument('left_pupil_size_before', location='form', type=float, required=False)
upload_parser.add_argument('left_pupil_size_after', location='form', type=float, required=False)
upload_parser.add_argument('right_pupil_size_before', location='form', type=float, required=False)
upload_parser.add_argument('right_pupil_size_after', location='form', type=float, required=False)

# API Models for documentation
test_result_model = pupil_reflex_ns.model('PupilReflexTestResult', {
    'id': fields.Integer(description='Test ID'),
    'user_id': fields.Integer(description='User ID'),
    'reaction_time': fields.Float(description='Reaction time in seconds'),
    'constriction_amplitude': fields.String(description='Amplitude classification'),
    'symmetry': fields.String(description='Symmetry status'),
    'test_duration': fields.Float(description='Test duration'),
    'created_at': fields.String(description='Test timestamp')
})

test_history_model = pupil_reflex_ns.model('PupilReflexHistory', {
    'tests': fields.List(fields.Nested(test_result_model)),
    'total_tests': fields.Integer(description='Total number of tests'),
    'avg_reaction_time': fields.Float(description='Average reaction time')
})


@pupil_reflex_ns.route('/test/submit')
class PupilReflexTestSubmission(Resource):
    """Submit and save pupil reflex test results"""
    
    @pupil_reflex_ns.expect(upload_parser)
    @pupil_reflex_ns.marshal_with(test_result_model)
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Submit pupil reflex test results
        Save test data with optional image
        """
        try:
            # Get form data
            reaction_time = request.form.get('reaction_time', type=float)
            constriction_amplitude = request.form.get('constriction_amplitude', 'Normal')
            symmetry = request.form.get('symmetry', 'Equal')
            test_duration = request.form.get('test_duration', type=float)
            
            # Optional pupil size measurements
            left_before = request.form.get('left_pupil_size_before', type=float)
            left_after = request.form.get('left_pupil_size_after', type=float)
            right_before = request.form.get('right_pupil_size_before', type=float)
            right_after = request.form.get('right_pupil_size_after', type=float)
            
            # Validate required fields
            if reaction_time is None:
                pupil_reflex_ns.abort(400, 'Reaction time is required')
            
            # Handle optional image upload
            image_filename = None
            if 'image' in request.files:
                file = request.files['image']
                if file and file.filename:
                    # Create upload directory if not exists
                    upload_dir = os.path.join(os.path.dirname(__file__), 'uploads', 'pupil_reflex')
                    os.makedirs(upload_dir, exist_ok=True)
                    
                    # Generate unique filename
                    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
                    filename = f"pupil_reflex_{current_user.id}_{timestamp}.jpg"
                    filepath = os.path.join(upload_dir, filename)
                    
                    # Save file
                    file.save(filepath)
                    image_filename = filename
            
            # Create test record
            new_test = PupilReflexTest(
                user_id=current_user.id,
                reaction_time=reaction_time,
                constriction_amplitude=constriction_amplitude,
                symmetry=symmetry,
                test_duration=test_duration,
                left_pupil_size_before=left_before,
                left_pupil_size_after=left_after,
                right_pupil_size_before=right_before,
                right_pupil_size_after=right_after,
                image_filename=image_filename,
                status='completed'
            )
            
            db.session.add(new_test)
            db.session.commit()
            
            return new_test.to_dict(), 201
            
        except Exception as e:
            db.session.rollback()
            pupil_reflex_ns.abort(500, f'Failed to save test: {str(e)}')


@pupil_reflex_ns.route('/tests')
class PupilReflexTestHistory(Resource):
    """Get user's pupil reflex test history"""
    
    @pupil_reflex_ns.marshal_with(test_history_model)
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """
        Get all pupil reflex tests for current user
        Returns test history with statistics
        """
        try:
            # Query tests for current user
            tests = PupilReflexTest.query.filter_by(
                user_id=current_user.id
            ).order_by(PupilReflexTest.created_at.desc()).all()
            
            # Calculate statistics
            total_tests = len(tests)
            avg_reaction_time = 0
            
            if total_tests > 0:
                avg_reaction_time = sum(t.reaction_time for t in tests) / total_tests
            
            return {
                'tests': [test.to_dict() for test in tests],
                'total_tests': total_tests,
                'avg_reaction_time': round(avg_reaction_time, 3)
            }
            
        except Exception as e:
            pupil_reflex_ns.abort(500, f'Failed to fetch tests: {str(e)}')


@pupil_reflex_ns.route('/tests/<int:test_id>')
class PupilReflexTestDetail(Resource):
    """Get specific pupil reflex test details"""
    
    @pupil_reflex_ns.marshal_with(test_result_model)
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, test_id):
        """
        Get specific test by ID
        """
        try:
            test = PupilReflexTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                pupil_reflex_ns.abort(404, 'Test not found')
            
            return test.to_dict()
            
        except Exception as e:
            pupil_reflex_ns.abort(500, f'Failed to fetch test: {str(e)}')
    
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def delete(self, current_user, test_id):
        """
        Delete specific test
        """
        try:
            test = PupilReflexTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                pupil_reflex_ns.abort(404, 'Test not found')
            
            # Delete associated image file if exists
            if test.image_filename:
                upload_dir = os.path.join(os.path.dirname(__file__), 'uploads', 'pupil_reflex')
                filepath = os.path.join(upload_dir, test.image_filename)
                if os.path.exists(filepath):
                    os.remove(filepath)
            
            db.session.delete(test)
            db.session.commit()
            
            return {'message': 'Test deleted successfully'}, 200
            
        except Exception as e:
            db.session.rollback()
            pupil_reflex_ns.abort(500, f'Failed to delete test: {str(e)}')
