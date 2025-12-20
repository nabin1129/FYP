# auth.py
from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import jwt

from db_model import db, User
from config import SECRET_KEY, JWT_EXP_MINUTES

auth_ns = Namespace("auth", description="Authentication APIs")

signup_model = auth_ns.model("Signup", {
    "name": fields.String(required=True),
    "email": fields.String(required=True),
    "password": fields.String(required=True),
    "age": fields.Integer,
    "sex": fields.String,
})

login_model = auth_ns.model("Login", {
    "email": fields.String(required=True),
    "password": fields.String(required=True),
})


def generate_token(user_id: int) -> str:
    payload = {
        "sub": str(user_id),  # ✅ MUST be string
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + timedelta(minutes=JWT_EXP_MINUTES),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def user_to_dict(user: User):
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "age": user.age,
        "sex": user.sex,
    }


@auth_ns.route("/signup")
class Signup(Resource):
    @auth_ns.expect(signup_model)
    def post(self):
        data = request.get_json()

        if not data:
            return {"error": "Invalid JSON body"}, 400

        if User.query.filter_by(email=data["email"]).first():
            return {"error": "Email already registered"}, 400

        user = User(
            name=data["name"],
            email=data["email"],
            password_hash=generate_password_hash(data["password"]),
            age=data.get("age"),
            sex=data.get("sex"),
        )

        db.session.add(user)
        db.session.commit()

        token = generate_token(user.id)

        return {"token": token, "user": user_to_dict(user)}, 201


@auth_ns.route("/login")
class Login(Resource):
    @auth_ns.expect(login_model)
    def post(self):
        data = request.get_json()

        if not data:
            return {"error": "Invalid JSON body"}, 400

        user = User.query.filter_by(email=data["email"]).first()

        if not user or not check_password_hash(user.password_hash, data["password"]):
            return {"error": "Invalid email or password"}, 401

        token = generate_token(user.id)

        return {"token": token, "user": user_to_dict(user)}, 200
