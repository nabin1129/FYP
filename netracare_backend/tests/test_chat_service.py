import unittest

from flask import Flask

from core.extensions import init_extensions
from db_model import db, User
from features.chat.auth import ChatActor
from features.chat.service import (
    create_message,
    ensure_user_doctor_pair,
    mark_messages_read,
)
from models.consultation import Consultation, ConsultationMessage
from models.doctor import Doctor
from models.notification import Notification


class ChatServiceTestCase(unittest.TestCase):
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

            self.user = User(
                name='Patient One',
                email='patient@example.com',
                password_hash='hashed-password',
            )
            self.doctor = Doctor(
                name='Doctor One',
                email='doctor@example.com',
                password_hash='hashed-password',
                nhpc_number='NHPC-001',
                qualification='MBBS',
            )
            db.session.add_all([self.user, self.doctor])
            db.session.commit()

            self.user_id = self.user.id
            self.doctor_id = self.doctor.id

            self.consultation = Consultation(
                doctor_id=self.doctor.id,
                patient_id=self.user.id,
                consultation_type='chat',
                status='pending',
                reason='Follow-up eye chat',
            )
            db.session.add(self.consultation)
            db.session.commit()

            self.consultation_id = self.consultation.id

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_create_message_persists_message_and_notification(self):
        with self.app.app_context():
            user = db.session.get(User, self.user_id)
            doctor = db.session.get(Doctor, self.doctor_id)
            consultation = ensure_user_doctor_pair(self.user_id, self.doctor_id)

            actor = ChatActor(
                role='doctor',
                actor_id=doctor.id,
                doctor=doctor,
            )
            message = create_message(actor, consultation, '  Hello from the doctor  ')

            stored = ConsultationMessage.query.filter_by(
                consultation_id=consultation.id,
            ).one()
            notification = Notification.query.one()

            self.assertEqual(consultation.id, self.consultation_id)
            self.assertEqual(message.id, stored.id)
            self.assertEqual(stored.content, 'Hello from the doctor')
            self.assertEqual(stored.sender_type, 'doctor')
            self.assertEqual(notification.recipient_type, 'user')
            self.assertEqual(notification.recipient_id, user.id)
            self.assertEqual(notification.related_id, consultation.id)
            self.assertEqual(notification.notification_type, 'new_message')

    def test_mark_messages_read_updates_only_inbound_messages(self):
        with self.app.app_context():
            user = db.session.get(User, self.user_id)
            doctor = db.session.get(Doctor, self.doctor_id)
            consultation = db.session.get(Consultation, self.consultation_id)

            doctor_message = ConsultationMessage(
                consultation_id=consultation.id,
                sender_type='doctor',
                sender_id=doctor.id,
                message_type='text',
                content='Doctor message',
            )
            patient_message = ConsultationMessage(
                consultation_id=consultation.id,
                sender_type='patient',
                sender_id=user.id,
                message_type='text',
                content='Patient message',
            )
            db.session.add_all([doctor_message, patient_message])
            db.session.commit()

            actor = ChatActor(role='patient', actor_id=user.id, user=user)
            updated_ids = mark_messages_read(
                actor,
                consultation,
                [str(doctor_message.id), str(patient_message.id)],
            )

            db.session.refresh(doctor_message)
            db.session.refresh(patient_message)

            self.assertEqual(updated_ids, [str(doctor_message.id)])
            self.assertTrue(doctor_message.is_read)
            self.assertIsNotNone(doctor_message.read_at)
            self.assertFalse(patient_message.is_read)
            self.assertIsNone(patient_message.read_at)


if __name__ == '__main__':
    unittest.main()