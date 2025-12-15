# auth.py
from flask import request
from flask_restx import Namespace, Resource, fields
import bcrypt, jwt
from datetime import datetime, timedelta
from db_model import db, User
from config import SECRET_KEY, JWT_EXP_MINUTES

auth_ns = Namespace("auth", description="Login & Signup")

signup_model = auth_ns.model("Signup", {
    "name": fields.String,
    "email": fields.String(required=True),
    "password": fields.String(required=True),
    "age": fields.Integer,
    "sex": fields.String,
})

login_model = auth_ns.model("Login", {
    "email": fields.String(required=True),
    "password": fields.String(required=True),
})

def hash_password(p):
    return bcrypt.hashpw(p.encode(), bcrypt.gensalt())

def check_password(p, h):
    return bcrypt.checkpw(p.encode(), h)

def create_token(uid):
    return jwt.encode(
        {"sub": uid, "exp": datetime.utcnow() + timedelta(minutes=JWT_EXP_MINUTES)},
        SECRET_KEY,
        algorithm="HS256",
    )

@auth_ns.route("/signup")
class Signup(Resource):
    @auth_ns.expect(signup_model)
    def post(self):
        data = request.json or {}

        if User.query.filter_by(email=data["email"]).first():
            auth_ns.abort(400, "Email already exists")

        user = User(
            name=data.get("name"),
            email=data["email"],
            password_hash=hash_password(data["password"]),
            age=data.get("age"),
            sex=data.get("sex"),
        )

        db.session.add(user)
        db.session.commit()

        return {
            "token": create_token(user.id),
            "user": {"id": user.id, "name": user.name, "email": user.email},
        }, 201


@auth_ns.route("/login")
class Login(Resource):
    @auth_ns.expect(login_model)
    def post(self):
        data = request.json or {}
        user = User.query.filter_by(email=data["email"]).first()

        if not user or not check_password(data["password"], user.password_hash):
            auth_ns.abort(401, "Invalid credentials")

        return {
            "token": create_token(user.id),
            "user": {"id": user.id, "name": user.name, "email": user.email},
        }
