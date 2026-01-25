"""
API Routes for Eye Tracking Tests (Dataset-based)
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from datetime import datetime
from db_model import db, EyeTrackingTest, User
from auth_utils import token_required
from eye_tracking_model import EyeTrackingMetrics, EyeTrackingDataset, EyeTrackingDataPoint

# Create namespace
eye_tracking_ns = Namespace('eye-tracking', description='Eye tracking test operations')

# API Models for documentation
data_point_model = eye_tracking_ns.model('EyeTrackingDataPoint', {
    'timestamp': fields.Float(required=True, description='Timestamp in seconds'),
    'gaze_x': fields.Float(required=True, description='Gaze X coordinate'),
    'gaze_y': fields.Float(required=True, description='Gaze Y coordinate'),
    'left_pupil_diameter': fields.Float(required=True, description='Left pupil diameter'),
    'right_pupil_diameter': fields.Float(required=True, description='Right pupil diameter'),
    'fixation_duration': fields.Float(description='Fixation duration'),
    'saccade_velocity': fields.Float(description='Saccade velocity')
})

test_submission_model = eye_tracking_ns.model('EyeTrackingTestSubmission', {
    'test_name': fields.String(required=False, default='Eye Tracking Test', description='Test name'),
    'test_duration': fields.Float(required=True, description='Test duration in seconds'),
    'gaze_accuracy': fields.Float(required=True, description='Gaze accuracy percentage'),
    'fixation_stability': fields.Float(description='Fixation stability score'),
    'saccade_consistency': fields.Float(description='Saccade consistency score'),
    'overall_score': fields.Float(description='Overall performance score'),
    'classification': fields.String(description='Performance classification'),
    'screen_width': fields.Integer(default=1920, description='Screen width'),
    'screen_height': fields.Integer(default=1080, description='Screen height'),
    'raw_data': fields.List(fields.Raw, description='Raw data points'),
    'pupil_metrics': fields.Raw(description='Pupil metrics')
})

upload_data_model = eye_tracking_ns.model('EyeTrackingUploadData', {
    'test_name': fields.String(required=True, description='Test name'),
    'data_points': fields.List(fields.Nested(data_point_model), required=True, description='Eye tracking data points'),
    'test_duration': fields.Float(required=True, description='Test duration in seconds'),
    'screen_width': fields.Integer(default=1920, description='Screen width'),
    'screen_height': fields.Integer(default=1080, description='Screen height')
})


@eye_tracking_ns.route('/tests')
class EyeTrackingTests(Resource):
    @token_required
    @eye_tracking_ns.doc('save_test_results')
    @eye_tracking_ns.expect(test_submission_model)
    def post(current_user, self):
        """Save eye tracking test results"""
        try:
            data = request.get_json()
            
            # Validate required fields
            required_fields = ['gaze_accuracy', 'test_duration']
            if not all(field in data for field in required_fields):
                eye_tracking_ns.abort(400, 'Missing required fields')
            
            # Create new test record
            test_record = EyeTrackingTest(
                user_id=current_user.id,
                test_name=data.get('test_name', 'Eye Tracking Test'),
                test_duration=data['test_duration'],
                gaze_accuracy=data['gaze_accuracy'],
                fixation_stability_score=data.get('fixation_stability', 0),
                saccade_consistency_score=data.get('saccade_consistency', 0),
                overall_performance_score=data.get('overall_score', data['gaze_accuracy']),
                performance_classification=data.get('classification', 'Fair'),
                screen_width=data.get('screen_width', 1920),
                screen_height=data.get('screen_height', 1080),
                status='completed'
            )
            
            # Store raw data if provided
            if 'raw_data' in data:
                test_record.set_raw_data(data['raw_data'])
            
            # Store pupil metrics if provided
            if 'pupil_metrics' in data:
                metrics = data['pupil_metrics']
                test_record.set_pupil_metrics(
                    metrics.get('left_pupil', {}),
                    metrics.get('right_pupil', {})
                )
            
            # Save to database
            db.session.add(test_record)
            db.session.commit()
            
            return {
                'message': 'Test results saved successfully',
                'test_id': test_record.id,
                'timestamp': test_record.created_at.isoformat()
            }, 201
        
        except Exception as e:
            db.session.rollback()
            eye_tracking_ns.abort(500, f'Failed to save results: {str(e)}')
    
    @token_required
    @eye_tracking_ns.doc('get_tests')
    def get(current_user, self):
        """Get all eye tracking tests for the current user"""
        try:
            limit = request.args.get('limit', 50, type=int)
            offset = request.args.get('offset', 0, type=int)
            
            tests = EyeTrackingTest.query.filter_by(user_id=current_user.id) \
                .order_by(EyeTrackingTest.created_at.desc()) \
                .limit(limit).offset(offset).all()
            
            return {
                'tests': [test.to_dict() for test in tests],
                'total': EyeTrackingTest.query.filter_by(user_id=current_user.id).count(),
                'limit': limit,
                'offset': offset
            }, 200
        
        except Exception as e:
            eye_tracking_ns.abort(500, f'Error retrieving tests: {str(e)}')


@eye_tracking_ns.route('/upload-data')
class EyeTrackingUploadData(Resource):
    @token_required
    @eye_tracking_ns.doc('upload_test_data')
    @eye_tracking_ns.expect(upload_data_model)
    def post(current_user, self):
        """Upload and process raw eye tracking data"""
        try:
            data = request.get_json()
            
            # Validate required fields
            required_fields = ['test_name', 'data_points', 'test_duration']
            if not all(field in data for field in required_fields):
                eye_tracking_ns.abort(400, 'Missing required fields')
            
            # Create dataset
            dataset = EyeTrackingDataset(
                test_name=data['test_name'],
                screen_width=data.get('screen_width', 1920),
                screen_height=data.get('screen_height', 1080)
            )
            dataset.set_test_duration(data['test_duration'])
            
            # Add data points
            for point_data in data['data_points']:
                data_point = EyeTrackingDataPoint(
                    timestamp=point_data['timestamp'],
                    gaze_x=point_data['gaze_x'],
                    gaze_y=point_data['gaze_y'],
                    left_pupil_diameter=point_data['left_pupil_diameter'],
                    right_pupil_diameter=point_data['right_pupil_diameter'],
                    fixation_duration=point_data.get('fixation_duration'),
                    saccade_velocity=point_data.get('saccade_velocity')
                )
                dataset.add_data_point(data_point)
            
            # Calculate metrics
            try:
                # Extract gaze points
                actual_gaze = [(p.gaze_x, p.gaze_y) for p in dataset.get_data_points()]
                tracked_gaze = actual_gaze  # In real scenario, compare with target
                gaze_accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(
                    actual_gaze, tracked_gaze
                )
                
                # Fixation stability
                fixation_durations = [p.fixation_duration for p in dataset.get_data_points()
                                     if p.fixation_duration]
                fixation_stability = EyeTrackingMetrics.calculate_fixation_stability(
                    fixation_durations
                ) if fixation_durations else {'stability_score': 0}
                
                # Saccade metrics
                saccade_velocities = [p.saccade_velocity for p in dataset.get_data_points()
                                     if p.saccade_velocity]
                saccade_metrics = EyeTrackingMetrics.calculate_saccade_metrics(
                    saccade_velocities
                ) if saccade_velocities else {'std_velocity': 0}
                
                # Pupil metrics
                pupil_metrics = EyeTrackingMetrics.calculate_pupil_metrics(dataset)
                
                # Overall performance
                performance = EyeTrackingMetrics.calculate_overall_performance(
                    dataset, gaze_accuracy, fixation_stability, saccade_metrics
                )
                
            except Exception as e:
                eye_tracking_ns.abort(400, f'Failed to calculate metrics: {str(e)}')
            
            # Create test record with calculated metrics
            test_record = EyeTrackingTest(
                user_id=current_user.id,
                test_name=data['test_name'],
                test_duration=data['test_duration'],
                gaze_accuracy=gaze_accuracy,
                fixation_stability_score=fixation_stability['stability_score'],
                saccade_consistency_score=performance['saccade_consistency'],
                overall_performance_score=performance['overall_score'],
                performance_classification=performance['classification'],
                screen_width=data.get('screen_width', 1920),
                screen_height=data.get('screen_height', 1080),
                status='completed'
            )
            
            test_record.set_raw_data(data['data_points'])
            test_record.set_pupil_metrics(pupil_metrics['left_pupil'], pupil_metrics['right_pupil'])
            
            # Save to database
            db.session.add(test_record)
            db.session.commit()
            
            return {
                'message': 'Test data uploaded and processed successfully',
                'test_id': test_record.id,
                'metrics': performance,
                'timestamp': test_record.created_at.isoformat()
            }, 201
        
        except Exception as e:
            db.session.rollback()
            eye_tracking_ns.abort(500, f'Failed to upload data: {str(e)}')


@eye_tracking_ns.route('/tests/<int:test_id>')
class EyeTrackingTestDetail(Resource):
    @token_required
    @eye_tracking_ns.doc('get_test')
    def get(current_user, self, test_id):
        """Get a specific eye tracking test"""
        try:
            test = EyeTrackingTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                eye_tracking_ns.abort(404, 'Test not found')
            
            return test.to_dict(), 200
            
        except Exception as e:
            eye_tracking_ns.abort(500, f'Error retrieving test: {str(e)}')
    
    @token_required
    @eye_tracking_ns.doc('delete_test')
    def delete(current_user, self, test_id):
        """Delete a specific eye tracking test"""
        try:
            test = EyeTrackingTest.query.filter_by(
                id=test_id,
                user_id=current_user.id
            ).first()
            
            if not test:
                eye_tracking_ns.abort(404, 'Test not found')
            
            db.session.delete(test)
            db.session.commit()
            
            return {'message': 'Test deleted successfully'}, 200
            
        except Exception as e:
            db.session.rollback()
            eye_tracking_ns.abort(500, f'Error deleting test: {str(e)}')


@eye_tracking_ns.route('/tests/latest')
class EyeTrackingLatestTest(Resource):
    @token_required
    @eye_tracking_ns.doc('get_latest_test')
    def get(current_user, self):
        """Get the most recent eye tracking test"""
        try:
            test = EyeTrackingTest.query.filter_by(user_id=current_user.id) \
                .order_by(EyeTrackingTest.created_at.desc()) \
                .first()
            
            if not test:
                eye_tracking_ns.abort(404, 'No test results found')
            
            return test.to_dict(), 200
            
        except Exception as e:
            eye_tracking_ns.abort(500, f'Error retrieving test: {str(e)}')


@eye_tracking_ns.route('/tests/statistics')
class EyeTrackingStatistics(Resource):
    @token_required
    @eye_tracking_ns.doc('get_statistics')
    def get(current_user, self):
        """Get statistics for all eye tracking tests"""
        try:
            tests = EyeTrackingTest.query.filter_by(user_id=current_user.id).all()
            
            if not tests:
                return {
                    'total_tests': 0,
                    'average_accuracy': 0,
                    'best_accuracy': 0,
                    'latest_classification': None
                }, 200
            
            accuracies = [t.gaze_accuracy for t in tests if t.gaze_accuracy]
            
            return {
                'total_tests': len(tests),
                'average_accuracy': sum(accuracies) / len(accuracies) if accuracies else 0,
                'best_accuracy': max(accuracies) if accuracies else 0,
                'latest_classification': tests[0].performance_classification,
                'latest_date': tests[0].created_at.isoformat()
            }, 200
            
        except Exception as e:
            eye_tracking_ns.abort(500, f'Error calculating statistics: {str(e)}')
