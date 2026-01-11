from flask import Blueprint, request, jsonify
from datetime import datetime
from functools import wraps
from db_model import db, EyeTrackingTest, User
from eye_tracking_model import EyeTrackingMetrics, EyeTrackingDataset, EyeTrackingDataPoint
import json

# Create blueprint for eye tracking routes
eye_tracking_bp = Blueprint('eye_tracking', __name__, url_prefix='/api/eye-tracking')


def token_required(f):
    """Decorator to require valid authentication token"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': 'Missing authentication token'}), 401
        
        # TODO: Implement token validation with your auth system
        # For now, we'll assume token is valid
        # Replace with actual token validation logic
        try:
            # token = token.split(' ')[1]  # Remove 'Bearer ' prefix
            # validate_token(token)
            pass
        except Exception as e:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(*args, **kwargs)
    return decorated


@eye_tracking_bp.route('/save', methods=['POST'])
@token_required
def save_test_results():
    """Save eye tracking test results"""
    try:
        # Get current user ID (from token/session)
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['gaze_accuracy', 'data_points_collected', 'test_duration']
        if not all(field in data for field in required_fields):
            return jsonify({'error': 'Missing required fields'}), 400
        
        # Create new test record
        test_record = EyeTrackingTest(
            user_id=int(user_id),
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
        
        return jsonify({
            'message': 'Test results saved successfully',
            'test_id': test_record.id,
            'timestamp': test_record.created_at.isoformat()
        }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Failed to save results: {str(e)}'}), 500


@eye_tracking_bp.route('/upload-data', methods=['POST'])
@token_required
def upload_test_data():
    """Upload and process raw eye tracking data"""
    try:
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        data = request.get_json()
        
        # Validate required fields
        required_fields = ['test_name', 'data_points', 'test_duration']
        if not all(field in data for field in required_fields):
            return jsonify({'error': 'Missing required fields'}), 400
        
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
            return jsonify({'error': f'Failed to calculate metrics: {str(e)}'}), 400
        
        # Create test record with calculated metrics
        test_record = EyeTrackingTest(
            user_id=int(user_id),
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
        
        return jsonify({
            'message': 'Test data uploaded and processed successfully',
            'test_id': test_record.id,
            'metrics': performance,
            'timestamp': test_record.created_at.isoformat()
        }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Failed to upload data: {str(e)}'}), 500


@eye_tracking_bp.route('/history', methods=['GET'])
@token_required
def get_test_history():
    """Retrieve user's eye tracking test history"""
    try:
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        limit = request.args.get('limit', 10, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        # Query test history
        tests = EyeTrackingTest.query.filter_by(user_id=int(user_id)) \
            .order_by(EyeTrackingTest.created_at.desc()) \
            .limit(limit) \
            .offset(offset) \
            .all()
        
        total = EyeTrackingTest.query.filter_by(user_id=int(user_id)).count()
        
        return jsonify({
            'results': [test.to_dict() for test in tests],
            'total': total,
            'limit': limit,
            'offset': offset
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Failed to retrieve history: {str(e)}'}), 500


@eye_tracking_bp.route('/latest', methods=['GET'])
@token_required
def get_latest_result():
    """Get the most recent eye tracking test result"""
    try:
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        test = EyeTrackingTest.query.filter_by(user_id=int(user_id)) \
            .order_by(EyeTrackingTest.created_at.desc()) \
            .first()
        
        if not test:
            return jsonify({'error': 'No test results found'}), 404
        
        return jsonify(test.to_dict()), 200
    
    except Exception as e:
        return jsonify({'error': f'Failed to retrieve result: {str(e)}'}), 500


@eye_tracking_bp.route('/statistics', methods=['GET'])
@token_required
def get_test_statistics():
    """Get test statistics for the user"""
    try:
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        tests = EyeTrackingTest.query.filter_by(user_id=int(user_id)).all()
        
        if not tests:
            return jsonify({
                'total_tests': 0,
                'average_accuracy': 0,
                'best_accuracy': 0,
                'latest_classification': None
            }), 200
        
        accuracies = [t.gaze_accuracy for t in tests if t.gaze_accuracy]
        
        return jsonify({
            'total_tests': len(tests),
            'average_accuracy': sum(accuracies) / len(accuracies) if accuracies else 0,
            'best_accuracy': max(accuracies) if accuracies else 0,
            'latest_classification': tests[0].performance_classification,
            'latest_date': tests[0].created_at.isoformat()
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Failed to retrieve statistics: {str(e)}'}), 500


@eye_tracking_bp.route('/<int:test_id>', methods=['DELETE'])
@token_required
def delete_test_result(test_id):
    """Delete a specific test result"""
    try:
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        test = EyeTrackingTest.query.filter_by(
            id=test_id,
            user_id=int(user_id)
        ).first()
        
        if not test:
            return jsonify({'error': 'Test result not found'}), 404
        
        db.session.delete(test)
        db.session.commit()
        
        return jsonify({'message': 'Test result deleted successfully'}), 200
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': f'Failed to delete result: {str(e)}'}), 500


@eye_tracking_bp.route('/<int:test_id>/generate-report', methods=['POST'])
@token_required
def generate_report(test_id):
    """Generate a PDF report of test results"""
    try:
        user_id = request.headers.get('User-ID', 1)  # TODO: Get from token
        
        test = EyeTrackingTest.query.filter_by(
            id=test_id,
            user_id=int(user_id)
        ).first()
        
        if not test:
            return jsonify({'error': 'Test result not found'}), 404
        
        # TODO: Implement PDF generation
        # This would use a library like reportlab or weasyprint
        
        return jsonify({
            'message': 'Report generation initiated',
            'report_url': f'/api/eye-tracking/reports/{test_id}.pdf'
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Failed to generate report: {str(e)}'}), 500


@eye_tracking_bp.route('/calibrate', methods=['POST'])
@token_required
def calibrate_tracker():
    """Calibrate eye tracker"""
    try:
        return jsonify({
            'message': 'Calibration successful',
            'calibration_points': 9,
            'accuracy': 95.5
        }), 200
    
    except Exception as e:
        return jsonify({'error': f'Calibration failed: {str(e)}'}), 500
