"""Business logic for medical record workflows."""
from __future__ import annotations

from models.medical_record import MedicalRecord
from repositories.medical_record_repository import MedicalRecordRepository


class MedicalRecordService:
    """Handles validation and access rules for medical records."""

    def __init__(self, repository: MedicalRecordRepository | None = None):
        self.repository = repository or MedicalRecordRepository()

    def create_record(self, *, doctor_id: int, patient_id: int, created_by_id: int, data: dict) -> MedicalRecord:
        record_type = (data.get('record_type') or data.get('type') or '').strip()
        title = (data.get('title') or '').strip()
        description = (data.get('description') or '').strip()

        if not record_type:
            raise ValueError('record_type is required')
        if not title:
            raise ValueError('title is required')
        if not description:
            raise ValueError('description is required')

        record = self.repository.create(
            doctor_id=doctor_id,
            patient_id=patient_id,
            created_by_id=created_by_id,
            updated_by_id=created_by_id,
            record_type=record_type,
            title=title,
            description=description,
            category=(data.get('category') or 'general').strip(),
            file_url=(data.get('file_url') or '').strip() or None,
            file_name=(data.get('file_name') or '').strip() or None,
            file_size=data.get('file_size'),
            mime_type=(data.get('mime_type') or '').strip() or None,
            status=(data.get('status') or 'active').strip(),
        )
        self.repository.commit()
        return record

    def update_record(self, record: MedicalRecord, *, updated_by_id: int, data: dict) -> MedicalRecord:
        for field in ('record_type', 'title', 'description', 'category', 'file_url', 'file_name', 'mime_type', 'status'):
            if field in data and data[field] is not None:
                value = data[field]
                if isinstance(value, str):
                    value = value.strip()
                setattr(record, field, value or None)

        if 'file_size' in data:
            record.file_size = data['file_size']
        record.updated_by_id = updated_by_id
        self.repository.commit()
        return record

    def soft_delete_record(self, record: MedicalRecord, *, deleted_by_id: int) -> MedicalRecord:
        record.status = 'deleted'
        record.deleted_by_id = deleted_by_id
        from datetime import datetime
        record.deleted_at = datetime.utcnow()
        self.repository.commit()
        return record

    def restore_record(self, record: MedicalRecord, *, restored_by_id: int) -> MedicalRecord:
        record.status = 'active'
        record.deleted_by_id = None
        record.deleted_at = None
        record.updated_by_id = restored_by_id
        self.repository.commit()
        return record
