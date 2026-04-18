import unittest
from datetime import datetime, timezone

from flask import Flask
from flask_restx import Api

from core.extensions import init_extensions
from db_model import AuthRateLimitEvent, db, User
from features.auth import routes as auth_routes


class AuthRateLimitTestCase(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.app.config.update(
            TESTING=True,
            SECRET_KEY="test-secret-key-that-is-long-enough",
            SQLALCHEMY_DATABASE_URI="sqlite:///:memory:",
            SQLALCHEMY_TRACK_MODIFICATIONS=False,
            JWT_EXP_MINUTES=60,
        )

        init_extensions(self.app)
        api = Api(self.app)
        api.add_namespace(auth_routes.auth_ns)

        with self.app.app_context():
            db.create_all()
            db.session.add(
                User(
                    name="John Doe",
                    email="john@example.com",
                    password_hash=auth_routes.generate_password_hash("Correct@123"),
                )
            )
            db.session.commit()

        self.client = self.app.test_client()
        self._reset_rate_limit_state()

    def tearDown(self):
        self._reset_rate_limit_state()
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def _reset_rate_limit_state(self):
        with self.app.app_context():
            AuthRateLimitEvent.query.delete()
            db.session.commit()

    def test_login_locks_after_repeated_failures(self):
        for _ in range(auth_routes.MAX_LOGIN_FAILURES):
            response = self.client.post(
                "/auth/login",
                json={"email": "john@example.com", "password": "Wrong@123"},
            )
            self.assertEqual(response.status_code, 401)

        locked_response = self.client.post(
            "/auth/login",
            json={"email": "john@example.com", "password": "Wrong@123"},
        )
        self.assertEqual(locked_response.status_code, 429)
        self.assertIn("Retry-After", locked_response.headers)

    def test_login_lockout_is_shared_through_database_rows(self):
        with self.app.app_context():
            for _ in range(auth_routes.MAX_LOGIN_FAILURES):
                db.session.add(
                    AuthRateLimitEvent(
                        kind="login_failure",
                        scope_key="127.0.0.1:john@example.com",
                        created_at=datetime.now(timezone.utc).replace(
                            tzinfo=None,
                            microsecond=0,
                        ),
                    )
                )
            db.session.commit()

        locked_response = self.client.post(
            "/auth/login",
            json={"email": "john@example.com", "password": "Wrong@123"},
        )
        self.assertEqual(locked_response.status_code, 429)
        self.assertIn("Retry-After", locked_response.headers)

    def test_successful_login_clears_failure_window(self):
        fail_response = self.client.post(
            "/auth/login",
            json={"email": "john@example.com", "password": "Wrong@123"},
        )
        self.assertEqual(fail_response.status_code, 401)

        success_response = self.client.post(
            "/auth/login",
            json={"email": "john@example.com", "password": "Correct@123"},
        )
        self.assertEqual(success_response.status_code, 200)

        # Should fail with credentials, not lockout, after successful reset.
        retry_response = self.client.post(
            "/auth/login",
            json={"email": "john@example.com", "password": "Wrong@123"},
        )
        self.assertEqual(retry_response.status_code, 401)

    def test_signup_is_throttled(self):
        email = "jane-throttle@example.com"
        for i in range(auth_routes.MAX_SIGNUP_ATTEMPTS):
            response = self.client.post(
                "/auth/signup",
                json={
                    "name": "Jane User",
                    "email": email,
                    "password": "Strong@123",
                },
            )
            # May return 201 or 400 if validation rejects name pattern; both count as attempts.
            self.assertIn(response.status_code, [201, 400])

        throttled_response = self.client.post(
            "/auth/signup",
            json={
                "name": "Jane User",
                "email": email,
                "password": "Strong@123",
            },
        )
        self.assertEqual(throttled_response.status_code, 429)
        self.assertIn("Retry-After", throttled_response.headers)


if __name__ == "__main__":
    unittest.main()
