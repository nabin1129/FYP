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

from db_model import db, User
from config import SECRET_KEY, JWT_EXP_MINUTES
from email_utils import send_otp_email

auth_ns = Namespace(
    "auth",
    description="Authentication APIs"
)

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
    exp_time = now + timedelta(minutes=JWT_EXP_MINUTES)
    payload = {
        "sub": str(user_id),  # JWT standard requires sub to be a string
        "iat": int(now.timestamp()),
        "exp": int(exp_time.timestamp()),
    }
    token = jwt.encode(payload, SECRET_KEY, algorithm="HS256")
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

        # Check email duplication
        if User.query.filter_by(email=data["email"]).first():
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
            email=data["email"],
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

        user = User.query.filter_by(email=data["email"]).first()

        if not user or not check_password_hash(
            user.password_hash, data["password"]
        ):
            auth_ns.abort(401, "Invalid email or password")

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