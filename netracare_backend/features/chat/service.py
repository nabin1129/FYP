"""Core chat business rules shared by REST and SocketIO handlers."""

from __future__ import annotations

from datetime import datetime

from db_model import db
from models.consultation import Consultation, ConsultationMessage
from models.notification import Notification

from .auth import ChatActor
from .firebase_history_store import mirror_message, mirror_messages_read

VALID_MESSAGE_TYPES = {
    "text",
    "image",
    "file",
    "test_result",
    "attachment",
    "medical_record",
    "clinical_note",
}
ACTIVE_CHAT_STATUSES = {"pending", "scheduled", "in_progress"}


class ChatServiceError(Exception):
    """Domain-level chat error with HTTP/socket-safe message."""



def consultation_room_id(consultation_id: int) -> str:
    return f"consultation_{consultation_id}"



def ensure_consultation_access(actor: ChatActor, consultation_id: int) -> Consultation:
    consultation = db.session.get(Consultation, consultation_id)
    if not consultation:
        raise ChatServiceError("Consultation not found")

    if actor.role == "doctor" and consultation.doctor_id != actor.actor_id:
        raise ChatServiceError("Not authorized for this consultation")
    if actor.role == "patient" and consultation.patient_id != actor.actor_id:
        raise ChatServiceError("Not authorized for this consultation")

    return consultation



def ensure_user_doctor_pair(patient_id: int, doctor_id: int) -> Consultation:
    consultation = (
        Consultation.query.filter_by(patient_id=patient_id, doctor_id=doctor_id)
        .order_by(Consultation.created_at.desc())
        .first()
    )

    if consultation:
        return consultation

    consultation = Consultation(
        patient_id=patient_id,
        doctor_id=doctor_id,
        consultation_type="chat",
        status="pending",
        reason="Chat initiated",
    )
    db.session.add(consultation)
    db.session.commit()
    return consultation



def get_consultation_messages(consultation: Consultation) -> list[ConsultationMessage]:
    return consultation.messages.order_by(ConsultationMessage.created_at.asc()).all()



def mark_incoming_as_read(actor: ChatActor, consultation: Consultation) -> list[str]:
    now = datetime.utcnow()
    updated_ids: list[str] = []
    updated_messages: list[ConsultationMessage] = []

    expected_sender = "patient" if actor.role == "doctor" else "doctor"

    for msg in get_consultation_messages(consultation):
        if msg.sender_type == expected_sender and not msg.is_read:
            msg.is_read = True
            msg.read_at = now
            updated_ids.append(str(msg.id))
            updated_messages.append(msg)

    if updated_ids:
        db.session.commit()
        mirror_messages_read(consultation, updated_messages, read_at=now)

    return updated_ids



def create_message(
    actor: ChatActor,
    consultation: Consultation,
    content: str,
    message_type: str = "text",
    attachments: list[dict] | None = None,
) -> ConsultationMessage:
    cleaned_content = (content or "").strip()
    if not cleaned_content and not attachments:
        raise ChatServiceError("Message content is required")

    if message_type not in VALID_MESSAGE_TYPES:
        raise ChatServiceError("Invalid message type")

    if consultation.status not in ACTIVE_CHAT_STATUSES:
        raise ChatServiceError("Consultation is not available for chat")

    # We currently persist one attachment per message in existing columns.
    first_attachment = (attachments or [None])[0]
    if first_attachment is not None and not isinstance(first_attachment, dict):
        first_attachment = None
    normalized_type = "file" if message_type == "attachment" else message_type
    if first_attachment is not None:
        normalized_type = (first_attachment.get("type") or normalized_type or "file").lower()
        if normalized_type == "attachment":
            normalized_type = "file"

    persisted_content = cleaned_content
    if not persisted_content and first_attachment is not None:
        persisted_content = "Shared attachment"

    file_url = None
    file_name = None
    test_type = None
    test_id = None
    if first_attachment is not None:
        file_url = first_attachment.get("url")
        file_name = first_attachment.get("file_name") or first_attachment.get("fileName")
        test_type = first_attachment.get("linked_entity_title") or first_attachment.get("linkedEntityTitle")
        linked_id = first_attachment.get("linked_entity_id") or first_attachment.get("linkedEntityId")
        if linked_id is not None:
            try:
                test_id = int(linked_id)
            except (TypeError, ValueError):
                test_id = None

    sender_type = "doctor" if actor.role == "doctor" else "patient"
    message = ConsultationMessage(
        consultation_id=consultation.id,
        sender_type=sender_type,
        sender_id=actor.actor_id,
        message_type=normalized_type,
        content=persisted_content,
        file_url=file_url,
        file_name=file_name,
        test_type=test_type,
        test_id=test_id,
    )

    db.session.add(message)

    if actor.role == "doctor":
        notification = Notification.create_message_notification(
            recipient_type="user",
            recipient_id=consultation.patient_id,
            sender_name=actor.doctor.name if actor.doctor else "Doctor",
            consultation_id=consultation.id,
        )
    else:
        notification = Notification.create_message_notification(
            recipient_type="doctor",
            recipient_id=consultation.doctor_id,
            sender_name=actor.user.name if actor.user and actor.user.name else "Patient",
            consultation_id=consultation.id,
        )

    db.session.add(notification)
    db.session.commit()

    mirror_message(consultation, message)

    return message



def mark_messages_read(
    actor: ChatActor,
    consultation: Consultation,
    message_ids: list[str] | None = None,
) -> list[str]:
    now = datetime.utcnow()
    target_sender = "patient" if actor.role == "doctor" else "doctor"

    query = consultation.messages.filter(
        ConsultationMessage.sender_type == target_sender,
        ConsultationMessage.is_read.is_(False),
    )

    if message_ids:
        query = query.filter(ConsultationMessage.id.in_([int(mid) for mid in message_ids]))

    rows = query.all()
    for msg in rows:
        msg.is_read = True
        msg.read_at = now

    if rows:
        db.session.commit()
        mirror_messages_read(consultation, rows, read_at=now)

    return [str(row.id) for row in rows]
