# app.py
from datetime import datetime, timedelta
import os
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
import bcrypt
import jwt

# config
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")
JWT_EXP_MINUTES = 60

app = Flask(__name__)
CORS(app)  # allow cross origin during dev
app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///db.sqlite3"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
db = SQLAlchemy(app)

# models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120))
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.LargeBinary, nullable=False)
    age = db.Column(db.Integer, nullable=True)
    sex = db.Column(db.String(20), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

# helpers
def hash_password(plain: str):
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt())

def check_password(plain: str, hashed: bytes):
    return bcrypt.checkpw(plain.encode(), hashed)

def create_token(user_id):
    payload = {
        "sub": user_id,
        "exp": datetime.utcnow() + timedelta(minutes=JWT_EXP_MINUTES)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def decode_token(token):
    return jwt.decode(token, SECRET_KEY, algorithms=["HS256"])

# routes
@app.route("/signup", methods=["POST"])
def signup():
    data = request.get_json() or {}
    name = data.get("name")
    email = data.get("email")
    password = data.get("password")
    age = data.get("age")
    sex = data.get("sex")
    if not email or not password:
        return jsonify({"error":"email and password required"}), 400
    if User.query.filter_by(email=email).first():
        return jsonify({"error":"email already exists"}), 400
    user = User(
        name=name,
        email=email,
        password_hash=hash_password(password),
        age=int(age) if age else None,
        sex=sex
    )
    db.session.add(user)
    db.session.commit()
    token = create_token(user.id)
    return jsonify({"token": token, "user": {"id":user.id, "email":user.email, "name":user.name}}), 201

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json() or {}
    email = data.get("email")
    password = data.get("password")
    if not email or not password:
        return jsonify({"error":"email and password required"}), 400
    user = User.query.filter_by(email=email).first()
    if not user or not check_password(password, user.password_hash):
        return jsonify({"error":"invalid credentials"}), 401
    token = create_token(user.id)
    return jsonify({"token": token, "user": {"id":user.id, "email":user.email, "name":user.name}})

def get_user_from_auth():
    auth = request.headers.get("Authorization","")
    if not auth.startswith("Bearer "):
        return None
    token = auth.split(" ",1)[1]
    try:
        payload = decode_token(token)
        uid = payload.get("sub")
        return User.query.get(uid)
    except Exception:
        return None

@app.route("/profile", methods=["GET"])
def profile():
    user = get_user_from_auth()
    if not user:
        return jsonify({"error":"unauthorized"}), 401
    return jsonify({
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "age": user.age,
        "sex": user.sex
    })

# endpoint for uploading test images (multipart)
@app.route("/upload_test", methods=["POST"])
def upload_test():
    user = get_user_from_auth()
    if not user:
        return jsonify({"error":"unauthorized"}), 401
    if "file" not in request.files:
        return jsonify({"error":"file missing"}), 400
    f = request.files["file"]
    # For dev store it locally; in production use cloud storage
    save_dir = os.path.join(os.path.dirname(__file__), "uploads")
    os.makedirs(save_dir, exist_ok=True)
    path = os.path.join(save_dir, f"{user.id}_{int(datetime.utcnow().timestamp())}_{f.filename}")
    f.save(path)
    # Here you could queue a job to process image with AI
    return jsonify({"status":"ok", "path": path})

if __name__ == "__main__":
    # create DB
    with app.app_context():
        db.create_all()
    app.run(host="0.0.0.0", port=5000, debug=True)
