"""REST endpoints for chat room bootstrap and history loading."""

from __future__ import annotations

from flask import request
from flask_restx import Namespace, Resource, fields

from db_model import db
from models.consultation import ConsultationMessage

from .auth import ChatAuthError, extract_bearer_from_request, resolve_actor_from_token
from .firebase_auth import create_chat_firebase_custom_token, firebase_uid_for_actor
from .service import (
    ChatServiceError,
    consultation_room_id,
    ensure_consultation_access,
    ensure_user_doctor_pair,
    mark_incoming_as_read,
)

chat_ns = Namespace("chat", description="Realtime chat room bootstrap")

room_request_model = chat_ns.model(
    "ChatRoomRequest",
    {
        "doctor_id": fields.Integer(description="Doctor id for patient room lookup"),
        "patient_id": fields.Integer(description="Patient id for doctor room lookup"),
        "consultation_id": fields.Integer(description="Known consultation id (preferred)"),
    },
)


@chat_ns.route("/rooms")
class ChatRoomResource(Resource):
    """Create or fetch a one-to-one chat room bound to a consultation."""

    @chat_ns.doc(security="Bearer")
    @chat_ns.expect(room_request_model)
    def post(self):
        try:
            actor = resolve_actor_from_token(extract_bearer_from_request())
            data = request.get_json() or {}

            consultation_id = data.get("consultation_id")
            if consultation_id is not None:
                consultation = ensure_consultation_access(actor, int(consultation_id))
            else:
                if actor.role == "patient":
                    doctor_id = int(data.get("doctor_id") or 0)
                    if not doctor_id:
                        return {"message": "doctor_id is required for patient"}, 400
                    consultation = ensure_user_doctor_pair(actor.actor_id, doctor_id)
                else:
                    patient_id = int(data.get("patient_id") or 0)
                    if not patient_id:
                        return {"message": "patient_id is required for doctor"}, 400
                    consultation = ensure_user_doctor_pair(patient_id, actor.actor_id)

            return {
                "room": {
                    "room_id": consultation_room_id(consultation.id),
                    "consultation_id": consultation.id,
                    "doctor_id": consultation.doctor_id,
                    "patient_id": consultation.patient_id,
                    "status": consultation.status,
                }
            }, 200
        except ChatAuthError as exc:
            return {"message": str(exc)}, 401
        except ChatServiceError as exc:
            return {"message": str(exc)}, 403
        except Exception as exc:
            db.session.rollback()
            return {"message": f"Failed to fetch room: {str(exc)}"}, 500


@chat_ns.route("/rooms/<int:consultation_id>/messages")
class ChatHistoryResource(Resource):
    """Load persisted history and mark inbound unread rows as read."""

    @chat_ns.doc(security="Bearer")
    def get(self, consultation_id: int):
        try:
            actor = resolve_actor_from_token(extract_bearer_from_request())
            consultation = ensure_consultation_access(actor, consultation_id)

            page = max(int(request.args.get("page", 1)), 1)
            per_page = min(max(int(request.args.get("per_page", 50)), 1), 100)

            query = consultation.messages.order_by(ConsultationMessage.created_at.asc())
            paged = query.paginate(page=page, per_page=per_page, error_out=False)

            updated_ids = mark_incoming_as_read(actor, consultation)

            return {
                "messages": [msg.to_dict() for msg in paged.items],
                "pagination": {
                    "page": paged.page,
                    "per_page": paged.per_page,
                    "pages": paged.pages,
                    "total": paged.total,
                },
                "updated_read_ids": updated_ids,
            }, 200
        except ChatAuthError as exc:
            return {"message": str(exc)}, 401
        except ChatServiceError as exc:
            return {"message": str(exc)}, 403
        except Exception as exc:
            return {"message": f"Failed to load history: {str(exc)}"}, 500


firebase_token_request_model = chat_ns.model(
    "ChatFirebaseTokenRequest",
    {
        "consultation_id": fields.Integer(required=True, description="Consultation id"),
    },
)


@chat_ns.route("/firebase/token")
class ChatFirebaseTokenResource(Resource):
    """Issue scoped Firebase custom token for chat history access."""

    @chat_ns.doc(security="Bearer")
    @chat_ns.expect(firebase_token_request_model)
    def post(self):
        try:
            actor = resolve_actor_from_token(extract_bearer_from_request())
            if actor.role not in {"doctor", "patient"}:
                return {"message": "Only doctor/patient chat actors are allowed"}, 403

            data = request.get_json() or {}
            consultation_id = int(data.get("consultation_id") or 0)
            if not consultation_id:
                return {"message": "consultation_id is required"}, 400

            consultation = ensure_consultation_access(actor, consultation_id)
            custom_token = create_chat_firebase_custom_token(actor, consultation.id)
            if not custom_token:
                return {
                    "message": "Firebase chat auth is not configured on server"
                }, 503

            return {
                "firebase_custom_token": custom_token,
                "uid": firebase_uid_for_actor(actor),
                "consultation_id": consultation.id,
                "role": actor.role,
            }, 200
        except ChatAuthError as exc:
            return {"message": str(exc)}, 401
        except ChatServiceError as exc:
            return {"message": str(exc)}, 403
        except (TypeError, ValueError):
            return {"message": "consultation_id must be an integer"}, 400
        except Exception as exc:
            return {"message": f"Failed to generate Firebase token: {str(exc)}"}, 500
