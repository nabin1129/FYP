"""
Distance Calibration Routes
Handles distance calibration data for arm-length enforcement
Author: NetraCare Team
Date: January 26, 2026
"""

from flask import Blueprint, request, jsonify
from functools import wraps
from datetime import datetime
import jwt
from config import Config
from db_model import db, User, DistanceCalibration

distance_bp = Blueprint('distance', __name__, url_prefix='/distance')


def token_required(f):
    """JWT authentication decorator"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'error': 'Token is missing'}), 401
        
        try:
            # Remove 'Bearer ' prefix if present
            if token.startswith('Bearer '):
                token = token[7:]
            
            data = jwt.decode(token, Config.SECRET_KEY, algorithms=['HS256'])
            current_user = User.query.filter_by(id=data['user_id']).first()
            
            if not current_user:
                return jsonify({'error': 'User not found'}), 401
            
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated


@distance_bp.route('/calibrate', methods=['POST'])
@token_required
def save_calibration(current_user):
    """
    Save distance calibration data for user
    
    Request Body:
    {
        "user_id": "string",
        "calibrated_at": "ISO8601 timestamp",
        "reference_distance": 45.0,
        "baseline_ipd_pixels": 120.5,
        "baseline_face_width_pixels": 250.3,
        "focal_length": 850.2,
        "real_world_ipd": 6.3,
        "tolerance_cm": 3.0,
        "device_model": "iPhone 14",
        "camera_resolution": "1920x1080",
        "is_active": true
    }
    """
    try:
        data = request.get_json()
        
        # Validate required fields
        required_fields = [
            'reference_distance',
            'baseline_ipd_pixels',
            'baseline_face_width_pixels',
            'focal_length'
        ]
        
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'Missing required field: {field}'}), 400
        
        # Deactivate all existing calibrations if new one is active
        if data.get('is_active', True):
            DistanceCalibration.query.filter_by(
                user_id=current_user.id,
                is_active=True
            ).update({'is_active': False})
        
        # Create new calibration
        calibration = DistanceCalibration(
            user_id=current_user.id,
            calibrated_at=datetime.utcnow(),
            reference_distance=float(data['reference_distance']),
            baseline_ipd_pixels=float(data['baseline_ipd_pixels']),
            baseline_face_width_pixels=float(data['baseline_face_width_pixels']),
            focal_length=float(data['focal_length']),
            real_world_ipd=float(data.get('real_world_ipd', 6.3)),
            tolerance_cm=float(data.get('tolerance_cm', 3.0)),
            device_model=data.get('device_model'),
            camera_resolution=data.get('camera_resolution'),
            is_active=data.get('is_active', True)
        )
        
        db.session.add(calibration)
        db.session.commit()
        
        return jsonify({
            'message': 'Calibration saved successfully',
            'calibration_id': calibration.id,
            'calibration': calibration.to_dict()
        }), 201
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@distance_bp.route('/calibration/active', methods=['GET'])
@token_required
def get_active_calibration(current_user):
    """
    Get user's active calibration data
    
    Response:
    {
        "calibration": {...} or null
    }
    """
    try:
        calibration = DistanceCalibration.query.filter_by(
            user_id=current_user.id,
            is_active=True
        ).order_by(DistanceCalibration.calibrated_at.desc()).first()
        
        if not calibration:
            return jsonify({'calibration': None}), 404
        
        return jsonify({'calibration': calibration.to_dict()}), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@distance_bp.route('/calibrations', methods=['GET'])
@token_required
def get_all_calibrations(current_user):
    """
    Get all calibrations for current user
    
    Response:
    {
        "calibrations": [...],
        "total": 5
    }
    """
    try:
        calibrations = DistanceCalibration.query.filter_by(
            user_id=current_user.id
        ).order_by(DistanceCalibration.calibrated_at.desc()).all()
        
        return jsonify({
            'calibrations': [c.to_dict() for c in calibrations],
            'total': len(calibrations)
        }), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@distance_bp.route('/calibration/<int:calibration_id>', methods=['DELETE'])
@token_required
def delete_calibration(current_user, calibration_id):
    """Delete a calibration"""
    try:
        calibration = DistanceCalibration.query.filter_by(
            id=calibration_id,
            user_id=current_user.id
        ).first()
        
        if not calibration:
            return jsonify({'error': 'Calibration not found'}), 404
        
        db.session.delete(calibration)
        db.session.commit()
        
        return jsonify({'message': 'Calibration deleted successfully'}), 200
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@distance_bp.route('/calibration/<int:calibration_id>/activate', methods=['PUT'])
@token_required
def activate_calibration(current_user, calibration_id):
    """Set a calibration as active"""
    try:
        # Deactivate all calibrations
        DistanceCalibration.query.filter_by(
            user_id=current_user.id,
            is_active=True
        ).update({'is_active': False})
        
        # Activate target calibration
        calibration = DistanceCalibration.query.filter_by(
            id=calibration_id,
            user_id=current_user.id
        ).first()
        
        if not calibration:
            return jsonify({'error': 'Calibration not found'}), 404
        
        calibration.is_active = True
        db.session.commit()
        
        return jsonify({
            'message': 'Calibration activated',
            'calibration': calibration.to_dict()
        }), 200
    
    except Exception as e:
        db.session.rollback()
        return jsonify({'error': str(e)}), 500


@distance_bp.route('/validate', methods=['POST'])
@token_required
def validate_distance(current_user):
    """
    Server-side distance validation
    
    Request Body:
    {
        "current_distance": 48.5,
        "reference_distance": 45.0
    }
    
    Response:
    {
        "is_valid": true,
        "delta": 3.5,
        "status": "acceptable"
    }
    """
    try:
        data = request.get_json()
        
        current_distance = float(data.get('current_distance', 0))
        reference_distance = float(data.get('reference_distance', 45.0))
        
        delta = current_distance - reference_distance
        abs_delta = abs(delta)
        
        # Validation logic
        if abs_delta <= 1.0:
            status = 'perfect'
            is_valid = True
        elif abs_delta <= 3.0:
            status = 'acceptable'
            is_valid = True
        elif delta < 0:
            status = 'too_close'
            is_valid = False
        else:
            status = 'too_far'
            is_valid = False
        
        return jsonify({
            'is_valid': is_valid,
            'delta': delta,
            'abs_delta': abs_delta,
            'status': status,
            'current_distance': current_distance,
            'reference_distance': reference_distance
        }), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@distance_bp.route('/statistics', methods=['GET'])
@token_required
def get_statistics(current_user):
    """
    Get distance calibration statistics
    
    Response:
    {
        "total_calibrations": 5,
        "active_calibration": {...},
        "average_reference_distance": 45.2,
        "latest_calibration_date": "2026-01-26T..."
    }
    """
    try:
        calibrations = DistanceCalibration.query.filter_by(
            user_id=current_user.id
        ).all()
        
        if not calibrations:
            return jsonify({
                'total_calibrations': 0,
                'active_calibration': None,
                'average_reference_distance': None,
                'latest_calibration_date': None
            }), 200
        
        active = next((c for c in calibrations if c.is_active), None)
        avg_distance = sum(c.reference_distance for c in calibrations) / len(calibrations)
        latest = max(calibrations, key=lambda c: c.calibrated_at)
        
        return jsonify({
            'total_calibrations': len(calibrations),
            'active_calibration': active.to_dict() if active else None,
            'average_reference_distance': round(avg_distance, 2),
            'latest_calibration_date': latest.calibrated_at.isoformat()
        }), 200
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500
