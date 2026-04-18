# auth.py
from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta, timezone
import jwt
import re
import random
import string
import requests as http_requests

from db_model import AuthRateLimitEvent, db, User
from core.config import BaseConfig
from core.mailer import send_otp_email

auth_ns = Namespace(
    "auth",
    description="Authentication APIs"
)


# -----------------------------
# RATE LIMITING / LOCKOUT (in-memory)
# -----------------------------
SIGNUP_WINDOW_SECONDS = 3600
MAX_SIGNUP_ATTEMPTS = 5

FORGOT_PASSWORD_WINDOW_SECONDS = 3600
MAX_FORGOT_PASSWORD_ATTEMPTS = 5

LOGIN_FAILURE_WINDOW_SECONDS = 900
MAX_LOGIN_FAILURES = 6


def _client_ip() -> str:
    forwarded = request.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip() or "unknown"
    return request.remote_addr or "unknown"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None, microsecond=0)


def _rate_limit_cutoff(window_seconds: int) -> datetime:
    return _utcnow() - timedelta(seconds=window_seconds)


def _login_is_locked(key: str):
    cutoff = _rate_limit_cutoff(LOGIN_FAILURE_WINDOW_SECONDS)
    failures = (
        AuthRateLimitEvent.query.filter_by(kind="login_failure", scope_key=key)
        .filter(AuthRateLimitEvent.created_at >= cutoff)
        .order_by(AuthRateLimitEvent.created_at.asc())
        .all()
    )
    if len(failures) >= MAX_LOGIN_FAILURES:
        oldest = failures[0].created_at or _utcnow()
        retry_after = max(
            1,
            int(LOGIN_FAILURE_WINDOW_SECONDS - (_utcnow() - oldest).total_seconds()),
        )
        return True, retry_after
    return False, 0


def _record_rate_limit_event(kind: str, key: str, window_seconds: int) -> None:
    cutoff = _rate_limit_cutoff(window_seconds)
    AuthRateLimitEvent.query.filter_by(kind=kind, scope_key=key).filter(
        AuthRateLimitEvent.created_at < cutoff
    ).delete(synchronize_session=False)
    db.session.add(
        AuthRateLimitEvent(
            kind=kind,
            scope_key=key,
            created_at=_utcnow(),
        )
    )
    db.session.commit()


def _clear_login_failures(key: str) -> None:
    AuthRateLimitEvent.query.filter_by(kind="login_failure", scope_key=key).delete(
        synchronize_session=False
    )
    db.session.commit()


def _rate_limit_response(message: str, retry_after: int):
    return {
        "message": message,
    }, 429, {"Retry-After": str(retry_after)}

# -----------------------------
# PASSWORD POLICY (STRONG)
# -----------------------------
PASSWORD_REGEX = re.compile(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
)

# -----------------------------
# Swagger Models
# -----------------------------
signup_model = auth_ns.model("Signup", {
    "name": fields.String(required=True),
    "email": fields.String(required=True),
    "password": fields.String(required=True),
    "age": fields.Integer(required=False),
    "sex": fields.String(required=False),
})

login_model = auth_ns.model("Login", {
    "email": fields.String(required=True),
    "password": fields.String(required=True),
})

auth_response = auth_ns.model("AuthResponse", {
    "token": fields.String,
    "user": fields.Raw,
})

# -----------------------------
# Helper Functions
# -----------------------------
def generate_token(user_id: int) -> str:
    now = datetime.now(timezone.utc)
    exp_time = now + timedelta(minutes=BaseConfig.JWT_EXP_MINUTES)
    payload = {
        "sub": str(user_id),  # JWT standard requires sub to be a string
        "iat": int(now.timestamp()),
        "exp": int(exp_time.timestamp()),
    }
    token = jwt.encode(payload, BaseConfig.SECRET_KEY, algorithm="HS256")
    # Ensure token is always a string (PyJWT 2.x returns string, but be safe)
    if isinstance(token, bytes):
        return token.decode('utf-8')
    return token


def user_to_dict(user: User) -> dict:
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "age": user.age,
        "sex": user.sex,
    }

