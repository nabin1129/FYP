# test.py
import os
from datetime import datetime
from flask import request
from flask_restx import Namespace, Resource

from auth_utils import get_user_from_auth

test_ns = Namespace(
    "tests",
    description="Eye Test Uploads",
    security="BearerAuth"
)

BASE_DIR = os.path.abspath(os.path.dirname(__file__))

@test_ns.route("/upload")
class Upload(Resource):

    @test_ns.doc(security="BearerAuth")
    def post(self):
        user = get_user_from_auth()
        if not user:
            test_ns.abort(401, "Unauthorized")

        if "file" not in request.files:
            test_ns.abort(400, "File missing")

        file = request.files["file"]

        upload_dir = os.path.join(BASE_DIR, "uploads")
        os.makedirs(upload_dir, exist_ok=True)

        filename = f"user{user.id}_{int(datetime.utcnow().timestamp())}_{file.filename}"
        path = os.path.join(upload_dir, filename)

        file.save(path)

        return {
            "status": "ok",
            "filename": filename
        }, 201
