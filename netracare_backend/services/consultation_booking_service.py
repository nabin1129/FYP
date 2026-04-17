"""Consultation booking helper utilities.

These helpers keep validation and normalization logic out of route handlers
so endpoints stay small and easier to maintain.
"""

from __future__ import annotations

from datetime import datetime, timezone

from models.consultation import DoctorSlot


VALID_CONSULTATION_TYPES = {'video_call', 'chat', 'physical'}


def normalize_consultation_type(raw_type: str | None) -> str:
    """Normalize consultation type to supported values."""
    if not raw_type:
        return 'video_call'

    value = str(raw_type).strip().lower()
    if value in {'video', 'video call', 'videocall'}:
        value = 'video_call'
    if value in {'in_person', 'in-person'}:
        value = 'physical'

    return value if value in VALID_CONSULTATION_TYPES else 'video_call'


def parse_iso_datetime_utc(value: str) -> datetime:
    """Parse an ISO datetime and normalize to naive UTC for SQLite consistency."""
    dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if dt.tzinfo is None:
        return dt
    return dt.astimezone(timezone.utc).replace(tzinfo=None)


def is_future_utc(value: datetime) -> bool:
    """Check that datetime is in the future according to UTC."""
    return value > datetime.utcnow()


def get_available_slot_for_booking(slot_id: int, doctor_id: int) -> DoctorSlot | None:
    """Return an active, unbooked slot owned by doctor or None."""
    slot = DoctorSlot.query.filter_by(
        id=slot_id,
        doctor_id=doctor_id,
        is_active=True,
        is_booked=False,
    ).first()

    if not slot:
        return None

    if not is_future_utc(slot.slot_start_at):
        return None

    return slot
