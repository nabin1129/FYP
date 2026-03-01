"""
API Routes for Eye Tracking Tests (Dataset-based)
"""

import math
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
    'target_x': fields.Float(description='Target X coordinate'),
    'target_y': fields.Float(description='Target Y coordinate'),
    'left_pupil_diameter': fields.Float(description='Left pupil diameter'),
    'right_pupil_diameter': fields.Float(description='Right pupil diameter'),
    'left_ear': fields.Float(description='Left Eye Aspect Ratio'),
    'right_ear': fields.Float(description='Right Eye Aspect Ratio'),
    'is_blink': fields.Boolean(description='Whether a blink was detected'),
    'head_euler_x': fields.Float(description='Head euler angle X'),
    'head_euler_y': fields.Float(description='Head euler angle Y'),
    'head_euler_z': fields.Float(description='Head euler angle Z'),
    'phase': fields.String(description='Test phase name'),
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
    def post(self, current_user):
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
    def get(self, current_user):
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
    def post(self, current_user):
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
                    timestamp=point_data.get('timestamp', 0),
                    gaze_x=point_data.get('gaze_x', 0),
                    gaze_y=point_data.get('gaze_y', 0),
                    left_pupil_diameter=point_data.get('left_pupil_diameter', 0),
                    right_pupil_diameter=point_data.get('right_pupil_diameter', 0),
                    fixation_duration=point_data.get('fixation_duration'),
                    saccade_velocity=point_data.get('saccade_velocity'),
                    target_x=point_data.get('target_x'),
                    target_y=point_data.get('target_y'),
                    left_ear=point_data.get('left_ear'),
                    right_ear=point_data.get('right_ear'),
                    is_blink=point_data.get('is_blink', False),
                    head_euler_x=point_data.get('head_euler_x'),
                    head_euler_y=point_data.get('head_euler_y'),
                    head_euler_z=point_data.get('head_euler_z'),
                    phase=point_data.get('phase'),
                )
                dataset.add_data_point(data_point)
            
            # Calculate metrics
            try:
                all_points = dataset.get_data_points()

                # Use target positions for gaze accuracy when available
                points_with_target = [p for p in all_points if p.has_target and not p.is_blink]
                if points_with_target:
                    target_positions = [(p.target_x, p.target_y) for p in points_with_target]
                    gaze_positions = [(p.gaze_x, p.gaze_y) for p in points_with_target]
                    screen_diag = math.sqrt(
                        dataset.screen_width ** 2 + dataset.screen_height ** 2
                    )
                    gaze_accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(
                        target_positions, gaze_positions, screen_diagonal=screen_diag
                    )
                else:
                    # Fallback: old behaviour
                    actual_gaze = [(p.gaze_x, p.gaze_y) for p in all_points]
                    gaze_accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(
                        actual_gaze, actual_gaze
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
                
                # Blink & EAR metrics
                blink_metrics = EyeTrackingMetrics.calculate_blink_metrics(
                    all_points, dataset.test_duration
                )
                
                # Overall performance
                performance = EyeTrackingMetrics.calculate_overall_performance(
                    dataset, gaze_accuracy, fixation_stability, saccade_metrics
                )
                performance['blink_metrics'] = blink_metrics
                
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
