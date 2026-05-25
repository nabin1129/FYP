"""Admin metrics and monitoring endpoints"""

import logging
from flask_restx import Namespace, Resource, fields
from flask import request
from db_model import db, BlinkFatigueTest, EyeTrackingTest, User, VisualAcuityTest
from datetime import datetime, timedelta
from core.security import token_required, admin_token_required
from sqlalchemy import func

# Create namespace
metrics_ns = Namespace("admin/metrics", description="Admin metrics and monitoring")

# API Models
accuracy_model = metrics_ns.model(
    "ModelAccuracy",
    {
        "model": fields.String(description="Model name"),
        "total_tests": fields.Integer(description="Total tests in period"),
        "false_positives": fields.Integer(description="False positive count"),
        "false_negatives": fields.Integer(description="False negative count"),
        "accuracy_percentage": fields.Float(description="Accuracy percentage"),
        "period_days": fields.Integer(description="Period in days"),
        "start_date": fields.String(description="Period start date"),
        "end_date": fields.String(description="Period end date"),
        "timestamp": fields.String(description="Query timestamp"),
    },
)

test_stats_model = metrics_ns.model(
    "TestStats",
    {
        "total_users": fields.Integer(description="Total users"),
        "active_users_7d": fields.Integer(description="Active users in last 7 days"),
        "active_users_30d": fields.Integer(description="Active users in last 30 days"),
        "tests_completed_7d": fields.Integer(
            description="Tests completed in last 7 days"
        ),
        "tests_completed_30d": fields.Integer(
            description="Tests completed in last 30 days"
        ),
        "average_tests_per_user": fields.Float(description="Average tests per user"),
        "timestamp": fields.String(description="Query timestamp"),
    },
)

notification_stats_model = metrics_ns.model(
    "NotificationStats",
    {
        "total_notifications": fields.Integer(description="Total notifications"),
        "unread_count": fields.Integer(description="Unread notifications"),
        "read_percentage": fields.Float(description="Percentage read"),
        "average_read_time_hours": fields.Float(
            description="Average time to read (hours)"
        ),
        "most_common_type": fields.String(description="Most common notification type"),
        "timestamp": fields.String(description="Query timestamp"),
    },
)


@metrics_ns.route("/blink-accuracy")
class BlinkAccuracy(Resource):
    """Get blink/fatigue model accuracy metrics"""

    @metrics_ns.doc(security="Bearer")
    @metrics_ns.marshal_with(accuracy_model)
    @token_required
    def get(self, current_user):
        """Get blink & fatigue model accuracy for specified period

        Query Parameters:
        - period_days: Number of days to look back (default: 7)
        """
        try:
            period_days = request.args.get("period_days", 7, type=int)

            # Calculate date range
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=period_days)

            # Query tests in period
            tests = BlinkFatigueTest.query.filter(
                BlinkFatigueTest.created_at.between(start_date, end_date)
            ).all()

            if not tests:
                return {
                    "model": "Blink & Fatigue CNN",
                    "total_tests": 0,
                    "false_positives": 0,
                    "false_negatives": 0,
                    "accuracy_percentage": 0.0,
                    "period_days": period_days,
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat(),
                    "timestamp": datetime.utcnow().isoformat(),
                }, 200

            # Calculate metrics
            total = len(tests)

            # False positives: predicted drowsy but alert triggered is False
            false_positives = sum(
                1 for t in tests if t.prediction == "drowsy" and not t.alert_triggered
            )

            # False negatives: predicted alert but user reported no issue (approximation)
            false_negatives = sum(
                1 for t in tests if t.prediction == "notdrowsy" and t.alert_triggered
            )

            # Accuracy: (TP + TN) / (TP + TN + FP + FN)
            correct = total - (false_positives + false_negatives)
            accuracy = (correct / total * 100) if total > 0 else 0.0

            return {
                "model": "Blink & Fatigue CNN",
                "total_tests": total,
                "false_positives": false_positives,
                "false_negatives": false_negatives,
                "accuracy_percentage": round(accuracy, 2),
                "period_days": period_days,
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "timestamp": datetime.utcnow().isoformat(),
            }, 200

        except Exception as e:
            logging.error(f"Error calculating blink accuracy: {str(e)}")
            return {"message": f"Error: {str(e)}"}, 500


