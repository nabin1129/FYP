"""
Consultation Routes - Consultation Management API
Handles consultation booking, scheduling, messaging
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from datetime import datetime, timedelta
from sqlalchemy import desc, or_

from db_model import db, User
from models.doctor import Doctor, DoctorPatient
from models.consultation import Consultation, ConsultationMessage, DoctorSlot
from models.notification import Notification
from services.consultation_booking_service import (
    get_available_slot_for_booking,
    is_future_utc,
    normalize_consultation_type,
    parse_iso_datetime_utc,
)
from core.security import token_required
from routes.doctor_routes import doctor_token_required
from features.chat.firebase_history_store import mirror_message, mirror_messages_read

# Create namespace
consultation_ns = Namespace('consultations', description='Consultation management')


# ==========================
# SWAGGER MODELS
# ==========================

book_consultation_model = consultation_ns.model('BookConsultation', {
    'doctor_id': fields.Integer(required=True, description='Doctor ID'),
    'consultation_type': fields.String(description='chat or physical'),
    'reason': fields.String(description='Reason for consultation'),
    'preferred_datetime': fields.String(description='Preferred date/time ISO format'),
    'doctor_slot_id': fields.Integer(description='Doctor slot ID (required for physical)'),
})

schedule_consultation_model = consultation_ns.model('ScheduleConsultation', {
    'scheduled_at': fields.String(required=True, description='Scheduled datetime ISO format'),
})

update_consultation_model = consultation_ns.model('UpdateConsultation', {
    'status': fields.String(description='New status'),
    'doctor_notes': fields.String(description='Doctor notes'),
    'diagnosis': fields.String(description='Diagnosis'),
    'prescription': fields.String(description='Prescription'),
    'follow_up_required': fields.Boolean(description='Follow-up needed'),
    'follow_up_date': fields.String(description='Follow-up date ISO format'),
})

send_message_model = consultation_ns.model('SendMessage', {
    'content': fields.String(required=True, description='Message content'),
    'message_type': fields.String(description='text, image, file, test_result'),
    'test_type': fields.String(description='Test type if sharing result'),
    'test_id': fields.Integer(description='Test ID if sharing result'),
})

doctor_slot_model = consultation_ns.model('DoctorSlot', {
    'slot_start_at': fields.String(required=True, description='Slot start datetime in ISO UTC format'),
    'location': fields.String(description='Physical consultation location'),
    'is_active': fields.Boolean(description='Whether slot is active'),
})


# ==========================
# PATIENT CONSULTATION ROUTES
# ==========================

@consultation_ns.route('/slots/available')
class PatientAvailableSlots(Resource):
    """Patient endpoint to discover doctor assigned physical slots"""

    @consultation_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get doctor's available physical slots"""
        try:
            doctor_id = request.args.get('doctor_id', type=int)
            if not doctor_id:
                return {'message': 'doctor_id is required'}, 400

            doctor = db.session.get(Doctor, doctor_id)
            if not doctor:
                return {'message': 'Doctor not found'}, 404

            now = datetime.utcnow()
            slots = DoctorSlot.query.filter(
                DoctorSlot.doctor_id == doctor_id,
                DoctorSlot.is_active.is_(True),
                DoctorSlot.is_booked.is_(False),
                DoctorSlot.slot_start_at >= now,
            ).order_by(DoctorSlot.slot_start_at.asc()).all()

            return {
                'slots': [s.to_dict() for s in slots],
                'total': len(slots),
            }, 200

        except Exception as e:
            return {'message': f'Failed to fetch slots: {str(e)}'}, 500

