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
from models.consultation import Consultation, ConsultationMessage
from models.notification import Notification
from core.security import token_required
from routes.doctor_routes import doctor_token_required

# Create namespace
consultation_ns = Namespace('consultations', description='Consultation management')


# ==========================
# SWAGGER MODELS
# ==========================

book_consultation_model = consultation_ns.model('BookConsultation', {
    'doctor_id': fields.Integer(required=True, description='Doctor ID'),
    'consultation_type': fields.String(description='video_call or chat'),
    'reason': fields.String(description='Reason for consultation'),
    'preferred_datetime': fields.String(description='Preferred date/time ISO format'),
})

schedule_consultation_model = consultation_ns.model('ScheduleConsultation', {
    'scheduled_at': fields.String(required=True, description='Scheduled datetime ISO format'),
    'duration_minutes': fields.Integer(description='Duration in minutes'),
    'fee': fields.Float(description='Consultation fee'),
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


# ==========================
# PATIENT CONSULTATION ROUTES
# ==========================

@consultation_ns.route('/book')
class BookConsultation(Resource):
    """Book a consultation (patient endpoint)"""
    
    @consultation_ns.doc(security='Bearer')
    @consultation_ns.expect(book_consultation_model)
    @token_required
    def post(self, current_user):
        """Book a new consultation with a doctor"""
        try:
            data = request.get_json()
            doctor_id = data.get('doctor_id')
            
            if not doctor_id:
                return {'message': 'Doctor ID is required'}, 400
            
            # Check doctor exists and is available
            doctor = db.session.get(Doctor, doctor_id)
            if not doctor:
                return {'message': 'Doctor not found'}, 404
            
            if not doctor.is_available:
                return {'message': 'Doctor is not currently available'}, 400
            
            # Create consultation
            consultation = Consultation(
                doctor_id=doctor_id,
                patient_id=current_user.id,
                consultation_type=data.get('consultation_type', 'video_call'),
                status='pending',
                reason=data.get('reason'),
                patient_notes=data.get('reason'),
                fee=doctor.consultation_fee,
            )
            
            db.session.add(consultation)
            
            # Create notification for doctor
            patient_name = current_user.name if hasattr(current_user, 'name') else 'A patient'
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
                'message': 'Consultation request submitted',
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

            if status == 'completed':
                consultation.ended_at = consultation.ended_at or datetime.utcnow()

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
            
            data = request.get_json()
            
            if not data.get('scheduled_at'):
                return {'message': 'Scheduled datetime is required'}, 400
            
            try:
                scheduled_at = datetime.fromisoformat(data['scheduled_at'].replace('Z', '+00:00'))
            except ValueError:
                return {'message': 'Invalid datetime format'}, 400
            
            consultation.scheduled_at = scheduled_at
            consultation.duration_minutes = data.get('duration_minutes', 30)
            consultation.fee = data.get('fee', current_doctor.consultation_fee)
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
            for msg in messages:
                if msg.sender_type == 'doctor' and not msg.is_read:
                    msg.is_read = True
                    msg.read_at = datetime.utcnow()
            
            db.session.commit()
            
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
            
            content = (data.get('content') or data.get('message') or '').strip()
            if not content:
                return {'message': 'Message content is required'}, 400
            
            message = ConsultationMessage(
                consultation_id=consultation_id,
                sender_type='patient',
                sender_id=current_user.id,
                message_type=data.get('message_type', 'text'),
                content=content,
                test_type=data.get('test_type'),
                test_id=data.get('test_id'),
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
            for msg in messages:
                if msg.sender_type == 'patient' and not msg.is_read:
                    msg.is_read = True
                    msg.read_at = datetime.utcnow()
            
            db.session.commit()
            
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
            
            data = request.get_json()
            
            content = (data.get('content') or data.get('message') or '').strip()
            if not content:
                return {'message': 'Message content is required'}, 400
            
            message = ConsultationMessage(
                consultation_id=consultation_id,
                sender_type='doctor',
                sender_id=current_doctor.id,
                message_type=data.get('message_type', 'text'),
                content=content,
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
            
            return {
                'message': 'Test result shared',
                'data': message.to_dict()
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Share failed: {str(e)}'}, 500

