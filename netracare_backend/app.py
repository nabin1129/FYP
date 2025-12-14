# app.py
from datetime import datetime, timedelta
import os

from flask import Flask, request
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_restx import Api, Resource, fields
import bcrypt
import jwt

# -----------------------------------------------------------------------------
# CONFIG
# -----------------------------------------------------------------------------
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")
JWT_EXP_MINUTES = 60

app = Flask(__name__)
CORS(app)

# -----------------------------------------------------------------------------
# SQLITE DATABASE (FULLY WORKING)
# -----------------------------------------------------------------------------
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
DB_PATH = os.path.join(BASE_DIR, "db.sqlite3")

app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{DB_PATH}"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# -----------------------------------------------------------------------------
# SWAGGER SETUP
# -----------------------------------------------------------------------------
authorizations = {
    "BearerAuth": {
        "type": "apiKey",
        "in": "header",
        "name": "Authorization",
        "description": "JWT format: Bearer <token>",
    }
}

api = Api(
    app,
    title="NetraCare API",
    version="1.0",
    description="Authentication, Profile & Eye Test Upload APIs",
    doc="/docs",
    authorizations=authorizations,
    security="BearerAuth",
)

auth_ns = api.namespace("auth", description="Login & Signup")
user_ns = api.namespace("user", description="Profile")
test_ns = api.namespace("tests", description="Eye Test Upload")

# -----------------------------------------------------------------------------
# DATABASE MODELS
# -----------------------------------------------------------------------------
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120))
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.LargeBinary, nullable=False)
    age = db.Column(db.Integer)
    sex = db.Column(db.String(20))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# -----------------------------------------------------------------------------
# HELPERS
# -----------------------------------------------------------------------------
def hash_password(plain):
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt())

def check_password(plain, hashed):
    return bcrypt.checkpw(plain.encode(), hashed)

def create_token(user_id):
    return jwt.encode(
        {"sub": user_id, "exp": datetime.utcnow() + timedelta(minutes=JWT_EXP_MINUTES)},
        SECRET_KEY,
        algorithm="HS256"
    )

def decode_token(token):
    return jwt.decode(token, SECRET_KEY, algorithms=["HS256"])

def get_user_from_auth():
    auth = request.headers.get("Authorization", "")

    if not auth.startswith("Bearer "):
        return None

    token = auth.split(" ", 1)[1]

    try:
        payload = decode_token(token)
        return User.query.get(payload.get("sub"))
    except:
        return None

# -----------------------------------------------------------------------------
# SWAGGER MODELS
# -----------------------------------------------------------------------------
signup_model = api.model("Signup", {
    "name": fields.String,
    "email": fields.String(required=True),
    "password": fields.String(required=True),
    "age": fields.Integer,
    "sex": fields.String,
})

login_model = api.model("Login", {
    "email": fields.String(required=True),
    "password": fields.String(required=True),
})

user_response = api.model("User", {
    "id": fields.Integer,
    "name": fields.String,
    "email": fields.String,
    "age": fields.Integer,
    "sex": fields.String,
})

token_response = api.model("TokenResponse", {
    "token": fields.String,
    "user": fields.Nested(user_response),
})

# -----------------------------------------------------------------------------
# AUTH ROUTES
# -----------------------------------------------------------------------------
@auth_ns.route("/signup")
class Signup(Resource):
    @auth_ns.expect(signup_model)
    @auth_ns.marshal_with(token_response, code=201)
    def post(self):
        data = request.json or {}
        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            api.abort(400, "Email and password required")

        if User.query.filter_by(email=email).first():
            api.abort(400, "Email already exists")

        user = User(
            name=data.get("name"),
            email=email,
            password_hash=hash_password(password),
            age=data.get("age"),
            sex=data.get("sex")
        )

        db.session.add(user)    
        db.session.commit()

        token = create_token(user.id)

        return {"token": token, "user": user}, 201


@auth_ns.route("/login")
class Login(Resource):
    @auth_ns.expect(login_model)
    @auth_ns.marshal_with(token_response)
    def post(self):
        data = request.json or {}
        email = data.get("email")
        password = data.get("password")

        user = User.query.filter_by(email=email).first()

        if not user or not check_password(password, user.password_hash):
            api.abort(401, "Invalid credentials")

        token = create_token(user.id)

        return {"token": token, "user": user}

# -----------------------------------------------------------------------------
# PROFILE
# -----------------------------------------------------------------------------
@user_ns.route("/profile")
class Profile(Resource):
    @user_ns.marshal_with(user_response)
    def get(self):
        user = get_user_from_auth()
        if not user:
            api.abort(401, "Unauthorized")

        return user

# -----------------------------------------------------------------------------
# FILE UPLOAD (Associated with DB user)
# -----------------------------------------------------------------------------
@test_ns.route("/upload")
class Upload(Resource):
    @test_ns.doc(security="BearerAuth")
    def post(self):
        user = get_user_from_auth()
        if not user:
            api.abort(401, "Unauthorized")

        if "file" not in request.files:
            api.abort(400, "File missing")

        file = request.files["file"]

        upload_path = os.path.join(BASE_DIR, "uploads")
        os.makedirs(upload_path, exist_ok=True)

        filename = f"user{user.id}_{int(datetime.utcnow().timestamp())}_{file.filename}"
        full_path = os.path.join(upload_path, filename)

        file.save(full_path)

        return {"status": "ok", "file_path": full_path}

# -----------------------------------------------------------------------------
# RUN APP
# -----------------------------------------------------------------------------
if __name__ == "__main__":
    with app.app_context():
        db.create_all()   # ensures database is always created

    app.run(host="0.0.0.0", port=5000, debug=True)
