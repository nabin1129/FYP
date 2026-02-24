"""
Notification Routes - Notification Management API
Handles user and doctor notifications
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from datetime import datetime
from sqlalchemy import desc

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from db_model import db
from models.notification import Notification
from auth_utils import token_required
from routes.doctor_routes import doctor_token_required

# Create namespace
notification_ns = Namespace('notifications', description='Notification management')


# ==========================
# USER NOTIFICATION ROUTES
# ==========================

@notification_ns.route('/user')
class UserNotifications(Resource):
    """User notifications"""
    
    @notification_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get user notifications"""
        try:
            unread_only = request.args.get('unread', 'false').lower() == 'true'
            limit = request.args.get('limit', 50, type=int)
            
            query = Notification.query.filter_by(
                recipient_type='user',
                recipient_id=current_user.id
            )
            
            if unread_only:
                query = query.filter_by(is_read=False)
            
            notifications = query.order_by(
                desc(Notification.created_at)
            ).limit(limit).all()
            
            unread_count = Notification.query.filter_by(
                recipient_type='user',
                recipient_id=current_user.id,
                is_read=False
            ).count()
            
            return {
                'notifications': [n.to_dict() for n in notifications],
                'unread_count': unread_count
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch notifications: {str(e)}'}, 500


@notification_ns.route('/user/count')
class UserNotificationCount(Resource):
    """User unread notification count"""
    
    @notification_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get unread notification count"""
        try:
            count = Notification.query.filter_by(
                recipient_type='user',
                recipient_id=current_user.id,
                is_read=False
            ).count()
            
            return {'unread_count': count}, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch count: {str(e)}'}, 500


@notification_ns.route('/user/<int:notification_id>/read')
class MarkUserNotificationRead(Resource):
    """Mark notification as read"""
    
    @notification_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user, notification_id):
        """Mark a notification as read"""
        try:
            notification = Notification.query.get(notification_id)
            
            if not notification:
                return {'message': 'Notification not found'}, 404
            
            if notification.recipient_type != 'user' or notification.recipient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            notification.is_read = True
            notification.read_at = datetime.utcnow()
            db.session.commit()
            
            return {'message': 'Notification marked as read'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to mark as read: {str(e)}'}, 500


@notification_ns.route('/user/read-all')
class MarkAllUserNotificationsRead(Resource):
    """Mark all notifications as read"""
    
    @notification_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """Mark all notifications as read"""
        try:
            Notification.query.filter_by(
                recipient_type='user',
                recipient_id=current_user.id,
                is_read=False
            ).update({
                'is_read': True,
                'read_at': datetime.utcnow()
            })
            
            db.session.commit()
            
            return {'message': 'All notifications marked as read'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to mark all as read: {str(e)}'}, 500


# ==========================
# DOCTOR NOTIFICATION ROUTES
# ==========================

@notification_ns.route('/doctor')
class DoctorNotifications(Resource):
    """Doctor notifications"""
    
    @notification_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get doctor notifications"""
        try:
            unread_only = request.args.get('unread', 'false').lower() == 'true'
            limit = request.args.get('limit', 50, type=int)
            
            query = Notification.query.filter_by(
                recipient_type='doctor',
                recipient_id=current_doctor.id
            )
            
            if unread_only:
                query = query.filter_by(is_read=False)
            
            notifications = query.order_by(
                desc(Notification.created_at)
            ).limit(limit).all()
            
            unread_count = Notification.query.filter_by(
                recipient_type='doctor',
                recipient_id=current_doctor.id,
                is_read=False
            ).count()
            
            return {
                'notifications': [n.to_dict() for n in notifications],
                'unread_count': unread_count
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch notifications: {str(e)}'}, 500


@notification_ns.route('/doctor/count')
class DoctorNotificationCount(Resource):
    """Doctor unread notification count"""
    
    @notification_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get unread notification count"""
        try:
            count = Notification.query.filter_by(
                recipient_type='doctor',
                recipient_id=current_doctor.id,
                is_read=False
            ).count()
            
            return {'unread_count': count}, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch count: {str(e)}'}, 500


@notification_ns.route('/doctor/<int:notification_id>/read')
class MarkDoctorNotificationRead(Resource):
    """Mark notification as read (doctor)"""
    
    @notification_ns.doc(security='Bearer')
    @doctor_token_required
    def post(self, current_doctor, notification_id):
        """Mark a notification as read"""
        try:
            notification = Notification.query.get(notification_id)
            
            if not notification:
                return {'message': 'Notification not found'}, 404
            
            if notification.recipient_type != 'doctor' or notification.recipient_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            notification.is_read = True
            notification.read_at = datetime.utcnow()
            db.session.commit()
            
            return {'message': 'Notification marked as read'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to mark as read: {str(e)}'}, 500


@notification_ns.route('/doctor/read-all')
class MarkAllDoctorNotificationsRead(Resource):
    """Mark all doctor notifications as read"""
    
    @notification_ns.doc(security='Bearer')
    @doctor_token_required
    def post(self, current_doctor):
        """Mark all notifications as read"""
        try:
            Notification.query.filter_by(
                recipient_type='doctor',
                recipient_id=current_doctor.id,
                is_read=False
            ).update({
                'is_read': True,
                'read_at': datetime.utcnow()
            })
            
            db.session.commit()
            
            return {'message': 'All notifications marked as read'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to mark all as read: {str(e)}'}, 500


# ==========================
# DELETE NOTIFICATIONS
# ==========================

@notification_ns.route('/user/<int:notification_id>')
class DeleteUserNotification(Resource):
    """Delete user notification"""
    
    @notification_ns.doc(security='Bearer')
    @token_required
    def delete(self, current_user, notification_id):
        """Delete a notification"""
        try:
            notification = Notification.query.get(notification_id)
            
            if not notification:
                return {'message': 'Notification not found'}, 404
            
            if notification.recipient_type != 'user' or notification.recipient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            db.session.delete(notification)
            db.session.commit()
            
            return {'message': 'Notification deleted'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to delete: {str(e)}'}, 500


@notification_ns.route('/doctor/<int:notification_id>/delete')
class DeleteDoctorNotification(Resource):
    """Delete doctor notification"""
    
    @notification_ns.doc(security='Bearer')
    @doctor_token_required
    def delete(self, current_doctor, notification_id):
        """Delete a notification"""
        try:
            notification = Notification.query.get(notification_id)
            
            if not notification:
                return {'message': 'Notification not found'}, 404
            
            if notification.recipient_type != 'doctor' or notification.recipient_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            db.session.delete(notification)
            db.session.commit()
            
            return {'message': 'Notification deleted'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to delete: {str(e)}'}, 500
