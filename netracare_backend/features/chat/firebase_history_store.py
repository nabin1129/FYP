"""Firestore mirror writes for consultation chat history."""

from __future__ import annotations

import logging
from datetime import datetime

from models.consultation import Consultation, ConsultationMessage

from .firebase_client import get_firestore_client


LOGGER = logging.getLogger(__name__)


def _participant_uids(consultation: Consultation) -> list[str]:
    return [f"doctor:{consultation.doctor_id}", f"patient:{consultation.patient_id}"]


def _consultation_doc_payload(consultation: Consultation) -> dict:
    return {
        "consultation_id": consultation.id,
        "doctor_id": consultation.doctor_id,
        "patient_id": consultation.patient_id,
        "participant_uids": _participant_uids(consultation),
        "status": consultation.status,
        "updated_at": datetime.utcnow().isoformat(),
    }


def _message_doc_payload(consultation: Consultation, message: ConsultationMessage) -> dict:
    as_dict = message.to_dict()
    return {
        "id": str(message.id),
        "consultation_id": consultation.id,
        "doctor_id": consultation.doctor_id,
        "patient_id": consultation.patient_id,
        "participant_uids": _participant_uids(consultation),
        "sender_type": message.sender_type,
        "sender_id": message.sender_id,
        "message_type": message.message_type,
        "content": message.content,
        "file_url": message.file_url,
        "file_name": message.file_name,
        "attachments": as_dict.get("attachments") or [],
        "test_type": message.test_type,
        "test_id": message.test_id,
        "is_read": bool(message.is_read),
        "read_at": message.read_at.isoformat() if message.read_at else None,
        "created_at": message.created_at.isoformat() if message.created_at else None,
        "updated_at": datetime.utcnow().isoformat(),
    }


def mirror_message(consultation: Consultation, message: ConsultationMessage) -> None:
    """Mirror one chat message into Firestore.

    This should never break primary SQL chat flow.
    """
    client = get_firestore_client()
    if client is None:
        return

    try:
        consultation_ref = client.collection("consultations").document(str(consultation.id))
        consultation_ref.set(_consultation_doc_payload(consultation), merge=True)

        message_ref = consultation_ref.collection("messages").document(str(message.id))
        message_ref.set(_message_doc_payload(consultation, message), merge=True)
    except Exception:
        LOGGER.exception(
            "Failed to mirror chat message to Firestore",
            extra={"consultation_id": consultation.id, "message_id": str(message.id)},
        )


def mirror_messages_read(
    consultation: Consultation,
    messages: list[ConsultationMessage],
    read_at: datetime | None = None,
) -> None:
    """Mirror read status updates for a message set."""
    if not messages:
        return

    client = get_firestore_client()
    if client is None:
        return

    try:
        consultation_ref = client.collection("consultations").document(str(consultation.id))
        consultation_ref.set(_consultation_doc_payload(consultation), merge=True)

        timestamp = (read_at or datetime.utcnow()).isoformat()
        batch = client.batch()
        for message in messages:
            msg_ref = consultation_ref.collection("messages").document(str(message.id))
            batch.set(
                msg_ref,
                {
                    "is_read": True,
                    "read_at": message.read_at.isoformat() if message.read_at else timestamp,
                    "updated_at": timestamp,
                    "participant_uids": _participant_uids(consultation),
                },
                merge=True,
            )
        batch.commit()
    except Exception:
        LOGGER.exception(
            "Failed to mirror read receipts to Firestore",
            extra={
                "consultation_id": consultation.id,
                "message_ids": [str(msg.id) for msg in messages],
            },
        )
