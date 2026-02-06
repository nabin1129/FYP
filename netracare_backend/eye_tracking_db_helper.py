"""
Database Helper for Eye Tracking
Provides functions to save eye tracking results to database
"""

from datetime import datetime
from db_model import db, CameraEyeTrackingSession


def save_eye_tracking_session(user_id: int, stats: dict, session_name: str = None,
                              blink_events: list = None, gaze_events: list = None,
                              notes: str = None) -> int:
    """
    Save eye tracking session to database
    
    Args:
        user_id: User ID
        stats: Statistics dictionary from tracker.get_statistics()
        session_name: Optional session name
        blink_events: Optional list of blink events
        gaze_events: Optional list of gaze movements
        notes: Optional notes
        
    Returns:
        Session ID of the saved record
    """
    
    if "error" in stats:
        raise ValueError("Cannot save session with errors in statistics")
    
    # Extract data from stats
    ear_stats = stats.get('ear_statistics', {})
    left_eye = ear_stats.get('left_eye', {})
    right_eye = ear_stats.get('right_eye', {})
    average = ear_stats.get('average', {})
    gaze_dist = stats.get('gaze_distribution', {})
    
    # Calculate detection rate
    total_frames = stats.get('data_points', 0)
    # Assume all frames had face if no specific count provided
    frames_with_face = total_frames
    detection_rate = 100.0 if total_frames > 0 else 0
    
    # Create session
    session = CameraEyeTrackingSession(
        user_id=user_id,
        session_name=session_name or f"Eye Tracking - {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        duration_seconds=stats['duration_seconds'],
        start_time=datetime.now(),
        end_time=datetime.now(),
        total_blinks=stats['total_blinks'],
        blink_rate_per_minute=stats['blink_rate_per_minute'],
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
        camera_id=0,  # Default camera
        ear_threshold=0.21,  # Default threshold
        notes=notes,
        status='completed'
    )
    
    # Set JSON fields
    session.set_gaze_distribution(gaze_dist)
    
    if blink_events:
        session.set_blink_events(blink_events)
    
    if gaze_events:
        session.set_gaze_events(gaze_events)
    
    db.session.add(session)
    db.session.commit()
    
    return session.id


def get_user_sessions(user_id: int, limit: int = 50, offset: int = 0) -> list:
    """
    Get all sessions for a user
    
    Args:
        user_id: User ID
        limit: Maximum number of sessions to return
        offset: Offset for pagination
        
    Returns:
        List of session dictionaries
    """
    sessions = CameraEyeTrackingSession.query.filter_by(
        user_id=user_id
    ).order_by(
        CameraEyeTrackingSession.created_at.desc()
    ).limit(limit).offset(offset).all()
    
    return [session.to_dict() for session in sessions]


def get_session_by_id(session_id: int, user_id: int = None) -> dict:
    """
    Get a specific session by ID
    
    Args:
        session_id: Session ID
        user_id: Optional user ID for verification
        
    Returns:
        Session dictionary or None
    """
    query = CameraEyeTrackingSession.query.filter_by(id=session_id)
    
    if user_id:
        query = query.filter_by(user_id=user_id)
    
    session = query.first()
    
    return session.to_dict(include_events=True) if session else None


def delete_session(session_id: int, user_id: int) -> bool:
    """
    Delete a session
    
    Args:
        session_id: Session ID
        user_id: User ID for verification
        
    Returns:
        True if deleted, False if not found
    """
    session = CameraEyeTrackingSession.query.filter_by(
        id=session_id,
        user_id=user_id
    ).first()
    
    if not session:
        return False
    
    db.session.delete(session)
    db.session.commit()
    
    return True


def get_user_statistics(user_id: int) -> dict:
    """
    Get aggregate statistics for a user
    
    Args:
        user_id: User ID
        
    Returns:
        Dictionary of aggregate statistics
    """
    sessions = CameraEyeTrackingSession.query.filter_by(user_id=user_id).all()
    
    if not sessions:
        return {
            'total_sessions': 0,
            'message': 'No sessions found'
        }
    
    total_sessions = len(sessions)
    total_blinks = sum(s.total_blinks for s in sessions)
    avg_blink_rate = sum(s.blink_rate_per_minute for s in sessions if s.blink_rate_per_minute) / total_sessions
    total_duration = sum(s.duration_seconds for s in sessions)
    
    # Average EAR values
    avg_left_ear = sum(s.left_eye_ear_mean for s in sessions if s.left_eye_ear_mean) / total_sessions
    avg_right_ear = sum(s.right_eye_ear_mean for s in sessions if s.right_eye_ear_mean) / total_sessions
    avg_overall_ear = sum(s.average_ear_mean for s in sessions if s.average_ear_mean) / total_sessions
    
    return {
        'total_sessions': total_sessions,
        'total_blinks': total_blinks,
        'average_blink_rate_per_minute': round(avg_blink_rate, 2),
        'total_duration_seconds': round(total_duration, 2),
        'average_duration_per_session': round(total_duration / total_sessions, 2),
        'average_ear_values': {
            'left_eye': round(avg_left_ear, 3),
            'right_eye': round(avg_right_ear, 3),
            'overall': round(avg_overall_ear, 3)
        }
    }
