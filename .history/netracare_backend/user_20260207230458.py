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
    "phone": fields.String,
    "address": fields.String,
    "emergency_contact": fields.String,
    "medical_history": fields.String,
    "profile_image_url": fields.String,
})

profile_update = user_ns.model("ProfileUpdate", {
    "name": fields.String,
    "email": fields.String,
    "age": fields.Integer,
    "sex": fields.String,
    "phone": fields.String,
    "address": fields.String,
    "emergency_contact": fields.String,
    "medical_history": fields.String,
    "profile_image_url": fields.String,
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
            "phone": user.phone,
            "address": user.address,
            "emergency_contact": user.emergency_contact,
            "medical_history": user.medical_history,
            "profile_image_url": user.profile_image_url,
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
        # Update new fields
        if "phone" in data:
            user.phone = data["phone"]

        if "address" in data:
            user.address = data["address"]

        if "emergency_contact" in data:
            user.emergency_contact = data["emergency_contact"]

        if "medical_history" in data:
            user.medical_history = data["medical_history"]

        if "profile_image_url" in data:
            user.profile_image_url = data["profile_image_url"]

        db.session.commit()

        return {
            "message": "Profile updated successfully",
            "user": {
                "id": user.id,
                "name": user.name,
                "email": user.email,
                "age": user.age,
                "sex": user.sex,
                "phone": user.phone,
                "address": user.address,
                "emergency_contact": user.emergency_contact,
                "medical_history": user.medical_history,
                "profile_image_url": user.profile_image_url,
            }
        }, 200


@user_ns.route("/profile/image")
class ProfileImageUploadAPI(Resource):

    @user_ns.doc(security="BearerAuth")
    @token_required
    def post(self, user):
        """
        Upload profile image
        """
        if 'profile_image' not in request.files:
            return {"error": "No image file provided"}, 400

        file = request.files['profile_image']

        if file.filename == '':
            return {"error": "No file selected"}, 400

        if file:
            import os
            from werkzeug.utils import secure_filename
            import uuid

            # Generate unique filename
            ext = os.path.splitext(file.filename)[1]
            filename = f"{user.id}_{uuid.uuid4().hex}{ext}"

            # Create uploads directory if it doesn't exist
            upload_folder = os.path.join(os.getcwd(), 'uploads', 'profile_images')
            os.makedirs(upload_folder, exist_ok=True)

            # Save file
            filepath = os.path.join(upload_folder, filename)
            file.save(filepath)

            # Generate URL (adjust based on your deployment)
            image_url = f"/uploads/profile_images/{filename}"

            # Update user profile
            user.profile_image_url = image_url
            db.session.commit()

            return {
                "message": "Image uploaded successfully",
                "image_url": image_url
            }, 200

