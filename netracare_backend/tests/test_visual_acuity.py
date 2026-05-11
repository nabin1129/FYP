"""Tests for Visual Acuity endpoints and model behavior."""

import json
import unittest

from db_model import db, User, VisualAcuityTest
from backend_app.factory import create_app
from core.security import generate_token


class TestVisualAcuityEndpoints(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.app.config["TESTING"] = True
        self.app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///:memory:"

        with self.app.app_context():
            db.create_all()
            self.user = User(
                email="va_user@example.com",
                password_hash="hashed",
                first_name="VA",
                last_name="User",
                user_type="patient",
            )
            db.session.add(self.user)
            db.session.commit()
            self.token = generate_token(self.user.id)

        self.client = self.app.test_client()

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_submit_visual_acuity_creates_record_and_returns_metrics(self):
        with self.app.app_context():
            response = self.client.post(
                "/visual-acuity/tests",
                headers={"Authorization": f"Bearer {self.token}"},
                json={"correct_answers": 8, "total_questions": 10, "test_variant": "snellen"},
            )

            self.assertEqual(response.status_code, 201)
            data = json.loads(response.data)
            # Basic fields
            self.assertIn("id", data)
            self.assertEqual(data["user_id"], self.user.id)
            self.assertIn("score", data)
            self.assertIn("snellen_value", data)
            self.assertIn("severity", data)
            # Verify saved in DB
            test = VisualAcuityTest.query.get(data["id"])
            self.assertIsNotNone(test)
            self.assertEqual(test.correct_answers, 8)
            self.assertEqual(test.total_questions, 10)

    def test_invalid_variant_returns_400(self):
        with self.app.app_context():
            response = self.client.post(
                "/visual-acuity/tests",
                headers={"Authorization": f"Bearer {self.token}"},
                json={"correct_answers": 5, "total_questions": 10, "test_variant": "unknown"},
            )

            self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
