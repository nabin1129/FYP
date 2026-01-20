"""
API Routes for Camera-Based Eye Tracking (OpenCV + MediaPipe)
"""

from flask import request, jsonify
from flask_restx import Namespace, Resource, fields
from datetime import datetime
from db_model import db, CameraEyeTrackingSession, User
from auth_utils import token_required

# Create namespace
camera_eye_tracking_ns = Namespace('camera-eye-tracking', description='Camera-based eye tracking operations')

# API Models for documentation
session_model = camera_eye_tracking_ns.model('CameraEyeTrackingSession', {
    'session_name': fields.String(required=False, description='Session name'),
    'duration_seconds': fields.Float(required=True, description='Session duration in seconds'),
    'total_blinks': fields.Integer(required=True, description='Total blinks detected'),
    'blink_rate_per_minute': fields.Float(required=True, description='Blink rate per minute'),
    'ear_statistics': fields.Raw(required=True, description='EAR statistics'),
    'gaze_distribution': fields.Raw(required=True, description='Gaze direction distribution'),
    'total_frames': fields.Integer(required=True, description='Total frames processed'),
    'frames_with_face': fields.Integer(required=True, description='Frames with face detected'),
    'camera_id': fields.Integer(required=False, description='Camera device ID', default=0),
    'ear_threshold': fields.Float(required=False, description='EAR threshold used', default=0.21),
    'notes': fields.String(required=False, description='Additional notes')
})


@camera_eye_tracking_ns.route('/sessions')
class CameraEyeTrackingSessions(Resource):
    @token_required
    @camera_eye_tracking_ns.doc('create_session')
    @camera_eye_tracking_ns.expect(session_model)
    def post(current_user, self):
        """Create a new camera eye tracking session"""
        try:
            data = request.get_json()
            
            # Extract statistics
            ear_stats = data.get('ear_statistics', {})
            left_eye = ear_stats.get('left_eye', {})
            right_eye = ear_stats.get('right_eye', {})
            average = ear_stats.get('average', {})
            
            gaze_dist = data.get('gaze_distribution', {})
            
            # Calculate detection rate
            total_frames = data.get('total_frames', 0)
            frames_with_face = data.get('frames_with_face', 0)
            detection_rate = (frames_with_face / total_frames * 100) if total_frames > 0 else 0
            
            # Create session
            session = CameraEyeTrackingSession(
                user_id=current_user.id,
                session_name=data.get('session_name', 'Camera Eye Tracking Session'),
                duration_seconds=data['duration_seconds'],
                start_time=datetime.utcnow(),
                end_time=datetime.utcnow(),
                total_blinks=data['total_blinks'],
                blink_rate_per_minute=data['blink_rate_per_minute'],
                left_eye_ear_mean=left_eye.get('mean'),
                left_eye_ear_std=left_eye.get('std'),
                left_eye_ear_min=left_eye.get('min'),
                left_eye_ear_max=left_eye.get('max'),
                right_eye_ear_mean=right_eye.get('mean'),
                right_eye_ear_std=right_eye.get('std'),
                right_eye_ear_min=right_eye.get('min'),
                right_eye_ear_max=right_eye.get('max'),
                average_ear_mean=average.get('mean'),
                average_ear_std=average.get('std'),
                average_ear_min=average.get('min'),
                average_ear_max=average.get('max'),
                total_frames=total_frames,
                frames_with_face=frames_with_face,
                detection_rate=detection_rate,
                camera_id=data.get('camera_id', 0),
                ear_threshold=data.get('ear_threshold', 0.21),
                notes=data.get('notes'),
                status='completed'
            )
            
            # Set JSON fields
            session.set_gaze_distribution(gaze_dist)
            
            # Optional: Store detailed events
            if 'blink_events' in data:
                session.set_blink_events(data['blink_events'])
            
            if 'gaze_events' in data:
                session.set_gaze_events(data['gaze_events'])
            
            db.session.add(session)
            db.session.commit()
            
            return {
                'message': 'Eye tracking session saved successfully',
                'session_id': session.id,
                'session': session.to_dict()
            }, 201
            
        except KeyError as e:
            return {'message': f'Missing required field: {str(e)}'}, 400
        except Exception as e:
            db.session.rollback()
            return {'message': f'Error saving session: {str(e)}'}, 500
    
    @token_required
    @camera_eye_tracking_ns.doc('get_sessions')
    def get(current_user, self):
        """Get all camera eye tracking sessions for the current user"""
        try:
            # Query parameters
            limit = request.args.get('limit', 50, type=int)
            offset = request.args.get('offset', 0, type=int)
            include_events = request.args.get('include_events', 'false').lower() == 'true'
            
            # Get sessions
            sessions = CameraEyeTrackingSession.query.filter_by(
                user_id=current_user.id
            ).order_by(
                CameraEyeTrackingSession.created_at.desc()
            ).limit(limit).offset(offset).all()
            
            return {
                'sessions': [session.to_dict(include_events=include_events) for session in sessions],
                'total': CameraEyeTrackingSession.query.filter_by(user_id=current_user.id).count(),
                'limit': limit,
                'offset': offset
            }, 200
            
        except Exception as e:
            return {'message': f'Error retrieving sessions: {str(e)}'}, 500


