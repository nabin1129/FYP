"""Medical Record routes for doctors, patients, and admins."""
from __future__ import annotations

import os
import uuid
from pathlib import Path

from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.utils import secure_filename

from core.security import token_required, admin_token_required
from models.doctor import Doctor
from models.consultation import Consultation
from models.medical_record import MedicalRecord
from repositories.medical_record_repository import MedicalRecordRepository
from services.medical_record_service import MedicalRecordService
from routes.doctor_routes import doctor_token_required
from db_model import db, User

_UPLOAD_ROOT = Path(__file__).resolve().parents[1] / 'uploads' / 'medical_records'
_ALLOWED_EXTENSIONS = {'pdf', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff', 'webp', 'doc', 'docx'}
_MAX_FILE_BYTES = 10 * 1024 * 1024  # 10 MB


def _save_uploaded_file(file_storage) -> dict:
    """Validate and persist an uploaded file.  Returns metadata dict."""
    original = file_storage.filename or ''
    ext = original.rsplit('.', 1)[-1].lower() if '.' in original else ''
    if ext not in _ALLOWED_EXTENSIONS:
        raise ValueError(f'File type .{ext} is not allowed')
    data = file_storage.read()
    if len(data) > _MAX_FILE_BYTES:
        raise ValueError('File exceeds the 10 MB size limit')
    _UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)
    unique_name = f'{uuid.uuid4().hex}.{ext}'
    save_path = _UPLOAD_ROOT / unique_name
    save_path.write_bytes(data)
    return {
        'file_url': f'/uploads/medical_records/{unique_name}',
        'file_name': secure_filename(original) or unique_name,
        'file_size': len(data),
        'mime_type': file_storage.content_type or 'application/octet-stream',
    }

medical_records_ns = Namespace('medical-records', description='Medical record management')

medical_record_model = medical_records_ns.model('MedicalRecord', {
    'doctor_id': fields.Integer,
    'patient_id': fields.Integer(required=True),
    'record_type': fields.String(required=True),
    'title': fields.String(required=True),
    'description': fields.String(required=True),
    'category': fields.String(description='general, follow_up, diagnosis, treatment, referral'),
    'file_url': fields.String,
    'file_name': fields.String,
    'file_size': fields.Integer,
    'mime_type': fields.String,
    'status': fields.String(description='draft, active, archived, deleted'),
})


def _service() -> MedicalRecordService:
    return MedicalRecordService(MedicalRecordRepository())


@medical_records_ns.route('/doctor')
class DoctorMedicalRecordList(Resource):
    @medical_records_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        records = MedicalRecord.query.filter(
            MedicalRecord.doctor_id == current_doctor.id,
            MedicalRecord.status != 'deleted',
        ).order_by(MedicalRecord.created_at.desc()).all()
        return {'records': [record.to_dict() for record in records], 'total': len(records)}, 200

    @medical_records_ns.expect(medical_record_model)
    @medical_records_ns.doc(security='Bearer')
    @doctor_token_required
    def post(self, current_doctor):
        data = request.get_json() or {}
        patient_id = data.get('patient_id')
        if not patient_id:
            return {'message': 'patient_id is required'}, 400
        if not db.session.get(User, patient_id):
            return {'message': 'Patient not found'}, 404
        try:
            record = _service().create_record(
                doctor_id=current_doctor.id,
                patient_id=patient_id,
                created_by_id=current_doctor.id,
                data=data,
            )
            return {'message': 'Medical record created successfully', 'record': record.to_dict()}, 201
        except ValueError as exc:
            return {'message': str(exc)}, 400
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to create medical record: {str(exc)}'}, 500


@medical_records_ns.route('/doctor/<int:record_id>')
class DoctorMedicalRecordDetail(Resource):
    @medical_records_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor, record_id):
        record = db.session.get(MedicalRecord, record_id)
        if not record or record.doctor_id != current_doctor.id:
            return {'message': 'Medical record not found'}, 404
        return {'record': record.to_dict()}, 200

    @medical_records_ns.expect(medical_record_model)
    @medical_records_ns.doc(security='Bearer')
    @doctor_token_required
    def put(self, current_doctor, record_id):
        record = db.session.get(MedicalRecord, record_id)
        if not record or record.doctor_id != current_doctor.id:
            return {'message': 'Medical record not found'}, 404
        try:
            updated = _service().update_record(record, updated_by_id=current_doctor.id, data=request.get_json() or {})
            return {'message': 'Medical record updated successfully', 'record': updated.to_dict()}, 200
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to update medical record: {str(exc)}'}, 500

    @medical_records_ns.doc(security='Bearer')
    @doctor_token_required
    def delete(self, current_doctor, record_id):
        record = db.session.get(MedicalRecord, record_id)
        if not record or record.doctor_id != current_doctor.id:
            return {'message': 'Medical record not found'}, 404
        try:
            deleted = _service().soft_delete_record(record, deleted_by_id=current_doctor.id)
            return {'message': 'Medical record deleted successfully', 'record': deleted.to_dict()}, 200
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to delete medical record: {str(exc)}'}, 500


