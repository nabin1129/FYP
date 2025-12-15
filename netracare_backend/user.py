# user.py
from flask_restx import Namespace, Resource, fields
from auth_utils import token_required

user_ns = Namespace(
    "user",
    description="User Profile",
    security="BearerAuth"
)

# Swagger response model
user_response = user_ns.model("UserProfile", {
    "id": fields.Integer,
    "name": fields.String,
    "email": fields.String,
    "age": fields.Integer,
    "sex": fields.String,
})

@user_ns.route("/profile")
class Profile(Resource):

    @user_ns.doc(security="BearerAuth")
    @user_ns.marshal_with(user_response)
    @token_required
    def get(self, user):
        # `user` is injected by token_required decorator
        return {
            "id": user.id,
            "name": user.name,
            "email": user.email,
            "age": user.age,
            "sex": user.sex,
        }