# -----------------------------
# SIGNUP
# -----------------------------
@auth_ns.route("/signup")
class Signup(Resource):

    @auth_ns.expect(signup_model)
    @auth_ns.marshal_with(auth_response, code=201)
    def post(self):
        data = request.get_json()

        if not data:
            auth_ns.abort(400, "Invalid JSON body")

        email = data.get("email", "").strip().lower()
        signup_key = f"{_client_ip()}:{email or 'unknown'}"
        cutoff = _rate_limit_cutoff(SIGNUP_WINDOW_SECONDS)
        attempts = (
            AuthRateLimitEvent.query.filter_by(kind="signup_attempt", scope_key=signup_key)
            .filter(AuthRateLimitEvent.created_at >= cutoff)
            .order_by(AuthRateLimitEvent.created_at.asc())
            .all()
        )
        if len(attempts) >= MAX_SIGNUP_ATTEMPTS:
            oldest = attempts[0].created_at or _utcnow()
            retry_after = max(
                1,
                int(
                    SIGNUP_WINDOW_SECONDS
                    - (_utcnow() - oldest).total_seconds()
                ),
            )
            return _rate_limit_response(
                f"Too many signup attempts. Try again in {retry_after} seconds.",
                retry_after,
            )

        _record_rate_limit_event("signup_attempt", signup_key, SIGNUP_WINDOW_SECONDS)

        # Check email duplication
        if User.query.filter_by(email=email).first():
            auth_ns.abort(400, "Email already registered")

        password = data["password"]

        # 🔐 Strong password validation
        if not PASSWORD_REGEX.match(password):
            auth_ns.abort(
                400,
                "Password must be at least 8 characters long and include "
                "uppercase, lowercase, number, and special character."
            )

        user = User(
            name=data["name"],
            email=email,
            password_hash=generate_password_hash(password),
            age=data.get("age"),
            sex=data.get("sex"),
        )

        db.session.add(user)
        db.session.commit()

        token = generate_token(user.id)

        return {
            "token": token,
            "user": user_to_dict(user),
        }, 201


# -----------------------------
# LOGIN
# -----------------------------
@auth_ns.route("/login")
class Login(Resource):

    @auth_ns.expect(login_model)
    @auth_ns.marshal_with(auth_response)
    def post(self):
        data = request.get_json()

        if not data:
            auth_ns.abort(400, "Invalid JSON body")

        email = data.get("email", "").strip().lower()
        login_key = f"{_client_ip()}:{email or 'unknown'}"
        locked, retry_after = _login_is_locked(login_key)
        if locked:
            return _rate_limit_response(
                f"Too many failed login attempts. Try again in {retry_after} seconds.",
                retry_after,
            )

        user = User.query.filter_by(email=email).first()

        if not user or not check_password_hash(
            user.password_hash, data["password"]
        ):
            _record_rate_limit_event(
                "login_failure",
                login_key,
                LOGIN_FAILURE_WINDOW_SECONDS,
            )
            auth_ns.abort(401, "Invalid email or password")

        _clear_login_failures(login_key)

        token = generate_token(user.id)

        return {
            "token": token,
            "user": user_to_dict(user),
        }, 200

# ─────────────────────────────────────────────────────────────────────────────
# FORGOT PASSWORD (OTP via email)
# ─────────────────────────────────────────────────────────────────────────────

forgot_password_model = auth_ns.model("ForgotPassword", {
    "email": fields.String(required=True),
})

reset_password_model = auth_ns.model("ResetPassword", {
    "email": fields.String(required=True),
    "otp": fields.String(required=True),
    "new_password": fields.String(required=True),
})

google_login_model = auth_ns.model("GoogleLogin", {
    "google_token": fields.String(required=True),
    "email": fields.String(required=True),
    "name": fields.String(required=True),
})


def _generate_otp(length: int = 6) -> str:
    return "".join(random.choices(string.digits, k=length))


