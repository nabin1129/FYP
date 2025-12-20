# user.py
from flask_restx import Namespace, Resource, fields
from flask import request

from auth_utils import token_required
from db_model import db, User

user_ns = Namespace(
    "user",
    description="User Profile APIs",
    security="BearerAuth"
)

# -----------------------------
# Swagger Models
# -----------------------------
profile_response = user_ns.model("ProfileResponse", {
    "id": fields.Integer,
    "name": fields.String,
    "email": fields.String,
    "age": fields.Integer,
    "sex": fields.String,
})

profile_update = user_ns.model("ProfileUpdate", {
    "name": fields.String,
    "email": fields.String,
    "age": fields.Integer,
    "sex": fields.String,
})

# -----------------------------
# PROFILE APIs
# -----------------------------
@user_ns.route("/profile")
class ProfileAPI(Resource):

    @user_ns.doc(security="BearerAuth")
    @user_ns.marshal_with(profile_response)
    @token_required
    def get(self, user):
        """
        Fetch logged-in user's profile
        """
        return {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "age": user.age,
            "sex": user.sex,
        }

    @user_ns.doc(security="BearerAuth")
    @user_ns.expect(profile_update)
    @token_required
    def put(self, user):
        """
        Update logged-in user's profile
        """
        data = request.get_json() or {}

        # Update name
        if "name" in data:
            user.name = data["name"]

        # Update email (ensure uniqueness)
        if "email" in data:
            existing = User.query.filter(
                User.email == data["email"],
                User.id != user.id
            ).first()
            if existing:
                return {"error": "Email already in use"}, 400
            user.email = data["email"]

        # Update age & sex
        if "age" in data:
            user.age = data["age"]

        if "sex" in data:
            user.sex = data["sex"]

        db.session.commit()

        return {
            "message": "Profile updated successfully",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "age": user.age,
                "sex": user.sex,
            }
        }, 200
