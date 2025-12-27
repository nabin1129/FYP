# auth.py
from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import jwt
import re

from db_model import db, User
from config import SECRET_KEY, JWT_EXP_MINUTES

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
    payload = {
        "sub": user_id,
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + timedelta(minutes=JWT_EXP_MINUTES),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


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
