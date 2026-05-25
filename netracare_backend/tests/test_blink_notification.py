"""Test for blink & fatigue test notification creation"""

import unittest
import json
from datetime import datetime
from db_model import db, User, BlinkFatigueTest
from models.notification import Notification
from backend_app.factory import create_app
from core.security import generate_token


class TestBlinkNotification(unittest.TestCase):
    """Test that blink test submission creates result_ready notification"""

    def setUp(self):
        """Set up test client and database"""
        self.app = create_app()
        self.app.config["TESTING"] = True
        self.app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"

        with self.app.app_context():
            db.create_all()

            # Create test user
            self.user = User(
                email="testuser@example.com",
                password_hash="hashed_pass",
                first_name="Test",
                last_name="User",
                user_type="patient",
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

    def test_blink_submission_creates_notification(self):
        """Test that submitting blink test creates result_ready notification"""
        with self.app.app_context():
            # Submit blink test
            response = self.client.post(
                "/blink-detection/submit",
                headers={"Authorization": f"Bearer {self.token}"},
                json={
                    "blink_count": 25,
                    "duration_seconds": 40,
                    "drowsiness_probability": 0.35,
                    "confidence_score": 0.92,
                    "fatigue_level": "Alert",
                },
            )

            # Verify test was saved
            self.assertEqual(response.status_code, 201)
            data = json.loads(response.data)
            self.assertIn("test_id", data)
            test_id = data["test_id"]

            # Verify test record exists
            test = BlinkFatigueTest.query.get(test_id)
            self.assertIsNotNone(test)
            self.assertEqual(test.user_id, self.user_id)
            self.assertEqual(test.total_blinks, 25)

            # Verify notification was created
            notification = Notification.query.filter_by(
                recipient_type="user",
                recipient_id=self.user_id,
                notification_type="result_ready",
                related_type="test_result",
                related_id=test_id,
            ).first()

            self.assertIsNotNone(notification)
            self.assertIn("Blink & Fatigue", notification.message)
            self.assertEqual(notification.priority, "normal")

    def test_blink_submission_notification_content(self):
        """Test notification content is correct"""
        with self.app.app_context():
            response = self.client.post(
                "/blink-detection/submit",
                headers={"Authorization": f"Bearer {self.token}"},
                json={
                    "blink_count": 20,
                    "duration_seconds": 40,
                    "drowsiness_probability": 0.5,
                    "confidence_score": 0.88,
                },
            )

            self.assertEqual(response.status_code, 201)
            data = json.loads(response.data)
            test_id = data["test_id"]

            # Verify notification details
            notification = Notification.query.filter_by(related_id=test_id).first()

            self.assertEqual(notification.title, "Test Result Ready")
            self.assertIn("Blink & Fatigue", notification.message)
            self.assertTrue(notification.message.endswith("to view."))


if __name__ == "__main__":
    unittest.main()
