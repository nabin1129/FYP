"""
API Routes for Visual Acuity Tests
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from db_model import db, VisualAcuityTest, User
from auth_utils import token_required
from va_model import validate, calculate_logmar, logmar_to_snellen, classify_severity

# Create namespace
visual_acuity_ns = Namespace('visual-acuity', description='Visual acuity test operations')

# API Models for documentation
test_submission_model = visual_acuity_ns.model('VisualAcuityTestSubmission', {
    'correct_answers': fields.Integer(required=True, description='Number of correct answers'),
    'total_questions': fields.Integer(required=True, description='Total number of questions')
})

test_response_model = visual_acuity_ns.model('VisualAcuityTestResponse', {
    'id': fields.Integer(description='Test ID'),
    'user_id': fields.Integer(description='User ID'),
    'correct_answers': fields.Integer(description='Correct answers'),
    'total_questions': fields.Integer(description='Total questions'),
    'logmar_value': fields.Float(description='LogMAR value'),
    'snellen_value': fields.String(description='Snellen notation'),
    'severity': fields.String(description='Severity classification'),
    'created_at': fields.String(description='Test creation timestamp')
})


@visual_acuity_ns.route('/tests')
class VisualAcuityTests(Resource):
    @token_required
    @visual_acuity_ns.doc('submit_test')
    @visual_acuity_ns.expect(test_submission_model)
    @visual_acuity_ns.marshal_with(test_response_model, code=201)
    def post(current_user, self):
        """Submit a new visual acuity test result"""
        try:
            data = request.get_json()
            correct = data['correct_answers']
            total = data['total_questions']
            
            # Validate inputs
            validate(correct, total)
            
            # Calculate metrics
            logmar = calculate_logmar(correct, total)
            snellen = logmar_to_snellen(logmar)
            severity = classify_severity(logmar)
            
            # Create test record
            test = VisualAcuityTest(
                user_id=current_user.id,
                correct_answers=correct,
                total_questions=total,
                logmar_value=logmar,
                snellen_value=snellen,
                severity=severity
            )
            
            db.session.add(test)
            db.session.commit()
            
            return test.to_dict(), 201
            
        except ValueError as e:
            visual_acuity_ns.abort(400, str(e))
        except KeyError as e:
            visual_acuity_ns.abort(400, f'Missing required field: {str(e)}')
        except Exception as e:
            db.session.rollback()
            visual_acuity_ns.abort(500, f'Error saving test: {str(e)}')
    
    @token_required
    @visual_acuity_ns.doc('get_tests')
    def get(current_user, self):
        """Get all visual acuity tests for the current user"""
        try:
            # Query parameters
            limit = request.args.get('limit', 50, type=int)
            offset = request.args.get('offset', 0, type=int)
            
            # Get tests
            tests = VisualAcuityTest.query.filter_by(
                user_id=current_user.id
            ).order_by(
                VisualAcuityTest.created_at.desc()
            ).limit(limit).offset(offset).all()
            
            return {
                'tests': [test.to_dict() for test in tests],
                'total': VisualAcuityTest.query.filter_by(user_id=current_user.id).count(),
                'limit': limit,
                'offset': offset
            }, 200
            
        except Exception as e:
            visual_acuity_ns.abort(500, f'Error retrieving tests: {str(e)}')


@visual_acuity_ns.route('/tests/<int:test_id>')
class VisualAcuityTestDetail(Resource):
    @token_required
    @visual_acuity_ns.doc('get_test')
    @visual_acuity_ns.marshal_with(test_response_model)
    def get(current_user, self, test_id):
        """Get a specific visual acuity test"""
        try:
            test = VisualAcuityTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                visual_acuity_ns.abort(404, 'Test not found')
            
            return test.to_dict(), 200
            
        except Exception as e:
            visual_acuity_ns.abort(500, f'Error retrieving test: {str(e)}')
    
    @token_required
    @visual_acuity_ns.doc('delete_test')
    def delete(current_user, self, test_id):
        """Delete a visual acuity test"""
        try:
            test = VisualAcuityTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                visual_acuity_ns.abort(404, 'Test not found')
            
            db.session.delete(test)
            db.session.commit()
            
            return {'message': 'Test deleted successfully'}, 200
            
        except Exception as e:
            db.session.rollback()
            visual_acuity_ns.abort(500, f'Error deleting test: {str(e)}')


@visual_acuity_ns.route('/tests/statistics')
class VisualAcuityStatistics(Resource):
    @token_required
    @visual_acuity_ns.doc('get_statistics')
    def get(current_user, self):
        """Get statistics for all visual acuity tests"""
        try:
            tests = VisualAcuityTest.query.filter_by(user_id=current_user.id).all()
            
            if not tests:
                return {
                    'total_tests': 0,
                    'average_logmar': None,
                    'best_snellen': None,
                    'latest_severity': None,
                    'tests_by_severity': {}
                }, 200
            
            # Calculate statistics
            logmar_values = [test.logmar_value for test in tests]
            avg_logmar = sum(logmar_values) / len(logmar_values)
            
            # Best test (lowest logMAR)
            best_test = min(tests, key=lambda t: t.logmar_value)
            
            # Latest test
            latest_test = max(tests, key=lambda t: t.created_at)
            
            # Count by severity
            severity_counts = {}
            for test in tests:
                severity_counts[test.severity] = severity_counts.get(test.severity, 0) + 1
            
            return {
                'total_tests': len(tests),
                'average_logmar': round(avg_logmar, 2),
                'best_snellen': best_test.snellen_value,
                'best_logmar': best_test.logmar_value,
                'latest_severity': latest_test.severity,
                'latest_snellen': latest_test.snellen_value,
                'latest_test_date': latest_test.created_at.isoformat(),
                'tests_by_severity': severity_counts
            }, 200
            
        except Exception as e:
            visual_acuity_ns.abort(500, f'Error calculating statistics: {str(e)}')