@medical_records_ns.route('/patient')
class PatientMedicalRecordList(Resource):
    @medical_records_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        records = MedicalRecord.query.filter(
            MedicalRecord.patient_id == current_user.id,
            MedicalRecord.status != 'deleted',
        ).order_by(MedicalRecord.created_at.desc()).all()

        grouped = {
            'scanReports': [],
            'prescriptions': [],
            'labReports': [],
            'clinicalNotes': [],
            'testResults': [],
            'all': [],
        }

        for record in records:
            payload = record.to_dict()
            record_type = (record.record_type or '').lower()

            if record_type == 'clinical_note':
                grouped['clinicalNotes'].append(payload)
            elif record_type == 'test_result':
                grouped['testResults'].append(payload)
            elif record_type == 'prescription':
                grouped['prescriptions'].append(payload)
            elif record_type == 'lab_report':
                grouped['labReports'].append(payload)
            else:
                grouped['scanReports'].append(payload)

            grouped['all'].append(payload)

        # Also expose doctor-authored consultation summaries so patients can
        # view diagnosis/prescriptions/doctor notes even if no file was attached.
        consultations = Consultation.query.filter(
            Consultation.patient_id == current_user.id,
            Consultation.doctor_id.isnot(None),
        ).order_by(Consultation.updated_at.desc()).all()

        for consultation in consultations:
            doctor_name = consultation.doctor.name if consultation.doctor else 'Unknown Doctor'
            created_at = consultation.updated_at or consultation.created_at
            date_iso = created_at.isoformat() if created_at else None

            if consultation.prescription and consultation.prescription.strip():
                payload = {
                    'id': f'consultation_{consultation.id}_prescription',
                    'record_type': 'prescription',
                    'type': 'prescription',
                    'title': f'Prescription from Dr. {doctor_name}',
                    'description': consultation.prescription.strip(),
                    'category': 'treatment',
                    'doctorName': doctor_name,
                    'source': 'doctor_consultation',
                    'created_at': date_iso,
                    'date': date_iso,
                    'consultation_id': consultation.id,
                }
                grouped['prescriptions'].append(payload)
                grouped['all'].append(payload)

            if consultation.diagnosis and consultation.diagnosis.strip():
                payload = {
                    'id': f'consultation_{consultation.id}_diagnosis',
                    'record_type': 'clinical_note',
                    'type': 'clinical_note',
                    'title': f'Diagnosis from Dr. {doctor_name}',
                    'description': consultation.diagnosis.strip(),
                    'category': 'diagnosis',
                    'doctorName': doctor_name,
                    'source': 'doctor_consultation',
                    'created_at': date_iso,
                    'date': date_iso,
                    'consultation_id': consultation.id,
                }
                grouped['clinicalNotes'].append(payload)
                grouped['all'].append(payload)

            if consultation.doctor_notes and consultation.doctor_notes.strip():
                payload = {
                    'id': f'consultation_{consultation.id}_doctor_notes',
                    'record_type': 'clinical_note',
                    'type': 'clinical_note',
                    'title': f'Consultation Notes from Dr. {doctor_name}',
                    'description': consultation.doctor_notes.strip(),
                    'category': 'general',
                    'doctorName': doctor_name,
                    'source': 'doctor_consultation',
                    'created_at': date_iso,
                    'date': date_iso,
                    'consultation_id': consultation.id,
                }
                grouped['clinicalNotes'].append(payload)
                grouped['all'].append(payload)

        grouped['total'] = len(grouped['all'])
        return grouped, 200


@medical_records_ns.route('/admin')
class AdminMedicalRecordList(Resource):
    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin=None):
        include_deleted = (request.args.get('include_deleted') or 'false').lower() in {'1', 'true', 'yes'}
        status = (request.args.get('status') or '').strip() or None
        record_type = (request.args.get('record_type') or '').strip() or None
        search = (request.args.get('q') or '').strip() or None
        doctor_id = request.args.get('doctor_id', type=int)
        patient_id = request.args.get('patient_id', type=int)
        page = request.args.get('page', default=1, type=int)
        per_page = request.args.get('per_page', default=20, type=int)

        repository = MedicalRecordRepository()
        records, total, total_pages = repository.list_admin_filtered(
            include_deleted=include_deleted,
            status=status,
            record_type=record_type,
            doctor_id=doctor_id,
            patient_id=patient_id,
            search=search,
            page=page,
            per_page=per_page,
        )
        return {
            'records': [record.to_dict() for record in records],
            'total': total,
            'page': page,
            'per_page': per_page,
            'total_pages': total_pages,
        }, 200

    @medical_records_ns.expect(medical_record_model)
    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def post(self, current_admin=None):
        data = request.get_json() or {}
        doctor_id = data.get('doctor_id')
        patient_id = data.get('patient_id')
        if not doctor_id or not patient_id:
            return {'message': 'doctor_id and patient_id are required'}, 400
        doctor = db.session.get(Doctor, doctor_id)
        patient = db.session.get(User, patient_id)
        if not doctor:
            return {'message': 'Doctor not found'}, 404
        if not patient:
            return {'message': 'Patient not found'}, 404
        try:
            record = _service().create_record(
                doctor_id=doctor.id,
                patient_id=patient.id,
                created_by_id=doctor.id,
                data=data,
            )
            return {'message': 'Medical record created successfully', 'record': record.to_dict()}, 201
        except ValueError as exc:
            return {'message': str(exc)}, 400
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to create medical record: {str(exc)}'}, 500


