import os
from datetime import datetime
from flask import request
from flask_restx import Namespace, Resource, fields

from auth_utils import get_user_from_auth
from va_model import (
    validate,
    calculate_logmar,
    logmar_to_snellen,
    classify_severity,
)

test_ns = Namespace(
    "tests",
    description="Eye Test Uploads",
    security="BearerAuth"
)

BASE_DIR = os.path.abspath(os.path.dirname(__file__))

# ------------------------------------------------
# EXISTING FILE UPLOAD ENDPOINT (UNCHANGED)
# ------------------------------------------------
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


# ------------------------------------------------
# VISUAL ACUITY TEST ENDPOINT (NEW)
# ------------------------------------------------

va_request = test_ns.model(
    "VisualAcuityRequest",
    {
        "correct": fields.Integer(required=True, description="Correct answers"),
        "total": fields.Integer(required=True, description="Total questions"),
    },
)

va_response = test_ns.model(
    "VisualAcuityResponse",
    {
        "logMAR": fields.Float,
        "snellen": fields.String,
        "severity": fields.String,
    },
)

@test_ns.route("/visual-acuity")
class VisualAcuity(Resource):

    @test_ns.doc(security="BearerAuth")
    @test_ns.expect(va_request)
    @test_ns.marshal_with(va_response)
    def post(self):
        user = get_user_from_auth()
        if not user:
            test_ns.abort(401, "Unauthorized")

        data = request.json
        correct = data.get("correct")
        total = data.get("total")

        try:
            validate(correct, total)

            logmar = calculate_logmar(correct, total)
            snellen = logmar_to_snellen(logmar)
            severity = classify_severity(logmar)

            return {
                "logMAR": logmar,
                "snellen": snellen,
                "severity": severity,
            }

        except Exception as e:
            test_ns.abort(400, str(e))
