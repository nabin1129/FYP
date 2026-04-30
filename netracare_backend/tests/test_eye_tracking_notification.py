"""Test for eye tracking test notification creation"""

import unittest
import json
from datetime import datetime
from db_model import db, User, EyeTrackingTest
from models.notification import Notification
from backend_app.factory import create_app
from core.security import generate_token


class TestEyeTrackingNotification(unittest.TestCase):
    """Test that eye tracking test submission creates result_ready notification"""
    
    def setUp(self):
        """Set up test client and database"""
        self.app = create_app()
        self.app.config['TESTING'] = True
        self.app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        
        with self.app.app_context():
            db.create_all()
            
            # Create test user
            self.user = User(
                email='eyetrackingtest@example.com',
                password_hash='hashed_pass',
                first_name='Eye',
                last_name='Tracker',
                user_type='patient'
            )
            db.session.add(self.user)
            db.session.commit()
            
            self.user_id = self.user.id
            self.token = generate_token(self.user.id)
        
        self.client = self.app.test_client()
    
    def tearDown(self):
        """Clean up database"""
        with self.app.app_context():
            db.session.remove()
            db.drop_all()
    
    def test_eye_tracking_submission_creates_notification(self):
        """Test that submitting eye tracking test creates result_ready notification"""
        with self.app.app_context():
            # Submit eye tracking test
            response = self.client.post(
                '/eye-tracking/tests',
                headers={'Authorization': f'Bearer {self.token}'},
                json={
                    'test_name': 'Eye Tracking Test',
                    'test_duration': 30.5,
                    'gaze_accuracy': 87.5,
                    'fixation_stability': 92.0,
                    'saccade_consistency': 88.0,
                    'overall_score': 89.2,
                    'classification': 'Good',
                    'screen_width': 1920,
                    'screen_height': 1080
                }
            )
            
            # Verify test was saved
            self.assertEqual(response.status_code, 201)
            data = json.loads(response.data)
            self.assertIn('test_id', data)
            test_id = data['test_id']
            
            # Verify test record exists
            test = EyeTrackingTest.query.get(test_id)
            self.assertIsNotNone(test)
            self.assertEqual(test.user_id, self.user_id)
            self.assertEqual(test.gaze_accuracy, 87.5)
            
            # Verify notification was created
            notification = Notification.query.filter_by(
                recipient_type='user',
                recipient_id=self.user_id,
                notification_type='result_ready',
                related_type='test_result',
                related_id=test_id
            ).first()
            
            self.assertIsNotNone(notification)
            self.assertIn('Eye Tracking', notification.message)
            self.assertEqual(notification.priority, 'normal')
    
    def test_eye_tracking_notification_content(self):
        """Test notification content is correct"""
        with self.app.app_context():
            response = self.client.post(
                '/eye-tracking/tests',
                headers={'Authorization': f'Bearer {self.token}'},
                json={
                    'test_name': 'Saccade Test',
                    'test_duration': 25.0,
                    'gaze_accuracy': 92.0,
                    'fixation_stability': 95.0,
                    'saccade_consistency': 93.5,
                    'overall_score': 93.5,
                    'classification': 'Excellent'
                }
            )
            
            self.assertEqual(response.status_code, 201)
            data = json.loads(response.data)
            test_id = data['test_id']
            
            # Verify notification details
            notification = Notification.query.filter_by(
                related_id=test_id
            ).first()
            
            self.assertEqual(notification.title, 'Test Result Ready')
            self.assertIn('Eye Tracking', notification.message)
            self.assertIn('to view', notification.message)


if __name__ == '__main__':
    unittest.main()