@medical_records_ns.route('/admin/<int:record_id>')
class AdminMedicalRecordDetail(Resource):
    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin=None, record_id=None):
        record = db.session.get(MedicalRecord, record_id)
        if not record:
            return {'message': 'Medical record not found'}, 404
        return {'record': record.to_dict()}, 200

    @medical_records_ns.expect(medical_record_model)
    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def put(self, current_admin=None, record_id=None):
        record = db.session.get(MedicalRecord, record_id)
        if not record:
            return {'message': 'Medical record not found'}, 404
        try:
            updated = _service().update_record(record, updated_by_id=record.doctor_id, data=request.get_json() or {})
            return {'message': 'Medical record updated successfully', 'record': updated.to_dict()}, 200
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to update medical record: {str(exc)}'}, 500

    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def delete(self, current_admin=None, record_id=None):
        record = db.session.get(MedicalRecord, record_id)
        if not record:
            return {'message': 'Medical record not found'}, 404
        try:
            deleted = _service().soft_delete_record(record, deleted_by_id=record.doctor_id)
            return {'message': 'Medical record deleted successfully', 'record': deleted.to_dict()}, 200
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to delete medical record: {str(exc)}'}, 500


@medical_records_ns.route('/admin/<int:record_id>/reassign')
class AdminMedicalRecordReassign(Resource):
    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def post(self, current_admin=None, record_id=None):
        data = request.get_json() or {}
        new_doctor_id = data.get('doctor_id')

        if not new_doctor_id:
            return {'message': 'doctor_id is required'}, 400

        record = db.session.get(MedicalRecord, record_id)
        if not record:
            return {'message': 'Medical record not found'}, 404

        doctor = db.session.get(Doctor, new_doctor_id)
        if not doctor:
            return {'message': 'Doctor not found'}, 404

        try:
            record.doctor_id = doctor.id
            record.updated_by_id = doctor.id
            db.session.commit()
            return {'message': 'Medical record reassigned successfully', 'record': record.to_dict()}, 200
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to reassign medical record: {str(exc)}'}, 500


@medical_records_ns.route('/upload')
class DoctorMedicalRecordUpload(Resource):
    """Upload a file attachment for a medical record (doctor-only)."""

    @medical_records_ns.doc(security='Bearer')
    @doctor_token_required
    def post(self, current_doctor):
        if 'file' not in request.files:
            return {'message': 'No file field in request'}, 400
        file = request.files['file']
        if not file.filename:
            return {'message': 'No file selected'}, 400
        try:
            meta = _save_uploaded_file(file)
        except ValueError as exc:
            return {'message': str(exc)}, 400
        return meta, 200


@medical_records_ns.route('/admin/upload')
class AdminMedicalRecordUpload(Resource):
    """Upload a file attachment for a medical record (admin-only)."""

    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def post(self, current_admin=None):
        if 'file' not in request.files:
            return {'message': 'No file field in request'}, 400
        file = request.files['file']
        if not file.filename:
            return {'message': 'No file selected'}, 400
        try:
            meta = _save_uploaded_file(file)
        except ValueError as exc:
            return {'message': str(exc)}, 400
        return meta, 200


@medical_records_ns.route('/admin/<int:record_id>/restore')
class AdminMedicalRecordRestore(Resource):
    @medical_records_ns.doc(security='Bearer')
    @admin_token_required
    def post(self, current_admin=None, record_id=None):
        record = db.session.get(MedicalRecord, record_id)
        if not record:
            return {'message': 'Medical record not found'}, 404
        try:
            restored = _service().restore_record(record, restored_by_id=record.doctor_id)
            return {'message': 'Medical record restored successfully', 'record': restored.to_dict()}, 200
        except Exception as exc:
            db.session.rollback()
            return {'message': f'Failed to restore medical record: {str(exc)}'}, 500