@camera_eye_tracking_ns.route('/sessions/<int:session_id>')
class CameraEyeTrackingSessionDetail(Resource):
    @token_required
    @camera_eye_tracking_ns.doc('get_session')
    def get(current_user, self, session_id):
        """Get a specific camera eye tracking session"""
        try:
            include_events = request.args.get('include_events', 'false').lower() == 'true'
            
            session = CameraEyeTrackingSession.query.filter_by(
                id=session_id,
                user_id=current_user.id
            ).first()
            
            if not session:
                return {'message': 'Session not found'}, 404
            
            return session.to_dict(include_events=include_events), 200
            
        except Exception as e:
            return {'message': f'Error retrieving session: {str(e)}'}, 500
    
    @token_required
    @camera_eye_tracking_ns.doc('delete_session')
    def delete(current_user, self, session_id):
        """Delete a camera eye tracking session"""
        try:
            session = CameraEyeTrackingSession.query.filter_by(
                id=session_id,
                user_id=current_user.id
            ).first()
            
            if not session:
                return {'message': 'Session not found'}, 404
            
            db.session.delete(session)
            db.session.commit()
            
            return {'message': 'Session deleted successfully'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Error deleting session: {str(e)}'}, 500


@camera_eye_tracking_ns.route('/sessions/<int:session_id>/update')
class CameraEyeTrackingSessionUpdate(Resource):
    @token_required
    @camera_eye_tracking_ns.doc('update_session')
    def put(current_user, self, session_id):
        """Update session notes or name"""
        try:
            data = request.get_json()
            
            session = CameraEyeTrackingSession.query.filter_by(
                id=session_id,
                user_id=current_user.id
            ).first()
            
            if not session:
                return {'message': 'Session not found'}, 404
            
            # Update fields
            if 'session_name' in data:
                session.session_name = data['session_name']
            
            if 'notes' in data:
                session.notes = data['notes']
            
            if 'status' in data:
                session.status = data['status']
            
            db.session.commit()
            
            return {
                'message': 'Session updated successfully',
                'session': session.to_dict()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Error updating session: {str(e)}'}, 500


@camera_eye_tracking_ns.route('/statistics')
class CameraEyeTrackingStatistics(Resource):
    @token_required
    @camera_eye_tracking_ns.doc('get_statistics')
    def get(current_user, self):
        """Get overall statistics for all sessions"""
        try:
            sessions = CameraEyeTrackingSession.query.filter_by(
                user_id=current_user.id
            ).all()
            
            if not sessions:
                return {
                    'total_sessions': 0,
                    'message': 'No sessions found'
                }, 200
            
            # Calculate aggregate statistics
            total_sessions = len(sessions)
            total_blinks = sum(s.total_blinks for s in sessions)
            avg_blink_rate = sum(s.blink_rate_per_minute for s in sessions if s.blink_rate_per_minute) / total_sessions
            avg_detection_rate = sum(s.detection_rate for s in sessions if s.detection_rate) / total_sessions
            total_duration = sum(s.duration_seconds for s in sessions)
            
            # Average EAR values
            avg_left_ear = sum(s.left_eye_ear_mean for s in sessions if s.left_eye_ear_mean) / total_sessions
            avg_right_ear = sum(s.right_eye_ear_mean for s in sessions if s.right_eye_ear_mean) / total_sessions
            avg_overall_ear = sum(s.average_ear_mean for s in sessions if s.average_ear_mean) / total_sessions
            
            # Recent sessions
            recent_sessions = sorted(sessions, key=lambda x: x.created_at, reverse=True)[:5]
            
            return {
                'total_sessions': total_sessions,
                'total_blinks': total_blinks,
                'average_blink_rate_per_minute': round(avg_blink_rate, 2),
                'average_detection_rate': round(avg_detection_rate, 2),
                'total_duration_seconds': round(total_duration, 2),
                'average_ear_values': {
                    'left_eye': round(avg_left_ear, 3),
                    'right_eye': round(avg_right_ear, 3),
                    'overall': round(avg_overall_ear, 3)
                },
                'recent_sessions': [s.to_dict() for s in recent_sessions]
            }, 200
            
        except Exception as e:
            return {'message': f'Error calculating statistics: {str(e)}'}, 500


@camera_eye_tracking_ns.route('/compare')
class CameraEyeTrackingComparison(Resource):
    @token_required
    @camera_eye_tracking_ns.doc('compare_sessions')
    def post(current_user, self):
        """Compare multiple sessions"""
        try:
            data = request.get_json()
            session_ids = data.get('session_ids', [])
            
            if len(session_ids) < 2:
                return {'message': 'At least 2 session IDs required for comparison'}, 400
            
            sessions = CameraEyeTrackingSession.query.filter(
                CameraEyeTrackingSession.id.in_(session_ids),
                CameraEyeTrackingSession.user_id == current_user.id
            ).all()
            
            if len(sessions) != len(session_ids):
                return {'message': 'Some sessions not found'}, 404
            
            comparison = {
                'sessions': [s.to_dict() for s in sessions],
                'comparison_metrics': {
                    'blink_rates': [s.blink_rate_per_minute for s in sessions],
                    'detection_rates': [s.detection_rate for s in sessions],
                    'average_ears': [s.average_ear_mean for s in sessions],
                    'durations': [s.duration_seconds for s in sessions]
                }
            }
            
            return comparison, 200
            
        except Exception as e:
            return {'message': f'Error comparing sessions: {str(e)}'}, 500
