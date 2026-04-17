"""
Admin Routes - Admin dashboard management API
Handles user listing/editing, doctor listing, and dashboard stats.
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash
from werkzeug.security import check_password_hash
from datetime import datetime, timedelta
import logging

from db_model import db, User
from db_model import EyeTrackingTest, VisualAcuityTest, ColourVisionTest, BlinkFatigueTest, PupilReflexTest
from models.doctor import Doctor
from core.security import generate_admin_token, admin_token_required
from core.config import BaseConfig

admin_ns = Namespace('admin', description='Admin management operations')

# ==========================
# SWAGGER MODELS
# ==========================

user_update_model = admin_ns.model('AdminUserUpdate', {
    'name': fields.String(description='Full name'),
    'email': fields.String(description='Email'),
    'phone': fields.String(description='Phone'),
    'age': fields.Integer(description='Age'),
    'sex': fields.String(description='Sex'),
    'address': fields.String(description='Address'),
})

admin_login_model = admin_ns.model('AdminLogin', {
    'email': fields.String(required=True, description='Admin email or username'),
    'password': fields.String(required=True, description='Admin password'),
})

analytics_query_model = admin_ns.model('AdminAnalyticsQuery', {
    'days': fields.Integer(description='Lookback window in days (default: 30)')
})


@admin_ns.route('/login')
class AdminLogin(Resource):
    @admin_ns.expect(admin_login_model)
    def post(self):
        """Authenticate admin and issue admin JWT."""
        try:
            data = request.get_json() or {}
            email = (data.get('email') or '').strip()
            password = data.get('password') or ''

            logging.info('[ADMIN] Login attempt received for email=%s', email or '<empty>')

            if not email or not password:
                logging.warning('[ADMIN] Login rejected: missing email or password')
                return {'message': 'Email and password are required'}, 400

            if email != BaseConfig.ADMIN_EMAIL:
                logging.warning('[ADMIN] Login rejected: invalid admin email=%s', email)
                return {'message': 'Invalid admin credentials'}, 401

            is_valid = False
            if BaseConfig.ADMIN_PASSWORD.startswith('pbkdf2:'):
                is_valid = check_password_hash(BaseConfig.ADMIN_PASSWORD, password)
            else:
                is_valid = password == BaseConfig.ADMIN_PASSWORD

            if not is_valid:
                logging.warning('[ADMIN] Login rejected: invalid password for email=%s', email)
                return {'message': 'Invalid admin credentials'}, 401

            token = generate_admin_token(BaseConfig.ADMIN_EMAIL)
            logging.info('[ADMIN] Login successful for email=%s', BaseConfig.ADMIN_EMAIL)
            return {
                'message': 'Admin login successful',
                'token': token,
                'admin': {
                    'email': BaseConfig.ADMIN_EMAIL,
                    'role': 'admin',
                }
            }, 200
        except Exception as e:
            logging.error('[ADMIN] Login failed with exception: %s', str(e))
            return {'message': f'Admin login failed: {str(e)}'}, 500


# ==========================
# DASHBOARD STATS
# ==========================

@admin_ns.route('/stats')
class AdminStats(Resource):
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin=None):
        """Get admin dashboard statistics."""
        try:
            total_users = User.query.count()
            total_doctors = Doctor.query.count()
            active_doctors = Doctor.query.filter_by(is_active=True).count()

            return {
                'total_users': total_users,
                'total_doctors': total_doctors,
                'active_doctors': active_doctors,
                'active_users': total_users,  # all registered users are active
            }, 200
        except Exception as e:
            return {'message': f'Failed to fetch stats: {str(e)}'}, 500


@admin_ns.route('/analytics/overview')
class AdminAnalyticsOverview(Resource):
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin=None):
        """Get protected admin analytics: usage, demographics, and condition indicators."""
        try:
            days = request.args.get('days', default=30, type=int)
            if days <= 0:
                return {'message': 'days must be greater than 0'}, 400

            cutoff = datetime.utcnow() - timedelta(days=days)

            total_users = User.query.count()
            demographics = {
                'sex': {
                    'male': User.query.filter(User.sex.ilike('male')).count(),
                    'female': User.query.filter(User.sex.ilike('female')).count(),
                    'other_or_unspecified': User.query.filter(
                        (User.sex.is_(None)) |
                        (~User.sex.ilike('male') & ~User.sex.ilike('female'))
                    ).count(),
                },
                'age_buckets': {
                    'under_18': User.query.filter(User.age.isnot(None), User.age < 18).count(),
                    '18_to_29': User.query.filter(User.age >= 18, User.age <= 29).count(),
                    '30_to_44': User.query.filter(User.age >= 30, User.age <= 44).count(),
                    '45_to_59': User.query.filter(User.age >= 45, User.age <= 59).count(),
                    '60_plus': User.query.filter(User.age >= 60).count(),
                    'unknown': User.query.filter(User.age.is_(None)).count(),
                }
            }

            usage = {
                'window_days': days,
                'eye_tracking_tests': EyeTrackingTest.query.filter(EyeTrackingTest.created_at >= cutoff).count(),
                'visual_acuity_tests': VisualAcuityTest.query.filter(VisualAcuityTest.created_at >= cutoff).count(),
                'colour_vision_tests': ColourVisionTest.query.filter(ColourVisionTest.created_at >= cutoff).count(),
                'blink_fatigue_tests': BlinkFatigueTest.query.filter(BlinkFatigueTest.created_at >= cutoff).count(),
                'pupil_reflex_tests': PupilReflexTest.query.filter(PupilReflexTest.created_at >= cutoff).count(),
            }

            condition_signals = {
                'colour_vision_deficiency_indications': ColourVisionTest.query.filter(
                    ColourVisionTest.created_at >= cutoff,
                    ColourVisionTest.severity.ilike('%deficiency%')
                ).count(),
                'high_fatigue_indications': BlinkFatigueTest.query.filter(
                    BlinkFatigueTest.created_at >= cutoff,
                    BlinkFatigueTest.prediction == 'drowsy'
                ).count(),
                'nystagmus_indications': PupilReflexTest.query.filter(
                    PupilReflexTest.created_at >= cutoff,
                    PupilReflexTest.nystagmus_detected.is_(True)
                ).count(),
            }

            return {
                'total_users': total_users,
                'demographics': demographics,
                'usage': usage,
                'condition_signals': condition_signals,
            }, 200
        except Exception as e:
            return {'message': f'Failed to fetch analytics overview: {str(e)}'}, 500


# ==========================
# USER MANAGEMENT
# ==========================

@admin_ns.route('/users')
class AdminUserList(Resource):
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin=None):
        """List all registered users."""
        try:
            users = User.query.order_by(User.created_at.desc()).all()
            return {
                'users': [_user_to_admin_dict(u) for u in users],
                'total': len(users),
            }, 200
        except Exception as e:
            return {'message': f'Failed to fetch users: {str(e)}'}, 500


@admin_ns.route('/users/<int:user_id>')
class AdminUserDetail(Resource):
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin, user_id):
        """Get single user details."""
        user = db.session.get(User, user_id)
        if not user:
            return {'message': 'User not found'}, 404
        return {'user': _user_to_admin_dict(user, include_history=True)}, 200

    @admin_ns.expect(user_update_model)
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def put(self, current_admin, user_id):
        """Update user details from admin panel."""
        try:
            user = db.session.get(User, user_id)
            if not user:
                return {'message': 'User not found'}, 404

            data = request.get_json()
            updatable = ['name', 'phone', 'age', 'sex', 'address']
            for field in updatable:
                if field in data and data[field] is not None:
                    setattr(user, field, data[field])

            # Email change with uniqueness check
            if 'email' in data and data['email'] and data['email'] != user.email:
                if User.query.filter(User.email == data['email'], User.id != user_id).first():
                    return {'message': 'Email already in use by another user'}, 400
                user.email = data['email']

            db.session.commit()
            return {
                'message': 'User updated successfully',
                'user': _user_to_admin_dict(user),
            }, 200
        except Exception as e:
            db.session.rollback()
            return {'message': f'Update failed: {str(e)}'}, 500

    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def delete(self, current_admin, user_id):
        """Delete a user from admin panel."""
        try:
            user = db.session.get(User, user_id)
            if not user:
                return {'message': 'User not found'}, 404
            db.session.delete(user)
            db.session.commit()
            return {'message': 'User deleted successfully'}, 200
        except Exception as e:
            db.session.rollback()
            return {'message': f'Delete failed: {str(e)}'}, 500


# ==========================
# DOCTOR MANAGEMENT (admin listing with full detail)
# ==========================

@admin_ns.route('/doctors')
class AdminDoctorList(Resource):
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin=None):
        """List all doctors with admin-level details."""
        try:
            doctors = Doctor.query.order_by(Doctor.created_at.desc()).all()
            return {
                'doctors': [_doctor_to_admin_dict(d) for d in doctors],
                'total': len(doctors),
            }, 200
        except Exception as e:
            return {'message': f'Failed to fetch doctors: {str(e)}'}, 500


@admin_ns.route('/doctors/<int:doctor_id>')
class AdminDoctorDetail(Resource):
    @admin_ns.doc(security='Bearer')
    @admin_token_required
    def get(self, current_admin, doctor_id):
        """Get single doctor full details."""
        doctor = db.session.get(Doctor, doctor_id)
        if not doctor:
            return {'message': 'Doctor not found'}, 404
        return {'doctor': _doctor_to_admin_dict(doctor)}, 200


# ==========================
# HELPERS
# ==========================

def _user_to_admin_dict(user: User, include_history: bool = False) -> dict:
    """Convert User model to admin-friendly dict."""
    latest_eye = EyeTrackingTest.query.filter_by(user_id=user.id).order_by(EyeTrackingTest.created_at.desc()).first()
    latest_visual = VisualAcuityTest.query.filter_by(user_id=user.id).order_by(VisualAcuityTest.created_at.desc()).first()
    latest_colour = ColourVisionTest.query.filter_by(user_id=user.id).order_by(ColourVisionTest.created_at.desc()).first()
    latest_blink = BlinkFatigueTest.query.filter_by(user_id=user.id).order_by(BlinkFatigueTest.created_at.desc()).first()
    latest_pupil = PupilReflexTest.query.filter_by(user_id=user.id).order_by(PupilReflexTest.created_at.desc()).first()

    eye_count = EyeTrackingTest.query.filter_by(user_id=user.id).count()
    visual_count = VisualAcuityTest.query.filter_by(user_id=user.id).count()
    colour_count = ColourVisionTest.query.filter_by(user_id=user.id).count()
    blink_count = BlinkFatigueTest.query.filter_by(user_id=user.id).count()
    pupil_count = PupilReflexTest.query.filter_by(user_id=user.id).count()

    latest_dates = [
        t.created_at for t in [latest_eye, latest_visual, latest_colour, latest_blink, latest_pupil]
        if t and t.created_at
    ]
    last_test_at = max(latest_dates).isoformat() if latest_dates else None

    response = {
        'id': user.id,
        'name': user.name or '',
        'email': user.email or '',
        'phone': getattr(user, 'phone', None) or '',
        'age': user.age,
        'sex': user.sex or '',
        'address': getattr(user, 'address', None) or '',
        'created_at': user.created_at.isoformat() if user.created_at else None,
        'test_summary': {
            'total_tests': eye_count + visual_count + colour_count + blink_count + pupil_count,
            'eye_tracking_count': eye_count,
            'visual_acuity_count': visual_count,
            'colour_vision_count': colour_count,
            'blink_fatigue_count': blink_count,
            'pupil_reflex_count': pupil_count,
            'last_test_at': last_test_at,
        },
        'recent_tests': {
            'eye_tracking': {
                'created_at': latest_eye.created_at.isoformat() if latest_eye and latest_eye.created_at else None,
                'gaze_accuracy': latest_eye.gaze_accuracy if latest_eye else None,
                'classification': latest_eye.performance_classification if latest_eye else None,
                'duration': latest_eye.test_duration if latest_eye else None,
                'fixation_stability': latest_eye.fixation_stability_score if latest_eye else None,
                'saccade_consistency': latest_eye.saccade_consistency_score if latest_eye else None,
            },
            'visual_acuity': {
                'created_at': latest_visual.created_at.isoformat() if latest_visual and latest_visual.created_at else None,
                'snellen': latest_visual.snellen_value if latest_visual else None,
                'severity': latest_visual.severity if latest_visual else None,
                'score': round((latest_visual.correct_answers / latest_visual.total_questions) * 100) if latest_visual and latest_visual.total_questions else None,
                'correct': latest_visual.correct_answers if latest_visual else None,
                'total': latest_visual.total_questions if latest_visual else None,
            },
            'colour_vision': {
                'created_at': latest_colour.created_at.isoformat() if latest_colour and latest_colour.created_at else None,
                'severity': latest_colour.severity if latest_colour else None,
                'score': latest_colour.score if latest_colour else None,
                'correct_count': latest_colour.correct_count if latest_colour else None,
                'total_plates': latest_colour.total_plates if latest_colour else None,
            },
            'blink_fatigue': {
                'created_at': latest_blink.created_at.isoformat() if latest_blink and latest_blink.created_at else None,
                'prediction': latest_blink.prediction if latest_blink else None,
                'fatigue_level': latest_blink.fatigue_level if latest_blink else None,
                'alertness_percentage': round((1 - latest_blink.drowsy_probability) * 100) if latest_blink and latest_blink.drowsy_probability is not None else None,
                'avg_blinks_per_minute': latest_blink.avg_blinks_per_minute if latest_blink else None,
                'total_blinks': latest_blink.total_blinks if latest_blink else None,
                'duration': latest_blink.test_duration if latest_blink else None,
            },
            'pupil_reflex': {
                'created_at': latest_pupil.created_at.isoformat() if latest_pupil and latest_pupil.created_at else None,
                'nystagmus_detected': latest_pupil.nystagmus_detected if latest_pupil else None,
                'nystagmus_severity': latest_pupil.nystagmus_severity if latest_pupil else None,
                'reaction_time': latest_pupil.reaction_time if latest_pupil else None,
                'constriction_amplitude': latest_pupil.constriction_amplitude if latest_pupil else None,
                'symmetry': latest_pupil.symmetry if latest_pupil else None,
            },
        },
    }

    if include_history:
        response['test_history'] = {
            'eye_tracking': [
                t.to_dict() for t in EyeTrackingTest.query.filter_by(user_id=user.id).order_by(EyeTrackingTest.created_at.desc()).all()
            ],
            'visual_acuity': [
                t.to_dict() for t in VisualAcuityTest.query.filter_by(user_id=user.id).order_by(VisualAcuityTest.created_at.desc()).all()
            ],
            'colour_vision': [
                t.to_dict() for t in ColourVisionTest.query.filter_by(user_id=user.id).order_by(ColourVisionTest.created_at.desc()).all()
            ],
            'blink_fatigue': [
                t.to_dict() for t in BlinkFatigueTest.query.filter_by(user_id=user.id).order_by(BlinkFatigueTest.created_at.desc()).all()
            ],
            'pupil_reflex': [
                t.to_dict() for t in PupilReflexTest.query.filter_by(user_id=user.id).order_by(PupilReflexTest.created_at.desc()).all()
            ],
        }

    return response


def _doctor_to_admin_dict(doctor: Doctor) -> dict:
    """Convert Doctor model to admin-friendly dict."""
    return {
        'id': doctor.id,
        'formatted_id': f'DOC-{doctor.id:03d}',
        'name': doctor.name,
        'email': doctor.email,
        'phone': doctor.phone or '',
        'specialization': doctor.specialization or '',
        'nhpc_number': doctor.nhpc_number or '',
        'qualification': doctor.qualification or '',
        'experience_years': doctor.experience_years or 0,
        'working_place': doctor.working_place or '',
        'address': doctor.address or '',
        'is_active': doctor.is_active,
        'is_verified': doctor.is_verified,
        'is_available': doctor.is_available,
        'rating': doctor.rating or 0.0,
        'total_patients': doctor.total_patients or 0,
        'total_consultations': doctor.total_consultations or 0,
        'created_at': doctor.created_at.isoformat() if doctor.created_at else None,
    }

