"""Repository helpers for medical record persistence."""
from __future__ import annotations

from sqlalchemy import or_

from db_model import db, User
from models.doctor import Doctor
from models.medical_record import MedicalRecord


class MedicalRecordRepository:
    """Encapsulates medical record queries and persistence operations."""

    def create(self, **payload) -> MedicalRecord:
        record = MedicalRecord(**payload)
        db.session.add(record)
        return record

    def get(self, record_id: int) -> MedicalRecord | None:
        return db.session.get(MedicalRecord, record_id)

    def list_for_patient(self, patient_id: int, include_deleted: bool = False) -> list[MedicalRecord]:
        query = MedicalRecord.query.filter(MedicalRecord.patient_id == patient_id)
        if not include_deleted:
            query = query.filter(MedicalRecord.status != 'deleted')
        return query.order_by(MedicalRecord.created_at.desc()).all()

    def list_for_doctor(self, doctor_id: int, include_deleted: bool = False) -> list[MedicalRecord]:
        query = MedicalRecord.query.filter(MedicalRecord.doctor_id == doctor_id)
        if not include_deleted:
            query = query.filter(MedicalRecord.status != 'deleted')
        return query.order_by(MedicalRecord.created_at.desc()).all()

    def list_all(self, include_deleted: bool = False) -> list[MedicalRecord]:
        query = MedicalRecord.query
        if not include_deleted:
            query = query.filter(MedicalRecord.status != 'deleted')
        return query.order_by(MedicalRecord.created_at.desc()).all()

    def list_admin_filtered(
        self,
        *,
        include_deleted: bool = False,
        status: str | None = None,
        record_type: str | None = None,
        doctor_id: int | None = None,
        patient_id: int | None = None,
        search: str | None = None,
        page: int = 1,
        per_page: int = 20,
    ) -> tuple[list[MedicalRecord], int, int]:
        query = MedicalRecord.query.join(Doctor, MedicalRecord.doctor_id == Doctor.id).join(
            User, MedicalRecord.patient_id == User.id
        )

        if not include_deleted and not status:
            query = query.filter(MedicalRecord.status != 'deleted')

        if status:
            query = query.filter(MedicalRecord.status == status)

        if record_type:
            query = query.filter(MedicalRecord.record_type == record_type)

        if doctor_id:
            query = query.filter(MedicalRecord.doctor_id == doctor_id)

        if patient_id:
            query = query.filter(MedicalRecord.patient_id == patient_id)

        if search:
            search_like = f"%{search.strip()}%"
            query = query.filter(
                or_(
                    MedicalRecord.title.ilike(search_like),
                    MedicalRecord.description.ilike(search_like),
                    Doctor.name.ilike(search_like),
                    User.name.ilike(search_like),
                )
            )

        total = query.count()
        if per_page <= 0:
            per_page = 20
        if page <= 0:
            page = 1

        total_pages = (total + per_page - 1) // per_page if total > 0 else 0
        items = (
            query.order_by(MedicalRecord.created_at.desc())
            .offset((page - 1) * per_page)
            .limit(per_page)
            .all()
        )
        return items, total, total_pages

    def commit(self) -> None:
        db.session.commit()

    def rollback(self) -> None:
        db.session.rollback()
