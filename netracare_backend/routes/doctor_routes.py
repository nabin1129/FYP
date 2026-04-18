"""
Doctor Routes - Doctor Management API
Handles doctor registration, profile, patient management
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash, check_password_hash
from datetime import datetime, timedelta
import jwt

from db_model import db, User
from models.doctor import Doctor, DoctorPatient
from core.security import token_required
from core.config import BaseConfig

# Create namespace
doctor_ns = Namespace('doctors', description='Doctor management operations')


# ==========================
# SWAGGER MODELS
# ==========================

doctor_register_model = doctor_ns.model('DoctorRegister', {
    'name': fields.String(required=True, description='Full name'),
    'email': fields.String(required=True, description='Email address'),
    'password': fields.String(required=True, description='Password'),
    'phone': fields.String(description='Phone number'),
    'nhpc_number': fields.String(required=True, description='NHPC registration number'),
    'qualification': fields.String(required=True, description='Medical qualification'),
    'specialization': fields.String(description='Specialization'),
    'experience_years': fields.Integer(description='Years of experience'),
    'working_place': fields.String(description='Hospital/Clinic name'),
    'address': fields.String(description='Address'),
})

doctor_login_model = doctor_ns.model('DoctorLogin', {
    'email': fields.String(required=True, description='Email'),
    'password': fields.String(required=True, description='Password'),
})

doctor_update_model = doctor_ns.model('DoctorUpdate', {
    'name': fields.String(description='Full name'),
    'phone': fields.String(description='Phone number'),
    'specialization': fields.String(description='Specialization'),
    'experience_years': fields.Integer(description='Years of experience'),
    'working_place': fields.String(description='Hospital/Clinic'),
    'address': fields.String(description='Address'),
    'is_available': fields.Boolean(description='Availability status'),
})

link_patient_model = doctor_ns.model('LinkPatient', {
    'patient_id': fields.Integer(required=True, description='Patient user ID'),
    'notes': fields.String(description='Initial notes'),
})

change_password_model = doctor_ns.model('DoctorChangePassword', {
    'current_password': fields.String(required=True, description='Current password'),
    'new_password': fields.String(required=True, description='New password (min 8 chars, upper+lower+digit+special)'),
})


# ==========================
# HELPER FUNCTIONS
# ==========================

def generate_doctor_token(doctor_id: int) -> str:
    """Generate JWT token for doctor"""
    payload = {
        'doctor_id': doctor_id,
        'type': 'doctor',
        'exp': datetime.utcnow() + timedelta(days=7)
    }
    return jwt.encode(payload, BaseConfig.SECRET_KEY, algorithm='HS256')


def doctor_token_required(f):
    """Decorator to require doctor authentication"""
    from functools import wraps
    
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            try:
                token = auth_header.split(' ')[1]
            except IndexError:
                return {'message': 'Invalid token format'}, 401
        
        if not token:
            return {'message': 'Token is missing'}, 401
        
        try:
            payload = jwt.decode(token, BaseConfig.SECRET_KEY, algorithms=['HS256'])
            
            # Check if it's a doctor token
            if payload.get('type') != 'doctor':
                return {'message': 'Invalid token type'}, 401
            
            doctor = db.session.get(Doctor, payload['doctor_id'])
            if not doctor:
                return {'message': 'Doctor not found'}, 401
            
            if not doctor.is_active:
                return {'message': 'Account is deactivated'}, 401
            
            kwargs['current_doctor'] = doctor
            return f(*args, **kwargs)
            
        except jwt.ExpiredSignatureError:
            return {'message': 'Token has expired'}, 401
        except jwt.InvalidTokenError:
            return {'message': 'Invalid token'}, 401
    
    return decorated


# ==========================
# DOCTOR AUTH ROUTES
# ==========================

@doctor_ns.route('/register')
class DoctorRegister(Resource):
    """Doctor registration endpoint"""
    
    @doctor_ns.expect(doctor_register_model)
    def post(self):
        """Register a new doctor"""
        try:
            data = request.get_json()
            
            # Validate required fields
            required = ['name', 'email', 'password', 'nhpc_number', 'qualification']
            for field in required:
                if not data.get(field):
                    return {'message': f'{field} is required'}, 400
            
            # Check if email exists
            if Doctor.query.filter_by(email=data['email']).first():
                return {'message': 'Email already registered'}, 400
            
            # Check if NHPC number exists
            if Doctor.query.filter_by(nhpc_number=data['nhpc_number']).first():
                return {'message': 'NHPC number already registered'}, 400
            
            # Create doctor
            doctor = Doctor(
                name=data['name'],
                email=data['email'],
                password_hash=generate_password_hash(data['password']),
                phone=data.get('phone'),
                nhpc_number=data['nhpc_number'],
                qualification=data['qualification'],
                specialization=data.get('specialization', 'Ophthalmology'),
                experience_years=data.get('experience_years', 0),
                working_place=data.get('working_place'),
                address=data.get('address'),
                is_verified=False,  # Requires admin verification
            )
            
            db.session.add(doctor)
            db.session.commit()
            
            token = generate_doctor_token(doctor.id)
            
            return {
                'message': 'Doctor registered successfully',
                'token': token,
                'doctor': doctor.to_dict()
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Registration failed: {str(e)}'}, 500


@doctor_ns.route('/login')
class DoctorLogin(Resource):
    """Doctor login endpoint"""
    
    @doctor_ns.expect(doctor_login_model)
    def post(self):
        """Login as doctor"""
        try:
            data = request.get_json()
            
            if not data.get('email') or not data.get('password'):
                return {'message': 'Email and password are required'}, 400
            
            doctor = Doctor.query.filter_by(email=data['email']).first()
            
            if not doctor or not check_password_hash(doctor.password_hash, data['password']):
                return {'message': 'Invalid email or password'}, 401
            
            if not doctor.is_active:
                return {'message': 'Account is deactivated'}, 401
            
            # Update last login
            doctor.last_login = datetime.utcnow()
            db.session.commit()
            
            token = generate_doctor_token(doctor.id)

            return {
                'message': 'Login successful',
                'token': token,
                'force_password_change': doctor.force_password_change,
                'doctor': doctor.to_dict()
            }, 200
            
        except Exception as e:
            return {'message': f'Login failed: {str(e)}'}, 500


# ==========================
# DOCTOR PROFILE ROUTES
# ==========================

@doctor_ns.route('/profile')
class DoctorProfile(Resource):
    """Doctor profile management"""
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get doctor profile"""
        return {
            'doctor': current_doctor.to_dict(include_sensitive=True)
        }, 200
    
    @doctor_ns.doc(security='Bearer')
    @doctor_ns.expect(doctor_update_model)
    @doctor_token_required
    def put(self, current_doctor):
        """Update doctor profile"""
        try:
            data = request.get_json()
            
            updateable_fields = [
                'name', 'phone', 'specialization', 'experience_years',
                'working_place', 'address', 'is_available',
                'profile_image_url'
            ]
            
            for field in updateable_fields:
                if field in data:
                    setattr(current_doctor, field, data[field])
            
            db.session.commit()
            
            return {
                'message': 'Profile updated successfully',
                'doctor': current_doctor.to_dict()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Update failed: {str(e)}'}, 500


@doctor_ns.route('/availability')
class DoctorAvailability(Resource):
    """Doctor availability management"""
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get availability schedule"""
        return {
            'is_available': current_doctor.is_available,
            'schedule': current_doctor.get_availability_schedule()
        }, 200
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def put(self, current_doctor):
        """Update availability schedule"""
        try:
            data = request.get_json()
            
            if 'is_available' in data:
                current_doctor.is_available = data['is_available']
            
            if 'schedule' in data:
                current_doctor.set_availability_schedule(data['schedule'])
            
            db.session.commit()
            
            return {
                'message': 'Availability updated',
                'is_available': current_doctor.is_available,
                'schedule': current_doctor.get_availability_schedule()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Update failed: {str(e)}'}, 500


# ==========================
# CHANGE PASSWORD
# ==========================

import re as _re
_STRONG_PASSWORD = _re.compile(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$'
)

@doctor_ns.route('/change-password')
class DoctorChangePassword(Resource):
    """Doctor password change — required on first login for admin-created accounts"""

    @doctor_ns.doc(security='Bearer')
    @doctor_ns.expect(change_password_model)
    @doctor_token_required
    def post(self, current_doctor):
        """Change doctor password"""
        try:
            data = request.get_json()
            current_pw = data.get('current_password', '')
            new_pw = data.get('new_password', '')

            if not check_password_hash(current_doctor.password_hash, current_pw):
                return {'message': 'Current password is incorrect'}, 400

            if not _STRONG_PASSWORD.match(new_pw):
                return {
                    'message': 'New password must be at least 8 characters and include '
                               'uppercase, lowercase, digit and special character (@$!%*?&)'
                }, 400

            if current_pw == new_pw:
                return {'message': 'New password must differ from current password'}, 400

            current_doctor.password_hash = generate_password_hash(new_pw)
            current_doctor.force_password_change = False
            db.session.commit()

            return {'message': 'Password changed successfully'}, 200

        except Exception as e:
            db.session.rollback()
            return {'message': f'Password change failed: {str(e)}'}, 500


# ==========================
# ALL APP USERS (for doctor dashboard — name + id only, no test data)
# ==========================

@doctor_ns.route('/all-users')
class DoctorAllUsers(Resource):
    """Doctor sees all registered app users (name + id only).
    Test data is only visible after the user explicitly shares it."""

    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """List all registered users (minimal info)"""
        try:
            users = User.query.order_by(User.created_at.desc()).all()
            return {
                'users': [
                    {
                        'id': u.id,
                        'name': u.name or 'Unknown',
                        'email': u.email,
                        'created_at': u.created_at.isoformat() if u.created_at else None,
                    }
                    for u in users
                ],
                'total': len(users),
            }, 200
        except Exception as e:
            return {'message': f'Failed to fetch users: {str(e)}'}, 500


# ==========================
# DOCTOR LIST (PUBLIC)
# ==========================

@doctor_ns.route('/list')
class DoctorList(Resource):
    """Public list of doctors"""
    
    def get(self):
        """Get all available doctors (for patients to book consultations)"""
        try:
            # Query parameters
            specialization = request.args.get('specialization')
            available_only = request.args.get('available', 'true').lower() == 'true'
            
            query = Doctor.query.filter_by(is_active=True, is_verified=True)
            
            if available_only:
                query = query.filter_by(is_available=True)
            
            if specialization:
                query = query.filter(Doctor.specialization.ilike(f'%{specialization}%'))
            
            doctors = query.order_by(Doctor.rating.desc()).all()
            
            return {
                'doctors': [d.to_public_dict() for d in doctors],
                'total': len(doctors)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch doctors: {str(e)}'}, 500


@doctor_ns.route('/search')
class DoctorSearch(Resource):
    """Search doctors"""
    
    def get(self):
        """Search doctors by name or specialization"""
        try:
            query_param = request.args.get('q', '')
            
            if not query_param:
                return {'doctors': [], 'total': 0}, 200
            
            doctors = Doctor.query.filter(
                Doctor.is_active == True,
                db.or_(
                    Doctor.name.ilike(f'%{query_param}%'),
                    Doctor.specialization.ilike(f'%{query_param}%'),
                    Doctor.working_place.ilike(f'%{query_param}%')
                )
            ).all()
            
            return {
                'doctors': [d.to_public_dict() for d in doctors],
                'total': len(doctors)
            }, 200
            
        except Exception as e:
            return {'message': f'Search failed: {str(e)}'}, 500


@doctor_ns.route('/<int:doctor_id>')
class DoctorDetail(Resource):
    """Doctor detail endpoint"""
    
    def get(self, doctor_id):
        """Get doctor details by ID"""
        doctor = db.session.get(Doctor, doctor_id)
        
        if not doctor:
            return {'message': 'Doctor not found'}, 404
        
        return {'doctor': doctor.to_public_dict()}, 200


# ==========================
# PATIENT MANAGEMENT
# ==========================

@doctor_ns.route('/patients')
class DoctorPatients(Resource):
    """Doctor's patient list"""
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get all patients linked to this doctor"""
        try:
            # Query parameters
            status_filter = request.args.get('status')
            search_query = request.args.get('q')
            
            query = DoctorPatient.query.filter_by(doctor_id=current_doctor.id)
            
            if status_filter:
                query = query.filter_by(health_status=status_filter)
            
            links = query.all()
            
            patients = []
            for link in links:
                patient_data = link.get_patient_summary()
                
                # Apply search filter
                if search_query:
                    if search_query.lower() not in patient_data['name'].lower():
                        continue
                
                patients.append(patient_data)
            
            return {
                'patients': patients,
                'total': len(patients)
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch patients: {str(e)}'}, 500
    
    @doctor_ns.doc(security='Bearer')
    @doctor_ns.expect(link_patient_model)
    @doctor_token_required
    def post(self, current_doctor):
        """Link a patient to this doctor"""
        try:
            data = request.get_json()
            patient_id = data.get('patient_id')
            
            if not patient_id:
                return {'message': 'Patient ID is required'}, 400
            
            # Check if patient exists
            patient = db.session.get(User, patient_id)
            if not patient:
                return {'message': 'Patient not found'}, 404
            
            # Check if already linked
            existing = DoctorPatient.query.filter_by(
                doctor_id=current_doctor.id,
                patient_id=patient_id
            ).first()
            
            if existing:
                return {'message': 'Patient already linked'}, 400
            
            # Create link
            link = DoctorPatient(
                doctor_id=current_doctor.id,
                patient_id=patient_id,
                doctor_notes=data.get('notes'),
            )
            
            db.session.add(link)
            current_doctor.total_patients += 1
            db.session.commit()
            
            return {
                'message': 'Patient linked successfully',
                'link': link.to_dict()
            }, 201
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to link patient: {str(e)}'}, 500


@doctor_ns.route('/patients/<int:patient_id>')
class DoctorPatientDetail(Resource):
    """Single patient detail for doctor"""
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor, patient_id):
        """Get patient details including test history"""
        try:
            link = DoctorPatient.query.filter_by(
                doctor_id=current_doctor.id,
                patient_id=patient_id
            ).first()
            
            if not link:
                return {'message': 'Patient not linked to you'}, 404
            
            patient = link.patient
            
            # Get test results
            from db_model import (
                VisualAcuityTest, ColourVisionTest, BlinkFatigueTest,
                PupilReflexTest, EyeTrackingTest
            )
            
            test_history = {
                'visual_acuity': [t.to_dict() for t in VisualAcuityTest.query.filter_by(user_id=patient_id).order_by(VisualAcuityTest.created_at.desc()).limit(5).all()],
                'colour_vision': [t.to_dict() for t in ColourVisionTest.query.filter_by(user_id=patient_id).order_by(ColourVisionTest.created_at.desc()).limit(5).all()],
                'blink_fatigue': [t.to_dict() for t in BlinkFatigueTest.query.filter_by(user_id=patient_id).order_by(BlinkFatigueTest.created_at.desc()).limit(5).all()],
                'pupil_reflex': [t.to_dict() for t in PupilReflexTest.query.filter_by(user_id=patient_id).order_by(PupilReflexTest.created_at.desc()).limit(5).all()],
                'eye_tracking': [t.to_dict() for t in EyeTrackingTest.query.filter_by(user_id=patient_id).order_by(EyeTrackingTest.created_at.desc()).limit(5).all()],
            }
            
            return {
                'patient': link.get_patient_summary(),
                'link_info': link.to_dict(),
                'test_history': test_history,
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch patient: {str(e)}'}, 500
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def put(self, current_doctor, patient_id):
        """Update patient notes/health score"""
        try:
            link = DoctorPatient.query.filter_by(
                doctor_id=current_doctor.id,
                patient_id=patient_id
            ).first()
            
            if not link:
                return {'message': 'Patient not linked to you'}, 404
            
            data = request.get_json()
            
            updateable = ['health_score', 'trend', 'health_status', 'doctor_notes']
            for field in updateable:
                if field in data:
                    setattr(link, field, data[field])
            
            db.session.commit()
            
            return {
                'message': 'Patient info updated',
                'link': link.to_dict()
            }, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to update: {str(e)}'}, 500
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def delete(self, current_doctor, patient_id):
        """Unlink patient from doctor"""
        try:
            link = DoctorPatient.query.filter_by(
                doctor_id=current_doctor.id,
                patient_id=patient_id
            ).first()
            
            if not link:
                return {'message': 'Patient not linked to you'}, 404
            
            db.session.delete(link)
            current_doctor.total_patients = max(0, current_doctor.total_patients - 1)
            db.session.commit()
            
            return {'message': 'Patient unlinked successfully'}, 200
            
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to unlink: {str(e)}'}, 500


# ==========================
# DOCTOR STATISTICS
# ==========================

@doctor_ns.route('/stats')
class DoctorStats(Resource):
    """Doctor dashboard statistics"""
    
    @doctor_ns.doc(security='Bearer')
    @doctor_token_required
    def get(self, current_doctor):
        """Get dashboard statistics"""
        try:
            from models.consultation import Consultation
            
            # Get patient counts by status
            patients = DoctorPatient.query.filter_by(doctor_id=current_doctor.id).all()
            
            status_counts = {'good': 0, 'attention': 0, 'critical': 0}
            for p in patients:
                if p.health_status in status_counts:
                    status_counts[p.health_status] += 1
            
            # Get consultation stats
            today = datetime.utcnow().date()
            consultations = Consultation.query.filter_by(doctor_id=current_doctor.id)
            
            pending_count = consultations.filter_by(status='pending').count()
            today_count = consultations.filter(
                db.func.date(Consultation.scheduled_at) == today
            ).count()
            
            return {
                'total_patients': len(patients),
                'patients_by_status': status_counts,
                'total_consultations': current_doctor.total_consultations,
                'pending_requests': pending_count,
                'today_appointments': today_count,
                'rating': current_doctor.rating,
            }, 200
            
        except Exception as e:
            return {'message': f'Failed to fetch stats: {str(e)}'}, 500


# ==========================
# ADMIN DOCTOR MANAGEMENT
# ==========================

@doctor_ns.route('/admin/create')
class AdminDoctorCreate(Resource):
    """Admin-only doctor creation — pre-verified, no strong password requirement."""

    def post(self):
        """Create a doctor directly via admin panel."""
        try:
            data = request.get_json()

            # Validate required fields
            required = ['name', 'email', 'password', 'nhpc_number', 'qualification']
            for field in required:
                if not data.get(field):
                    return {'message': f'{field} is required'}, 400

            if len(data['password']) < 6:
                return {'message': 'Password must be at least 6 characters'}, 400

            # Duplicate checks
            if Doctor.query.filter_by(email=data['email']).first():
                return {'message': 'Email already registered'}, 400

            if Doctor.query.filter_by(nhpc_number=data['nhpc_number']).first():
                return {'message': 'NHPC number already registered'}, 400

            doctor = Doctor(
                name=data['name'],
                email=data['email'],
                password_hash=generate_password_hash(data['password']),
                phone=data.get('phone', ''),
                nhpc_number=data['nhpc_number'],
                qualification=data['qualification'],
                specialization=data.get('specialization', 'Ophthalmology'),
                experience_years=data.get('experience_years', 0),
                working_place=data.get('working_place', ''),
                address=data.get('address', ''),
                is_verified=True,   # Admin-created doctors are pre-verified
                is_active=data.get('is_active', True),
                is_available=data.get('is_available', True),
                force_password_change=True,  # Must change password on first login
            )

            db.session.add(doctor)
            db.session.commit()

            formatted_id = f"DOC-{doctor.id:03d}"

            return {
                'message': 'Doctor created successfully',
                'doctor_id': doctor.id,
                'formatted_id': formatted_id,
                'doctor': doctor.to_dict(),
            }, 201

        except Exception as e:
            db.session.rollback()
            return {'message': f'Creation failed: {str(e)}'}, 500


@doctor_ns.route('/admin/<int:doctor_id>')
class AdminDoctorManage(Resource):
    """Admin doctor update & delete."""

    def put(self, doctor_id):
        """Admin update a doctor profile."""
        try:
            data = request.get_json()
            doctor = db.session.get(Doctor, doctor_id)
            if not doctor:
                return {'message': 'Doctor not found'}, 404

            if data.get('name'):             doctor.name = data['name']
            if data.get('phone') is not None: doctor.phone = data['phone']
            if data.get('specialization'):   doctor.specialization = data['specialization']
            if data.get('nhpc_number'):      doctor.nhpc_number = data['nhpc_number']
            if data.get('qualification'):    doctor.qualification = data['qualification']
            if data.get('experience_years') is not None:
                doctor.experience_years = data['experience_years']
            if data.get('working_place') is not None: doctor.working_place = data['working_place']
            if data.get('address') is not None:       doctor.address = data['address']
            if 'is_active' in data:    doctor.is_active = data['is_active']
            if 'is_available' in data: doctor.is_available = data['is_available']
            if 'is_verified' in data:  doctor.is_verified = data['is_verified']
            if data.get('password') and len(data['password']) >= 6:
                doctor.password_hash = generate_password_hash(data['password'])

            db.session.commit()

            return {
                'message': 'Doctor updated successfully',
                'formatted_id': f"DOC-{doctor.id:03d}",
                'doctor': doctor.to_dict(),
            }, 200

        except Exception as e:
            db.session.rollback()
            return {'message': f'Update failed: {str(e)}'}, 500

    def delete(self, doctor_id):
        """Admin delete a doctor."""
        try:
            doctor = db.session.get(Doctor, doctor_id)
            if not doctor:
                return {'message': 'Doctor not found'}, 404

            db.session.delete(doctor)
            db.session.commit()

            return {'message': 'Doctor deleted successfully'}, 200

        except Exception as e:
            db.session.rollback()
            return {'message': f'Delete failed: {str(e)}'}, 500