@consultation_ns.route('/book')
class BookConsultation(Resource):
    """Book a consultation (patient endpoint)"""
    
    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(book_consultation_model)
    @token_required
    def post(self, current_user):
        """Book a new consultation with a doctor"""
        try:
            data = request.get_json() or {}
            doctor_id = data.get('doctor_id')
            
            if not doctor_id:
                return {'message': 'Doctor ID is required'}, 400
            
            # Check doctor exists and is available
            doctor = db.session.get(Doctor, doctor_id)
            if not doctor:
                return {'message': 'Doctor not found'}, 404
            
            if not doctor.is_available:
                return {'message': 'Doctor is not currently available'}, 400

            consultation_type = normalize_consultation_type(
                data.get('consultation_type')
            )
            consultation_status = 'pending'
            scheduled_at = None
            doctor_slot_id = None

            if consultation_type == 'physical':
                slot_id = data.get('doctor_slot_id')
                if not slot_id:
                    return {'message': 'doctor_slot_id is required for physical consultation'}, 400

                slot = get_available_slot_for_booking(int(slot_id), doctor_id)
                if not slot:
                    return {'message': 'Selected slot is not available'}, 409

                doctor_slot_id = slot.id
                scheduled_at = slot.slot_start_at
                consultation_status = 'scheduled'
                slot.is_booked = True

            preferred_datetime = data.get('preferred_datetime')
            if preferred_datetime and consultation_type != 'physical':
                try:
                    preferred_at = parse_iso_datetime_utc(preferred_datetime)
                    if is_future_utc(preferred_at):
                        scheduled_at = preferred_at
                except ValueError:
                    return {'message': 'Invalid preferred_datetime format'}, 400
            
            # Create consultation
            consultation = Consultation(
                doctor_id=doctor_id,
                patient_id=current_user.id,
                doctor_slot_id=doctor_slot_id,
                consultation_type=consultation_type,
                status=consultation_status,
                scheduled_at=scheduled_at,
                reason=data.get('reason'),
                patient_notes=data.get('reason'),
            )
            
            db.session.add(consultation)
            db.session.flush()
            
            # Create notification for doctor
            patient_name = current_user.name if hasattr(current_user, 'name') else 'A patient'
            if consultation_type == 'physical':
                notification = Notification(
                    recipient_type='doctor',
                    recipient_id=doctor_id,
                    notification_type='consultation_scheduled',
                    title='New Physical Consultation Booking',
                    message=f'{patient_name} booked your physical slot for {scheduled_at.strftime("%B %d, %Y at %I:%M %p")}.',
                    related_type='consultation',
                    related_id=consultation.id,
                    priority='high',
                )
            else:
                notification = Notification.create_consultation_request(
                    doctor_id=doctor_id,
                    patient_id=current_user.id,
                    consultation_id=consultation.id,
                    patient_name=patient_name
                )
            db.session.add(notification)
            
            # Link patient to doctor if not already linked
            existing_link = DoctorPatient.query.filter_by(
                doctor_id=doctor_id,
                patient_id=current_user.id
            ).first()
            
            if not existing_link:
                link = DoctorPatient(
                    doctor_id=doctor_id,
                    patient_id=current_user.id,
                    status='active'
                )
                db.session.add(link)
                doctor.total_patients += 1
            
            db.session.commit()
            
            return {
                'message': consultation_type == 'physical'
                    and 'Physical consultation booked successfully'
                    or 'Consultation request submitted',
                'consultation': consultation.to_dict()
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Booking failed: {str(e)}'}, 500


@consultation_ns.route('/patient/history')
class PatientConsultationHistory(Resource):
    """Patient's consultation history"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get patient's consultation history"""
        try:
            status_filter = request.args.get('status')
            
            query = Consultation.query.filter_by(patient_id=current_user.id)
            
            if status_filter:
                query = query.filter_by(status=status_filter)
            
            consultations = query.order_by(desc(Consultation.created_at)).all()
            
            return {
                'consultations': [c.to_dict() for c in consultations],
                'total': len(consultations)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch history: {str(e)}'}, 500


@consultation_ns.route('/patient/upcoming')
class PatientUpcomingConsultations(Resource):
    """Patient's upcoming consultations"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get patient's upcoming scheduled consultations"""
        try:
            # Mark any past scheduled consultations as missed
            Consultation.mark_missed_consultations()
            
            now = datetime.utcnow()
            
            consultations = Consultation.query.filter(
                Consultation.patient_id == current_user.id,
                Consultation.status.in_(['pending', 'scheduled']),
            ).order_by(Consultation.scheduled_at.asc()).all()
            
            return {
                'consultations': [c.to_dict() for c in consultations],
                'total': len(consultations)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch upcoming: {str(e)}'}, 500


# ==========================
# DOCTOR CONSULTATION ROUTES
# ==========================

@consultation_ns.route('/doctor/slots')
class DoctorSlotList(Resource):
    """Doctor-managed slot list and creation"""

    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get doctor's physical slots"""
        try:
            include_past = request.args.get('include_past', 'false').lower() == 'true'
            query = DoctorSlot.query.filter_by(doctor_id=current_doctor.id)

            if not include_past:
                query = query.filter(DoctorSlot.slot_start_at >= datetime.utcnow())

            slots = query.order_by(DoctorSlot.slot_start_at.asc()).all()

            return {
                'slots': [s.to_dict() for s in slots],
                'total': len(slots),
            }, 200

        except Exception as e:
            return {'message': f'Failed to fetch doctor slots: {str(e)}'}, 500

    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(doctor_slot_model)
    @doctor_token_required
    def post(self, current_doctor):
        """Create a doctor physical slot"""
        try:
            data = request.get_json() or {}
            slot_start_at_raw = data.get('slot_start_at')

            if not slot_start_at_raw:
                return {'message': 'slot_start_at is required'}, 400

            try:
                slot_start_at = parse_iso_datetime_utc(slot_start_at_raw)
            except ValueError:
                return {'message': 'Invalid slot_start_at format'}, 400

            if not is_future_utc(slot_start_at):
                return {'message': 'slot_start_at must be in the future (UTC)'}, 400

            slot = DoctorSlot(
                doctor_id=current_doctor.id,
                slot_start_at=slot_start_at,
                location=data.get('location') or current_doctor.working_place,
                is_active=data.get('is_active', True),
            )
            db.session.add(slot)
            db.session.commit()

            return {
                'message': 'Doctor slot created',
                'slot': slot.to_dict(),
            }, 201

        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to create slot: {str(e)}'}, 500


@consultation_ns.route('/doctor/slots/<int:slot_id>')
class DoctorSlotDetail(Resource):
    """Doctor slot update/deactivation"""

    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(doctor_slot_model)
    @doctor_token_required
    def put(self, current_doctor, slot_id):
        """Update doctor slot metadata"""
        try:
            slot = db.session.get(DoctorSlot, slot_id)
            if not slot:
                return {'message': 'Slot not found'}, 404

            if slot.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403

            data = request.get_json() or {}

            if slot.is_booked and 'slot_start_at' in data:
                return {'message': 'Booked slot time cannot be changed'}, 409

            if 'slot_start_at' in data and data['slot_start_at']:
                try:
                    slot_start_at = parse_iso_datetime_utc(data['slot_start_at'])
                except ValueError:
                    return {'message': 'Invalid slot_start_at format'}, 400
                if not is_future_utc(slot_start_at):
                    return {'message': 'slot_start_at must be in the future (UTC)'}, 400
                slot.slot_start_at = slot_start_at

            if 'location' in data:
                slot.location = data['location']
            if 'is_active' in data:
                slot.is_active = data['is_active']

            db.session.commit()
            return {
                'message': 'Slot updated',
                'slot': slot.to_dict(),
            }, 200

        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to update slot: {str(e)}'}, 500

    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def delete(self, current_doctor, slot_id):
        """Delete an unbooked doctor slot"""
        try:
            slot = db.session.get(DoctorSlot, slot_id)
            if not slot:
                return {'message': 'Slot not found'}, 404

            if slot.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403

            if slot.is_booked:
                return {'message': 'Booked slot cannot be deleted'}, 409

            db.session.delete(slot)
            db.session.commit()
            return {'message': 'Slot deleted'}, 200

        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to delete slot: {str(e)}'}, 500

@consultation_ns.route('/doctor/pending')
class DoctorPendingConsultations(Resource):
    """Doctor's pending consultation requests"""
    
    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get pending consultation requests"""
        try:
            consultations = Consultation.query.filter_by(
                doctor_id=current_doctor.id,
                status='pending'
            ).order_by(Consultation.created_at.asc()).all()
            
            return {
                'consultations': [c.to_doctor_dict() for c in consultations],
                'total': len(consultations)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch pending: {str(e)}'}, 500


@consultation_ns.route('/doctor/schedule')
class DoctorSchedule(Resource):
    """Doctor's scheduled consultations"""
    
    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get doctor's schedule"""
        try:
            # Mark any past scheduled consultations as missed
            Consultation.mark_missed_consultations()
            
            date_str = request.args.get('date')
            
            query = Consultation.query.filter_by(
                doctor_id=current_doctor.id,
                status='scheduled'
            )
            
            if date_str:
                try:
                    date = datetime.fromisoformat(date_str).date()
                    query = query.filter(
                        db.func.date(Consultation.scheduled_at) == date
                    )
                except ValueError:
                    pass
            
            consultations = query.order_by(Consultation.scheduled_at.asc()).all()
            
            return {
                'consultations': [c.to_doctor_dict() for c in consultations],
                'total': len(consultations)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch schedule: {str(e)}'}, 500


@consultation_ns.route('/doctor/history')
class DoctorConsultationHistory(Resource):
    """Doctor's consultation history"""
    
    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get doctor's consultation history"""
        try:
            status_filter = request.args.get('status')
            
            query = Consultation.query.filter_by(doctor_id=current_doctor.id)
            
            if status_filter:
                query = query.filter_by(status=status_filter)
            
            consultations = query.order_by(desc(Consultation.created_at)).all()
            
            return {
                'consultations': [c.to_doctor_dict() for c in consultations],
                'total': len(consultations)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch history: {str(e)}'}, 500


# ==========================
# CONSULTATION MANAGEMENT
# ==========================

@consultation_ns.route('/<int:consultation_id>')
class ConsultationDetail(Resource):
    """Consultation detail and management"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, consultation_id):
        """Get consultation details"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            # Check authorization
            if consultation.patient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            return {
                'consultation': consultation.to_dict(include_messages=True)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch: {str(e)}'}, 500

    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(update_consultation_model)
    @doctor_token_required
    def put(self, current_doctor, consultation_id):
        """Update consultation status (doctor)"""
        try:
            consultation = db.session.get(Consultation, consultation_id)

            if not consultation:
                return {'message': 'Consultation not found'}, 404

            if consultation.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403

            data = request.get_json() or {}
            status = data.get('status')

            if not status:
                return {'message': 'Status is required'}, 400

            if status not in ['scheduled', 'rejected', 'cancelled', 'in_progress', 'completed']:
                return {'message': 'Invalid status'}, 400

            if consultation.status == 'completed':
                return {'message': 'Completed consultation cannot be modified'}, 400

            if status == 'scheduled' and not consultation.scheduled_at:
                consultation.scheduled_at = datetime.utcnow() + timedelta(minutes=30)

            consultation.status = status

            if status == 'in_progress':
                consultation.started_at = consultation.started_at or datetime.utcnow()
                db.session.add(Notification(
                    recipient_type='user',
                    recipient_id=consultation.patient_id,
                    notification_type='consultation_started',
                    title='Consultation Started',
                    message=f'Your consultation with {current_doctor.name} has started.',
                    related_type='consultation',
                    related_id=consultation.id,
                    priority='normal',
                ))

            if status == 'completed':
                consultation.ended_at = consultation.ended_at or datetime.utcnow()
                db.session.add(Notification(
                    recipient_type='user',
                    recipient_id=consultation.patient_id,
                    notification_type='consultation_completed',
                    title='Consultation Completed',
                    message=f'Your consultation with {current_doctor.name} has been completed.',
                    related_type='consultation',
                    related_id=consultation.id,
                    priority='normal',
                ))

            # Notify patient about doctor decision for pending requests
            if status in ['scheduled', 'rejected']:
                if status == 'scheduled':
                    scheduled_label = consultation.scheduled_at.strftime('%B %d, %Y at %I:%M %p') if consultation.scheduled_at else 'soon'
                    notification = Notification.create_consultation_scheduled(
                        patient_id=consultation.patient_id,
                        consultation_id=consultation.id,
                        doctor_name=current_doctor.name,
                        scheduled_date=scheduled_label,
                    )
                else:
                    notification = Notification(
                        recipient_type='user',
                        recipient_id=consultation.patient_id,
                        notification_type='consultation_rejected',
                        title='Consultation Rejected',
                        message=f'Your consultation request with {current_doctor.name} was rejected.',
                        related_type='consultation',
                        related_id=consultation.id,
                        priority='normal',
                    )
                db.session.add(notification)

            db.session.commit()

            return {
                'message': 'Consultation updated successfully',
                'consultation': consultation.to_dict(),
            }, 200

        except Exception as e:
            db.session.rollback()
            return {'message': f'Update failed: {str(e)}'}, 500


@consultation_ns.route('/<int:consultation_id>/schedule')
class ScheduleConsultation(Resource):
    """Schedule a consultation (doctor endpoint)"""
    
    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(schedule_consultation_model)
    @doctor_token_required
    def post(self, current_doctor, consultation_id):
        """Schedule a pending consultation"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            if consultation.status != 'pending':
                return {'message': 'Consultation is not pending'}, 400

            if consultation.consultation_type == 'physical':
                return {'message': 'Physical consultations are scheduled from doctor slots'}, 409
            
            data = request.get_json() or {}
            
            if not data.get('scheduled_at'):
                return {'message': 'Scheduled datetime is required'}, 400
            
            try:
                scheduled_at = parse_iso_datetime_utc(data['scheduled_at'])
            except ValueError:
                return {'message': 'Invalid datetime format'}, 400

            if not is_future_utc(scheduled_at):
                return {'message': 'Cannot schedule consultation in the past. Please select a future date and time.'}, 400
            
            consultation.scheduled_at = scheduled_at
            consultation.status = 'scheduled'
            
            # Create notification for patient
            notification = Notification.create_consultation_scheduled(
                patient_id=consultation.patient_id,
                consultation_id=consultation.id,
                doctor_name=current_doctor.name,
                scheduled_date=scheduled_at.strftime('%B %d, %Y at %I:%M %p')
            )
            db.session.add(notification)
            
            db.session.commit()
            
            return {
                'message': 'Consultation scheduled',
                'consultation': consultation.to_dict()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Scheduling failed: {str(e)}'}, 500


@consultation_ns.route('/<int:consultation_id>/start')
class StartConsultation(Resource):
    """Start a consultation (doctor endpoint)"""
    
    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def post(self, current_doctor, consultation_id):
        """Start a scheduled consultation"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            if consultation.status != 'scheduled':
                return {'message': 'Consultation is not scheduled'}, 400
            
            consultation.status = 'in_progress'
            consultation.started_at = datetime.utcnow()

            db.session.add(Notification(
                recipient_type='user',
                recipient_id=consultation.patient_id,
                notification_type='consultation_started',
                title='Consultation Started',
                message=f'Your consultation with {current_doctor.name} has started.',
                related_type='consultation',
                related_id=consultation.id,
                priority='normal',
            ))
            
            db.session.commit()
            
            return {
                'message': 'Consultation started',
                'consultation': consultation.to_dict()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Start failed: {str(e)}'}, 500


@consultation_ns.route('/<int:consultation_id>/complete')
class CompleteConsultation(Resource):
    """Complete a consultation (doctor endpoint)"""
    
    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(update_consultation_model)
    @doctor_token_required
    def post(self, current_doctor, consultation_id):
        """Complete a consultation with notes and diagnosis"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            if consultation.status not in ['scheduled', 'in_progress']:
                return {'message': 'Consultation cannot be completed'}, 400
            
            data = request.get_json() or {}
            
            consultation.status = 'completed'
            consultation.ended_at = datetime.utcnow()
            
            if data.get('doctor_notes'):
                consultation.doctor_notes = data['doctor_notes']
            if data.get('diagnosis'):
                consultation.diagnosis = data['diagnosis']
            if data.get('prescription'):
                consultation.prescription = data['prescription']
            if 'follow_up_required' in data:
                consultation.follow_up_required = data['follow_up_required']
            if data.get('follow_up_date'):
                consultation.follow_up_date = datetime.fromisoformat(data['follow_up_date'])
            
            # Update doctor stats
            current_doctor.total_consultations += 1
            
            # Update patient link with last consultation date
            link = DoctorPatient.query.filter_by(
                doctor_id=current_doctor.id,
                patient_id=consultation.patient_id
            ).first()
            if link:
                link.last_consultation = datetime.utcnow()

            db.session.add(Notification(
                recipient_type='user',
                recipient_id=consultation.patient_id,
                notification_type='consultation_completed',
                title='Consultation Completed',
                message=f'Your consultation with {current_doctor.name} has been completed.',
                related_type='consultation',
                related_id=consultation.id,
                priority='normal',
            ))
            
            db.session.commit()
            
            return {
                'message': 'Consultation completed',
                'consultation': consultation.to_dict()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Completion failed: {str(e)}'}, 500


@consultation_ns.route('/<int:consultation_id>/cancel')
class CancelConsultation(Resource):
    """Cancel a consultation"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user, consultation_id):
        """Cancel a consultation (by patient)"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.patient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            if consultation.status in ['completed', 'cancelled']:
                return {'message': 'Consultation cannot be cancelled'}, 400
            
            consultation.status = 'cancelled'

            db.session.add(Notification(
                recipient_type='doctor',
                recipient_id=consultation.doctor_id,
                notification_type='consultation_cancelled',
                title='Consultation Cancelled',
                message='A patient cancelled their consultation request.',
                related_type='consultation',
                related_id=consultation.id,
                priority='normal',
            ))
            db.session.commit()
            
            return {'message': 'Consultation cancelled'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Cancellation failed: {str(e)}'}, 500


# ==========================
# CONSULTATION MESSAGING
# ==========================

@consultation_ns.route('/<int:consultation_id>/messages')
class ConsultationMessages(Resource):
    """Consultation chat messages"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, consultation_id):
        """Get consultation messages"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.patient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            messages = consultation.messages.order_by(
                ConsultationMessage.created_at.asc()
            ).all()
            
            # Mark messages as read
            read_at = datetime.utcnow()
            updated_messages = []
            for msg in messages:
                if msg.sender_type == 'doctor' and not msg.is_read:
                    msg.is_read = True
                    msg.read_at = read_at
                    updated_messages.append(msg)
            
            db.session.commit()
            if updated_messages:
                mirror_messages_read(consultation, updated_messages, read_at=read_at)
            
            return {
                'messages': [m.to_dict() for m in messages]
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch messages: {str(e)}'}, 500
    
    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(send_message_model)
    @token_required
    def post(self, current_user, consultation_id):
        """Send a message (patient)"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.patient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            data = request.get_json()

            attachments = data.get('attachments') or []
            if not isinstance(attachments, list):
                attachments = []
            first_attachment = attachments[0] if attachments else None
            if first_attachment is not None and not isinstance(first_attachment, dict):
                first_attachment = None

            content = (data.get('content') or data.get('message') or '').strip()
            if not content and not first_attachment:
                return {'message': 'Message content is required'}, 400

            message_type = (data.get('message_type') or 'text').lower()
            if first_attachment:
                message_type = (
                    first_attachment.get('type') or
                    first_attachment.get('attachment_type') or
                    message_type or
                    'file'
                ).lower()
                if message_type == 'attachment':
                    message_type = 'file'
                if not content:
                    content = 'Shared attachment'

            file_url = None
            file_name = None
            test_type = data.get('test_type')
            test_id = data.get('test_id')
            if first_attachment:
                file_url = first_attachment.get('url')
                file_name = first_attachment.get('file_name') or first_attachment.get('fileName')
                if not test_type:
                    test_type = first_attachment.get('linked_entity_title') or first_attachment.get('linkedEntityTitle')
                if test_id is None:
                    linked_id = first_attachment.get('linked_entity_id') or first_attachment.get('linkedEntityId')
                    if linked_id is not None:
                        try:
                            test_id = int(linked_id)
                        except (TypeError, ValueError):
                            test_id = None
            
            message = ConsultationMessage(
                consultation_id=consultation_id,
                sender_type='patient',
                sender_id=current_user.id,
                message_type=message_type,
                content=content,
                file_url=file_url,
                file_name=file_name,
                test_type=test_type,
                test_id=test_id,
            )
            
            db.session.add(message)
            
            # Create notification for doctor
            patient_name = current_user.name if hasattr(current_user, 'name') else 'Patient'
            notification = Notification.create_message_notification(
                recipient_type='doctor',
                recipient_id=consultation.doctor_id,
                sender_name=patient_name,
                consultation_id=consultation_id
            )
            db.session.add(notification)
            
            db.session.commit()
            mirror_message(consultation, message)
            
            return {
                'message': 'Message sent',
                'data': message.to_dict(),
                'chat_message': message.to_dict(),
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Send failed: {str(e)}'}, 500


@consultation_ns.route('/<int:consultation_id>/doctor/messages')
class DoctorConsultationMessages(Resource):
    """Doctor's consultation messages endpoint"""
    
    @consultation_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor, consultation_id):
        """Get consultation messages (doctor)"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            messages = consultation.messages.order_by(
                ConsultationMessage.created_at.asc()
            ).all()
            
            # Mark patient messages as read
            read_at = datetime.utcnow()
            updated_messages = []
            for msg in messages:
                if msg.sender_type == 'patient' and not msg.is_read:
                    msg.is_read = True
                    msg.read_at = read_at
                    updated_messages.append(msg)
            
            db.session.commit()
            if updated_messages:
                mirror_messages_read(consultation, updated_messages, read_at=read_at)
            
            return {
                'messages': [m.to_dict() for m in messages]
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch messages: {str(e)}'}, 500
    
    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(send_message_model)
    @doctor_token_required
    def post(self, current_doctor, consultation_id):
        """Send a message (doctor)"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.doctor_id != current_doctor.id:
                return {'message': 'Not authorized'}, 403
            
            data = request.get_json() or {}

            attachments = data.get('attachments') or []
            if not isinstance(attachments, list):
                attachments = []
            first_attachment = attachments[0] if attachments else None
            if first_attachment is not None and not isinstance(first_attachment, dict):
                first_attachment = None

            content = (data.get('content') or data.get('message') or '').strip()
            if not content and not first_attachment:
                return {'message': 'Message content is required'}, 400

            message_type = (data.get('message_type') or 'text').lower()
            if first_attachment:
                message_type = (
                    first_attachment.get('type') or
                    first_attachment.get('attachment_type') or
                    message_type or
                    'file'
                ).lower()
                if message_type == 'attachment':
                    message_type = 'file'
                if not content:
                    content = 'Shared attachment'

            file_url = None
            file_name = None
            test_type = data.get('test_type')
            test_id = data.get('test_id')
            if first_attachment:
                file_url = first_attachment.get('url')
                file_name = first_attachment.get('file_name') or first_attachment.get('fileName')
                if not test_type:
                    test_type = first_attachment.get('linked_entity_title') or first_attachment.get('linkedEntityTitle')
                if test_id is None:
                    linked_id = first_attachment.get('linked_entity_id') or first_attachment.get('linkedEntityId')
                    if linked_id is not None:
                        try:
                            test_id = int(linked_id)
                        except (TypeError, ValueError):
                            test_id = None
            
            message = ConsultationMessage(
                consultation_id=consultation_id,
                sender_type='doctor',
                sender_id=current_doctor.id,
                message_type=message_type,
                content=content,
                file_url=file_url,
                file_name=file_name,
                test_type=test_type,
                test_id=test_id,
            )
            
            db.session.add(message)
            
            # Create notification for patient
            notification = Notification.create_message_notification(
                recipient_type='user',
                recipient_id=consultation.patient_id,
                sender_name=current_doctor.name,
                consultation_id=consultation_id
            )
            db.session.add(notification)
            
            db.session.commit()
            mirror_message(consultation, message)
            
            return {
                'message': 'Message sent',
                'data': message.to_dict(),
                'chat_message': message.to_dict(),
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Send failed: {str(e)}'}, 500


# ==========================
# SHARE TEST RESULTS
# ==========================

@consultation_ns.route('/<int:consultation_id>/share-test')
class ShareTestResult(Resource):
    """Share test result in consultation"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user, consultation_id):
        """Share a test result with doctor"""
        try:
            consultation = db.session.get(Consultation, consultation_id)
            
            if not consultation:
                return {'message': 'Consultation not found'}, 404
            
            if consultation.patient_id != current_user.id:
                return {'message': 'Not authorized'}, 403
            
            data = request.get_json()
            test_type = data.get('test_type')
            test_id = data.get('test_id')
            
            if not test_type or not test_id:
                return {'message': 'Test type and ID are required'}, 400
            
            # Create message with test reference
            message = ConsultationMessage(
                consultation_id=consultation_id,
                sender_type='patient',
                sender_id=current_user.id,
                message_type='test_result',
                content=f'Shared {test_type.replace("_", " ").title()} test result',
                test_type=test_type,
                test_id=test_id,
            )
            
            db.session.add(message)
            
            # Update shared tests
            shared_tests = consultation.get_shared_test_ids()
            shared_tests.append({'type': test_type, 'id': test_id})
            consultation.set_shared_test_ids(shared_tests)
            
            # Notify doctor
            patient_name = current_user.name if hasattr(current_user, 'name') else 'Patient'
            notification = Notification.create_test_shared(
                doctor_id=consultation.doctor_id,
                patient_id=current_user.id,
                test_type=test_type.replace('_', ' ').title(),
                patient_name=patient_name
            )
            db.session.add(notification)
            
            db.session.commit()
            mirror_message(consultation, message)
            
            return {
                'message': 'Test result shared',
                'data': message.to_dict()
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Share failed: {str(e)}'}, 500


# ==========================
# DOCTOR-ASSIGNED RECORDS
# ==========================

@consultation_ns.route('/assigned-records')
class DoctorAssignedRecords(Resource):
    """Fetch medical records, clinical notes, and test results assigned by doctors"""
    
    @consultation_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get all doctor-assigned records (medical records, clinical notes, test results)"""
        try:
            # Query all consultation messages from doctors with various record types
            messages = ConsultationMessage.query.join(
                Consultation, ConsultationMessage.consultation_id == Consultation.id
            ).filter(
                Consultation.patient_id == current_user.id,
                ConsultationMessage.sender_type == 'doctor',
                ConsultationMessage.message_type.in_([
                    'medicalRecord', 'medical_record',
                    'clinicalNote', 'clinical_note',
                    'testResult', 'test_result'
                ])
            ).order_by(ConsultationMessage.created_at.desc()).all()
            
            # Convert messages to record format organized by type
            records = {
                'scanReports': [],
                'prescriptions': [],
                'labReports': [],
                'clinicalNotes': [],
                'testResults': [],
                'all': []
            }
            
            for msg in messages:
                doctor = db.session.get(Doctor, msg.sender_id)
                doctor_name = doctor.name if doctor else 'Unknown Doctor'
                
                # Determine the category based on message type
                message_type_lower = msg.message_type.lower() if msg.message_type else ''
                is_clinical = 'clinical' in message_type_lower
                is_test = 'test' in message_type_lower
                
                record = {
                    'id': msg.id,
                    'title': msg.content or f'{msg.test_type or "Document"} from {doctor_name}',
                    'type': msg.test_type or 'document',
                    'date': msg.created_at.isoformat() if msg.created_at else None,
                    'fileName': msg.file_name or 'document.pdf',
                    'url': msg.file_url,
                    'source': 'doctor',
                    'doctorName': doctor_name,
                    'doctorId': msg.sender_id,
                    'consultationId': msg.consultation_id,
                    'description': msg.content,
                    'messageId': msg.id
                }
                
                records['all'].append(record)
                
                # Categorize by message type first
                if is_clinical:
                    records['clinicalNotes'].append(record)
                elif is_test:
                    records['testResults'].append(record)
                else:
                    # Medical record - further categorize by test_type
                    if msg.test_type:
                        test_type_lower = msg.test_type.lower()
                        if 'scan' in test_type_lower or 'image' in test_type_lower:
                            records['scanReports'].append(record)
                        elif 'prescription' in test_type_lower or 'medicine' in test_type_lower:
                            records['prescriptions'].append(record)
                        elif 'lab' in test_type_lower or 'report' in test_type_lower:
                            records['labReports'].append(record)
                        else:
                            records['labReports'].append(record)
                    else:
                        records['labReports'].append(record)
            
            return records, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch assigned records: {str(e)}'}, 500

