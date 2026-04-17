"""API namespace registration for Flask-RestX."""

from __future__ import annotations

from flask_restx import Api


# Import feature namespaces
from features.auth.routes import auth_ns
from features.user.routes import user_ns
from features.eye_tracking.camera_routes import camera_eye_tracking_ns
from features.visual_acuity.routes import visual_acuity_ns
from features.eye_tracking.routes import eye_tracking_ns
from features.colour_vision.routes import colour_vision_ns
from features.blink.fatigue_routes import blink_fatigue_ns
from features.blink.detection_routes import blink_detection_ns

# Import modular namespaces
from routes.auth_routes import auth_ns as auth_v2_ns
from routes.pupil_reflex_routes import pupil_reflex_ns as pupil_reflex_v2_ns
from routes.ai_report_routes import ai_report_ns
from routes.doctor_routes import doctor_ns
from routes.consultation_routes import consultation_ns
from routes.notification_routes import notification_ns
from routes.admin_routes import admin_ns
from features.chat.rest_routes import chat_ns

# Import models to ensure tables are discovered
from models.doctor import Doctor, DoctorPatient
from models.consultation import Consultation, ConsultationMessage, DoctorSlot
from models.notification import Notification


def build_api(app) -> Api:
    """Create and register the API object with all namespaces."""
    api = Api(
        app,
        title="NetraCare API",
        version="1.0",
        description="Backend APIs",
        doc="/docs",
    )

    # Legacy namespaces
    api.add_namespace(auth_ns)
    api.add_namespace(user_ns)
    api.add_namespace(camera_eye_tracking_ns)
    api.add_namespace(visual_acuity_ns)
    api.add_namespace(eye_tracking_ns)
    api.add_namespace(colour_vision_ns)
    api.add_namespace(blink_fatigue_ns)
    api.add_namespace(blink_detection_ns)

    # Modular/professional namespaces
    api.add_namespace(auth_v2_ns, path="/api/auth")
    api.add_namespace(pupil_reflex_v2_ns, path="/api/pupil-reflex")
    api.add_namespace(ai_report_ns, path="/api/ai-report")
    api.add_namespace(doctor_ns, path="/api/doctors")
    api.add_namespace(consultation_ns, path="/api/consultations")
    api.add_namespace(notification_ns, path="/api/notifications")
    api.add_namespace(admin_ns, path="/api/admin")
    api.add_namespace(chat_ns, path="/api/chat")

    return api
