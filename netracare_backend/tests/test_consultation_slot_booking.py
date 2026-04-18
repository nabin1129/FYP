import unittest
from datetime import datetime

from flask import Flask
from sqlalchemy.exc import IntegrityError

from core.extensions import init_extensions
from db_model import db, User
from models.consultation import Consultation, DoctorSlot
from models.doctor import Doctor
from services.consultation_booking_service import (
    get_available_slot_for_booking,
    normalize_consultation_type,
)


class ConsultationSlotBookingTestCase(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.app.config.update(
            TESTING=True,
            SECRET_KEY='test-secret',
            SQLALCHEMY_DATABASE_URI='sqlite:///:memory:',
            SQLALCHEMY_TRACK_MODIFICATIONS=False,
        )
        init_extensions(self.app)

        with self.app.app_context():
            db.create_all()

            user = User(
                name='Patient Slot User',
                email='slot-patient@example.com',
                password_hash='hashed-password',
            )
            doctor = Doctor(
                name='Doctor Slot Owner',
                email='slot-doctor@example.com',
                password_hash='hashed-password',
                nhpc_number='NHPC-SLOT-001',
                qualification='MBBS',
            )
            db.session.add_all([user, doctor])
            db.session.commit()

            self.user_id = user.id
            self.doctor_id = doctor.id

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_duplicate_doctor_slots_are_blocked(self):
        with self.app.app_context():
            slot_start = datetime(2026, 5, 2, 10, 0, 0)

            first_slot = DoctorSlot(
                doctor_id=self.doctor_id,
                slot_start_at=slot_start,
            )
            db.session.add(first_slot)
            db.session.commit()

            duplicate_slot = DoctorSlot(
                doctor_id=self.doctor_id,
                slot_start_at=slot_start,
            )
            db.session.add(duplicate_slot)

            with self.assertRaises(IntegrityError):
                db.session.commit()
            db.session.rollback()

    def test_physical_slot_can_only_be_booked_once(self):
        with self.app.app_context():
            slot = DoctorSlot(
                doctor_id=self.doctor_id,
                slot_start_at=datetime(2026, 5, 2, 11, 0, 0),
                is_active=True,
                is_booked=False,
            )
            db.session.add(slot)
            db.session.commit()

            first_pick = get_available_slot_for_booking(slot.id, self.doctor_id)
            self.assertIsNotNone(first_pick)

            consultation = Consultation(
                doctor_id=self.doctor_id,
                patient_id=self.user_id,
                doctor_slot_id=slot.id,
                consultation_type='physical',
                status='scheduled',
                scheduled_at=slot.slot_start_at,
                reason='Physical slot booking',
            )
            slot.is_booked = True
            db.session.add(consultation)
            db.session.commit()

            second_pick = get_available_slot_for_booking(slot.id, self.doctor_id)
            self.assertIsNone(second_pick)

    def test_consultation_type_normalization_supports_aliases(self):
        self.assertEqual(normalize_consultation_type('in-person'), 'physical')
        self.assertEqual(normalize_consultation_type('CHAT'), 'chat')
        self.assertEqual(normalize_consultation_type('unknown'), 'chat')


if __name__ == '__main__':
    unittest.main()
