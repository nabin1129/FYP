"""
Distance Calibration Routes
ARCore/ARKit integration for accurate distance measurement
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from datetime import datetime, timedelta

from db_model import db
from models.distance_calibration import DistanceCalibration
from core.security import token_required

# Create namespace
calibration_ns = Namespace('calibration', description='Distance calibration operations')

# API Models
calibration_model = calibration_ns.model('Calibration', {
    'calibration_method': fields.String(required=True, description='arcore, arkit, manual, credit_card'),
    'platform': fields.String(description='android or ios'),
    'measured_distance_cm': fields.Float(required=True, description='Measured distance in cm'),
    'target_distance_cm': fields.Float(default=100.0, description='Target distance (default 100cm)'),
    'device_model': fields.String(description='Device model'),
    'screen_size_inches': fields.Float(description='Screen size'),
    'camera_resolution': fields.String(description='Camera resolution'),
    'reference_object': fields.String(description='Reference object used'),
    'reference_object_size_cm': fields.Float(description='Reference object size'),
    'ar_session_data': fields.Raw(description='AR session data (JSON)'),
    'tracking_quality': fields.String(description='AR tracking quality')
})


@calibration_ns.route('/calibrate')
class Calibrate(Resource):
    """Calibrate distance for visual acuity tests"""
    
    @calibration_ns.doc(security='Bearer')
    @calibration_ns.expect(calibration_model)
    @token_required
    def post(self, current_user):
        """Submit distance calibration"""
        try:
            data = request.get_json()
            
            # Calculate accuracy
            target = data.get('target_distance_cm', 100.0)
            measured = data['measured_distance_cm']
            accuracy = (1 - abs(target - measured) / target) * 100
            
            # Create calibration record
            calibration = DistanceCalibration(
                user_id=current_user.id,
                calibration_method=data['calibration_method'],
                platform=data.get('platform'),
                measured_distance_cm=measured,
                target_distance_cm=target,
                calibration_accuracy=accuracy,
                device_model=data.get('device_model'),
                screen_size_inches=data.get('screen_size_inches'),
                camera_resolution=data.get('camera_resolution'),
                reference_object=data.get('reference_object'),
                reference_object_size_cm=data.get('reference_object_size_cm'),
                tracking_quality=data.get('tracking_quality'),
                is_validated=accuracy >= 90.0,  # Auto-validate if accuracy is high
                validation_timestamp=datetime.utcnow() if accuracy >= 90.0 else None,
                expires_at=datetime.utcnow() + timedelta(days=30)  # Calibration valid for 30 days
            )
            
            # Set AR session data if provided
            if 'ar_session_data' in data:
                calibration.set_ar_session_data(data['ar_session_data'])
            
            db.session.add(calibration)
            db.session.commit()
            
            return {
                'message': 'Calibration completed successfully',
                'calibration': calibration.to_dict(),
                'accuracy': accuracy,
                'is_validated': calibration.is_validated
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Calibration failed: {str(e)}'}, 500


@calibration_ns.route('/latest')
class LatestCalibration(Resource):
    """Get user's latest valid calibration"""
    
    @calibration_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get most recent valid calibration"""
        try:
            now = datetime.utcnow()
            calibration = DistanceCalibration.query.filter(
                DistanceCalibration.user_id == current_user.id,
                DistanceCalibration.is_validated == True,
                DistanceCalibration.expires_at > now
            ).order_by(DistanceCalibration.created_at.desc()).first()
            
            if not calibration:
                return {
                    'message': 'No valid calibration found',
                    'calibration': None
                }, 200
            
            return {
                'message': 'Latest calibration retrieved',
                'calibration': calibration.to_dict()
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to get calibration: {str(e)}'}, 500


@calibration_ns.route('/history')
class CalibrationHistory(Resource):
    """Get calibration history"""
    
    @calibration_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get all calibrations for current user"""
        try:
            calibrations = DistanceCalibration.query.filter_by(
                user_id=current_user.id
            ).order_by(DistanceCalibration.created_at.desc()).all()
            
            return {
                'message': 'Calibration history retrieved',
                'calibrations': [cal.to_dict() for cal in calibrations],
                'total': len(calibrations)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to get history: {str(e)}'}, 500

