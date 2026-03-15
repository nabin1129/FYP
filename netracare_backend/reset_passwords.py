"""Quick password reset for existing users"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from flask import Flask
from db_model import db, User
from werkzeug.security import generate_password_hash

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(BASE_DIR, 'db.sqlite3')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

NEW_PASSWORD = "password123"

with app.app_context():
    users = User.query.all()
    for u in users:
        u.password_hash = generate_password_hash(NEW_PASSWORD)
        print(f"  Reset: {u.email} -> password: {NEW_PASSWORD}")
    db.session.commit()
    print(f"\nDone! All {len(users)} user(s) can now log in with: {NEW_PASSWORD}")
