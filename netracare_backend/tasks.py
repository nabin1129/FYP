"""Celery tasks for NetraCare backend - scheduled jobs and async operations"""

from celery import Celery, Task
from celery.schedules import crontab
from datetime import datetime, timedelta
from db_model import db, User
from models.notification import Notification

# Initialize Celery app
celery_app = Celery(__name__)

# Configure Celery
celery_app.conf.update(
    broker_url="redis://localhost:6379/0",
    result_backend="redis://localhost:6379/0",
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
)

# Configure periodic tasks (scheduled jobs)
celery_app.conf.beat_schedule = {
    "send-screening-reminders-daily": {
        "task": "tasks.send_screening_reminders_task",
        "schedule": crontab(hour=9, minute=0),  # Daily at 9 AM UTC
    },
}


class ContextTask(Task):
    """Make celery tasks work with Flask app context"""

    def __call__(self, *args, **kwargs):
        from backend_app.factory import create_app

        app = create_app()
        with app.app_context():
            return self.run(*args, **kwargs)


celery_app.Task = ContextTask


@celery_app.task
def send_screening_reminders_task():
    """Send screening reminder notifications to all users.

    Scheduled to run daily at 9 AM UTC.
    Creates a notification for each user reminding them to complete screening.
    """
    try:
        users = User.query.all()
        created_count = 0

        for user in users:
            # Calculate next screening date (30 days from now)
            next_screening = datetime.utcnow() + timedelta(days=30)
            next_date_str = next_screening.strftime("%B %d, %Y")

            # Create screening reminder notification
            notif = Notification.create_screening_reminder(user.id, next_date_str)
            db.session.add(notif)
            created_count += 1

        db.session.commit()
        return {
            "status": "success",
            "message": f"Screening reminders sent to {created_count} users",
            "count": created_count,
            "timestamp": datetime.utcnow().isoformat(),
        }
    except Exception as e:
        db.session.rollback()
        return {
            "status": "error",
            "message": f"Failed to send screening reminders: {str(e)}",
            "timestamp": datetime.utcnow().isoformat(),
        }


@celery_app.task
def send_screening_reminders_to_group(user_ids: list):
    """Send screening reminders to a specific group of users.

    Used by admin endpoint for manual campaign triggering.

    Args:
        user_ids: List of user IDs to send reminders to
    """
    try:
        created_count = 0

        for user_id in user_ids:
            user = User.query.get(user_id)
            if not user:
                continue

            next_screening = datetime.utcnow() + timedelta(days=30)
            next_date_str = next_screening.strftime("%B %d, %Y")

            notif = Notification.create_screening_reminder(user.id, next_date_str)
            db.session.add(notif)
            created_count += 1

        db.session.commit()
        return {
            "status": "success",
            "message": f"Screening reminders sent to {created_count} users",
            "count": created_count,
            "timestamp": datetime.utcnow().isoformat(),
        }
    except Exception as e:
        db.session.rollback()
        return {
            "status": "error",
            "message": f"Failed to send reminders: {str(e)}",
            "timestamp": datetime.utcnow().isoformat(),
        }