@auth_ns.route("/forgot-password")
class ForgotPassword(Resource):

    @auth_ns.expect(forgot_password_model)
    def post(self):
        """Send a 6-digit OTP to the user's email for password reset."""
        data = request.get_json()
        if not data or not data.get("email"):
            auth_ns.abort(400, "Email is required")

        email = data["email"].strip().lower()
        forgot_key = f"{_client_ip()}:{email}"
        cutoff = _rate_limit_cutoff(FORGOT_PASSWORD_WINDOW_SECONDS)
        attempts = (
            AuthRateLimitEvent.query.filter_by(
                kind="forgot_password_attempt",
                scope_key=forgot_key,
            )
            .filter(AuthRateLimitEvent.created_at >= cutoff)
            .order_by(AuthRateLimitEvent.created_at.asc())
            .all()
        )
        if len(attempts) >= MAX_FORGOT_PASSWORD_ATTEMPTS:
            oldest = attempts[0].created_at or _utcnow()
            retry_after = max(
                1,
                int(
                    FORGOT_PASSWORD_WINDOW_SECONDS
                    - (_utcnow() - oldest).total_seconds()
                ),
            )
            return _rate_limit_response(
                f"Too many OTP requests. Try again in {retry_after} seconds.",
                retry_after,
            )

        _record_rate_limit_event(
            "forgot_password_attempt",
            forgot_key,
            FORGOT_PASSWORD_WINDOW_SECONDS,
        )

        user = User.query.filter_by(email=email).first()

        if not user:
            auth_ns.abort(404, "No account found with this email")

        otp = _generate_otp()
        user.reset_otp = otp
        user.reset_otp_expiry = datetime.now(timezone.utc) + timedelta(minutes=15)
        db.session.commit()

        sent = send_otp_email(email, otp)
        if not sent:
            auth_ns.abort(500, "Failed to send email. Please try again.")

        return {"message": "Verification code sent to your email."}, 200


@auth_ns.route("/reset-password")
class ResetPassword(Resource):

    @auth_ns.expect(reset_password_model)
    def post(self):
        """Verify OTP and reset password."""
        data = request.get_json()
        if not data:
            auth_ns.abort(400, "Invalid request body")

        email = data.get("email", "").strip().lower()
        otp = data.get("otp", "").strip()
        new_password = data.get("new_password", "")

        user = User.query.filter_by(email=email).first()
        if not user:
            auth_ns.abort(404, "No account found with this email")

        # Validate OTP
        if not user.reset_otp or user.reset_otp != otp:
            auth_ns.abort(400, "Invalid verification code")

        if user.reset_otp_expiry and user.reset_otp_expiry.replace(
            tzinfo=timezone.utc
        ) < datetime.now(timezone.utc):
            auth_ns.abort(400, "Verification code has expired")

        # Validate new password strength
        if not PASSWORD_REGEX.match(new_password):
            auth_ns.abort(
                400,
                "Password must be at least 8 characters with uppercase, "
                "lowercase, number, and special character.",
            )

        user.password_hash = generate_password_hash(new_password)
        user.reset_otp = None
        user.reset_otp_expiry = None
        db.session.commit()

        return {"message": "Password reset successfully."}, 200


# ─────────────────────────────────────────────────────────────────────────────
# GOOGLE SIGN-IN
# ─────────────────────────────────────────────────────────────────────────────

GOOGLE_TOKEN_INFO_URL = "https://oauth2.googleapis.com/tokeninfo"


@auth_ns.route("/google-login")
class GoogleLogin(Resource):

    @auth_ns.expect(google_login_model)
    @auth_ns.marshal_with(auth_response, code=200)
    def post(self):
        """Authenticate via Google ID token. Creates account if new user."""
        data = request.get_json()
        if not data:
            auth_ns.abort(400, "Invalid request body")

        google_token = data.get("google_token", "")
        email = data.get("email", "").strip().lower()
        name = data.get("name", "").strip()

        if not google_token or not email:
            auth_ns.abort(400, "google_token and email are required")

        # Verify the Google token
        try:
            resp = http_requests.get(
                GOOGLE_TOKEN_INFO_URL,
                params={"id_token": google_token},
                timeout=10,
            )
            if resp.status_code != 200:
                auth_ns.abort(401, "Invalid Google token")

            token_info = resp.json()
            token_email = token_info.get("email", "").lower()

            if token_email != email:
                auth_ns.abort(401, "Token email mismatch")

        except http_requests.RequestException:
            auth_ns.abort(502, "Could not verify Google token")

        # Find or create user
        user = User.query.filter_by(email=email).first()
        if not user:
            user = User(
                name=name or email.split("@")[0],
                email=email,
                password_hash=generate_password_hash(
                    # Random strong password — user logs in via Google only
                    "".join(random.choices(
                        string.ascii_letters + string.digits + "!@#$%", k=32
                    ))
                ),
            )
            db.session.add(user)
            db.session.commit()

        token = generate_token(user.id)
        return {"token": token, "user": user_to_dict(user)}, 200
