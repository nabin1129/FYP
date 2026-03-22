"""
Admin Routes - Admin dashboard management API
Handles user listing/editing, doctor listing, and dashboard stats.
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from werkzeug.security import generate_password_hash
from datetime import datetime

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from db_model import db, User
from models.doctor import Doctor

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


# ==========================
# DASHBOARD STATS
# ==========================

@admin_ns.route('/stats')
class AdminStats(Resource):
    def get(self):
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


# ==========================
# USER MANAGEMENT
# ==========================

@admin_ns.route('/users')
class AdminUserList(Resource):
    def get(self):
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
    def get(self, user_id):
        """Get single user details."""
        user = User.query.get(user_id)
        if not user:
            return {'message': 'User not found'}, 404
        return {'user': _user_to_admin_dict(user)}, 200

    @admin_ns.expect(user_update_model)
    def put(self, user_id):
        """Update user details from admin panel."""
        try:
            user = User.query.get(user_id)
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

    def delete(self, user_id):
        """Delete a user from admin panel."""
        try:
            user = User.query.get(user_id)
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
    def get(self):
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
    def get(self, doctor_id):
        """Get single doctor full details."""
        doctor = Doctor.query.get(doctor_id)
        if not doctor:
            return {'message': 'Doctor not found'}, 404
        return {'doctor': _doctor_to_admin_dict(doctor)}, 200


# ==========================
# HELPERS
# ==========================

def _user_to_admin_dict(user: User) -> dict:
    """Convert User model to admin-friendly dict."""
    return {
        'id': user.id,
        'name': user.name or '',
        'email': user.email or '',
        'phone': getattr(user, 'phone', None) or '',
        'age': user.age,
        'sex': user.sex or '',
        'address': getattr(user, 'address', None) or '',
        'created_at': user.created_at.isoformat() if user.created_at else None,
    }


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