@metrics_ns.route("/eye-tracking-accuracy")
class EyeTrackingAccuracy(Resource):
    """Get eye tracking model accuracy metrics"""

    @metrics_ns.doc(security="Bearer")
    @metrics_ns.marshal_with(accuracy_model)
    @token_required
    def get(self, current_user):
        """Get eye tracking model performance for specified period

        Query Parameters:
        - period_days: Number of days to look back (default: 7)
        """
        try:
            period_days = request.args.get("period_days", 7, type=int)

            # Calculate date range
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=period_days)

            # Query tests in period
            tests = EyeTrackingTest.query.filter(
                EyeTrackingTest.created_at.between(start_date, end_date)
            ).all()

            if not tests:
                return {
                    "model": "Eye Tracking",
                    "total_tests": 0,
                    "false_positives": 0,
                    "false_negatives": 0,
                    "accuracy_percentage": 0.0,
                    "period_days": period_days,
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat(),
                    "timestamp": datetime.utcnow().isoformat(),
                }, 200

            # Calculate metrics based on gaze accuracy
            total = len(tests)

            # Consider tests with >85% accuracy as "correct"
            high_accuracy_tests = sum(1 for t in tests if t.gaze_accuracy >= 85)

            accuracy = (high_accuracy_tests / total * 100) if total > 0 else 0.0

            return {
                "model": "Eye Tracking",
                "total_tests": total,
                "false_positives": total - high_accuracy_tests,
                "false_negatives": 0,
                "accuracy_percentage": round(accuracy, 2),
                "period_days": period_days,
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat(),
                "timestamp": datetime.utcnow().isoformat(),
            }, 200

        except Exception as e:
            logging.error(f"Error calculating eye tracking accuracy: {str(e)}")
            return {"message": f"Error: {str(e)}"}, 500


@metrics_ns.route("/test-statistics")
class TestStatistics(Resource):
    """Get overall test statistics"""

    @metrics_ns.doc(security="Bearer")
    @metrics_ns.marshal_with(test_stats_model)
    @token_required
    def get(self, current_user):
        """Get test completion statistics"""
        try:
            now = datetime.utcnow()
            week_ago = now - timedelta(days=7)
            month_ago = now - timedelta(days=30)

            # Total users
            total_users = User.query.filter_by(user_type="patient").count()

            # Active users (completed any test)
            active_7d = (
                db.session.query(func.count(func.distinct(BlinkFatigueTest.user_id)))
                .filter(BlinkFatigueTest.created_at >= week_ago)
                .scalar()
                or 0
            )
            active_7d += (
                db.session.query(func.count(func.distinct(EyeTrackingTest.user_id)))
                .filter(EyeTrackingTest.created_at >= week_ago)
                .scalar()
                or 0
            )

            active_30d = (
                db.session.query(func.count(func.distinct(BlinkFatigueTest.user_id)))
                .filter(BlinkFatigueTest.created_at >= month_ago)
                .scalar()
                or 0
            )
            active_30d += (
                db.session.query(func.count(func.distinct(EyeTrackingTest.user_id)))
                .filter(EyeTrackingTest.created_at >= month_ago)
                .scalar()
                or 0
            )

            # Tests completed
            tests_7d = (
                BlinkFatigueTest.query.filter(
                    BlinkFatigueTest.created_at >= week_ago
                ).count()
                + EyeTrackingTest.query.filter(
                    EyeTrackingTest.created_at >= week_ago
                ).count()
            )

            tests_30d = (
                BlinkFatigueTest.query.filter(
                    BlinkFatigueTest.created_at >= month_ago
                ).count()
                + EyeTrackingTest.query.filter(
                    EyeTrackingTest.created_at >= month_ago
                ).count()
            )

            # Average tests per user
            avg_tests_per_user = (tests_30d / total_users) if total_users > 0 else 0.0

            return {
                "total_users": total_users,
                "active_users_7d": active_7d,
                "active_users_30d": active_30d,
                "tests_completed_7d": tests_7d,
                "tests_completed_30d": tests_30d,
                "average_tests_per_user": round(avg_tests_per_user, 2),
                "timestamp": datetime.utcnow().isoformat(),
            }, 200

        except Exception as e:
            logging.error(f"Error calculating test statistics: {str(e)}")
            return {"message": f"Error: {str(e)}"}, 500
