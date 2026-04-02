"""
Notification Model - User Notifications
Handles system notifications for users and doctors
"""
from datetime import datetime
import json
from db_model import db


class Notification(db.Model):
    """User notifications"""
    __tablename__ = 'notifications'
    
    id = db.Column(db.Integer, primary_key=True)
    
    # Recipient (can be user or doctor)
    recipient_type = db.Column(db.String(10), nullable=False)  # 'user' or 'doctor'
    recipient_id = db.Column(db.Integer, nullable=False)
    
    # Notification content
    notification_type = db.Column(db.String(50), nullable=False)  # consultation_request, test_result, reminder, etc.
    title = db.Column(db.String(200), nullable=False)
    message = db.Column(db.Text, nullable=False)
    
    # Related entity
    related_type = db.Column(db.String(50))  # consultation, test_result, etc.
    related_id = db.Column(db.Integer)
    
    # Action
    action_url = db.Column(db.String(500))
    action_data = db.Column(db.Text)  # JSON additional data
    
    # Status
    is_read = db.Column(db.Boolean, default=False)
    read_at = db.Column(db.DateTime)
    
    # Priority
    priority = db.Column(db.String(10), default='normal')  # low, normal, high, urgent
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    expires_at = db.Column(db.DateTime)  # Optional expiration
    
    def get_action_data(self) -> dict:
        """Get action data as dictionary"""
        return json.loads(self.action_data) if self.action_data else {}
    
    def set_action_data(self, data: dict):
        """Set action data from dictionary"""
        self.action_data = json.dumps(data)
    
    def to_dict(self) -> dict:
        """Convert to dictionary"""
        return {
            'id': self.id,
            'type': self.notification_type,
            'title': self.title,
            'message': self.message,
            'related_type': self.related_type,
            'related_id': self.related_id,
            'action_url': self.action_url,
            'action_data': self.get_action_data(),
            'is_read': self.is_read,
            'priority': self.priority,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'time_ago': self._get_time_ago(),
        }
    
    def _get_time_ago(self) -> str:
        """Get human-readable time ago string"""
        if not self.created_at:
            return 'Just now'
        
        diff = datetime.utcnow() - self.created_at
        seconds = diff.total_seconds()
        
        if seconds < 60:
            return 'Just now'
        elif seconds < 3600:
            minutes = int(seconds / 60)
            return f"{minutes} min{'s' if minutes > 1 else ''} ago"
        elif seconds < 86400:
            hours = int(seconds / 3600)
            return f"{hours} hour{'s' if hours > 1 else ''} ago"
        else:
            days = int(seconds / 86400)
            return f"{days} day{'s' if days > 1 else ''} ago"
    
    @staticmethod
    def create_consultation_request(doctor_id: int, patient_id: int, consultation_id: int, patient_name: str):
        """Create notification for consultation request"""
        return Notification(
            recipient_type='doctor',
            recipient_id=doctor_id,
            notification_type='consultation_request',
            title='New Consultation Request',
            message=f'{patient_name} has requested a consultation with you.',
            related_type='consultation',
            related_id=consultation_id,
            priority='high',
        )
    
    @staticmethod
    def create_consultation_scheduled(patient_id: int, consultation_id: int, doctor_name: str, scheduled_date: str):
        """Create notification for scheduled consultation"""
        return Notification(
            recipient_type='user',
            recipient_id=patient_id,
            notification_type='consultation_scheduled',
            title='Consultation Scheduled',
            message=f'Your consultation with {doctor_name} has been scheduled for {scheduled_date}.',
            related_type='consultation',
            related_id=consultation_id,
            priority='high',
        )
    
    @staticmethod
    def create_test_shared(doctor_id: int, patient_id: int, test_type: str, patient_name: str):
        """Create notification when patient shares test result"""
        return Notification(
            recipient_type='doctor',
            recipient_id=doctor_id,
            notification_type='test_shared',
            title='New Test Result',
            message=f'{patient_name} has shared their {test_type} test results with you.',
            related_type='test_result',
            priority='normal',
        )
    
    @staticmethod
    def create_message_notification(recipient_type: str, recipient_id: int, sender_name: str, consultation_id: int):
        """Create notification for new message"""
        return Notification(
            recipient_type=recipient_type,
            recipient_id=recipient_id,
            notification_type='new_message',
            title='New Message',
            message=f'You have a new message from {sender_name}.',
            related_type='consultation',
            related_id=consultation_id,
            priority='normal',
        )
