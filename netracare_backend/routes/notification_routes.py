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

reminder_model = notification_ns.model('ReminderCreate', {
    'recipient_type': fields.String(required=True, description='user or doctor'),
    'recipient_id': fields.Integer(required=True, description='Target user/doctor id'),
    'title': fields.String(required=True, description='Reminder title'),
    'message': fields.String(required=True, description='Reminder message body'),
    'priority': fields.String(description='low, normal, high, urgent'),
    'related_type': fields.String(description='Optional related entity type'),
    'related_id': fields.Integer(description='Optional related entity id'),
    'scheduled_for': fields.String(description='Optional ISO datetime for follow-up context'),
})


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


# ==========================
# REMINDER CREATION (ADMIN/DOCTOR)
# ==========================

@notification_ns.route('/admin/reminders')
class CreateAdminReminder(Resource):
    """Create a follow-up reminder as admin."""

    @notification_ns.expect(reminder_model)
    def post(self):
        """Create in-app reminder notification for user/doctor."""
        try:
            data = request.get_json() or {}

            recipient_type = (data.get('recipient_type') or '').strip().lower()
            recipient_id = data.get('recipient_id')
            title = (data.get('title') or '').strip()
            message = (data.get('message') or '').strip()

            if recipient_type not in {'user', 'doctor'}:
                return {'message': 'recipient_type must be user or doctor'}, 400
            if not isinstance(recipient_id, int):
                return {'message': 'recipient_id must be an integer'}, 400
            if not title or not message:
                return {'message': 'title and message are required'}, 400

            notification = Notification(
                recipient_type=recipient_type,
                recipient_id=recipient_id,
                notification_type='reminder',
                title=title,
                message=message,
                related_type=data.get('related_type'),
                related_id=data.get('related_id'),
                priority=(data.get('priority') or 'normal').lower(),
            )

            action_data = {
                'created_by_role': 'admin',
                'created_by': 'local_admin',
            }
            if data.get('scheduled_for'):
                action_data['scheduled_for'] = data.get('scheduled_for')
            notification.set_action_data(action_data)

            db.session.add(notification)
            db.session.commit()

            return {
                'message': 'Reminder created successfully',
                'notification': notification.to_dict(),
            }, 201
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to create reminder: {str(e)}'}, 500


@notification_ns.route('/doctor/reminders')
class CreateDoctorReminder(Resource):
    """Create a follow-up reminder as doctor."""

    @notification_ns.doc(security='Bearer')
    @notification_ns.expect(reminder_model)
    @doctor_token_required
    def post(self, current_doctor):
        """Create in-app reminder notification for patient users."""
        try:
            data = request.get_json() or {}

            recipient_type = (data.get('recipient_type') or '').strip().lower()
            recipient_id = data.get('recipient_id')
            title = (data.get('title') or '').strip()
            message = (data.get('message') or '').strip()

            if recipient_type != 'user':
                return {'message': 'Doctor reminders can only target users'}, 400
            if not isinstance(recipient_id, int):
                return {'message': 'recipient_id must be an integer'}, 400
            if not title or not message:
                return {'message': 'title and message are required'}, 400

            notification = Notification(
                recipient_type='user',
                recipient_id=recipient_id,
                notification_type='reminder',
                title=title,
                message=message,
                related_type=data.get('related_type') or 'followup',
                related_id=data.get('related_id'),
                priority=(data.get('priority') or 'normal').lower(),
            )

            action_data = {
                'created_by_role': 'doctor',
                'doctor_id': current_doctor.id,
                'doctor_name': current_doctor.name,
            }
            if data.get('scheduled_for'):
                action_data['scheduled_for'] = data.get('scheduled_for')
            notification.set_action_data(action_data)

            db.session.add(notification)
            db.session.commit()

            return {
                'message': 'Reminder created successfully',
                'notification': notification.to_dict(),
            }, 201
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to create reminder: {str(e)}'}, 500
