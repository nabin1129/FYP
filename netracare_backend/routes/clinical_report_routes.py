"""Clinical report workflow — AI summary + clinician countersignature."""

from datetime import datetime, timezone

from flask import request, send_file, current_app
import os
from flask_restx import Namespace, Resource, fields

from core.audit import audit_log
from core.security import token_required
from db_model import ClinicalReport, db
from models.notification import Notification

clinical_report_ns = Namespace(
    "clinical-reports", description="Clinician review and countersignature workflow"
)

create_model = clinical_report_ns.model(
    "CreateClinicalReport",
    {
        "ai_summary": fields.String(
            required=True, description="AI-generated summary text"
        ),
        "visual_acuity_test_id": fields.Integer(),
        "colour_vision_test_id": fields.Integer(),
        "pupil_reflex_test_id": fields.Integer(),
        "blink_fatigue_test_id": fields.Integer(),
    },
)

review_model = clinical_report_ns.model(
    "ReviewClinicalReport",
    {
        "action": fields.String(
            required=True,
            description="validated or rejected",
            enum=["validated", "rejected"],
        ),
        "clinician_notes": fields.String(description="Optional review notes"),
    },
)


@clinical_report_ns.route("")
class ClinicalReportList(Resource):
    @clinical_report_ns.doc(security="Bearer")
    @clinical_report_ns.expect(create_model)
    @token_required
    @audit_log("create", "clinical_report")
    def post(self, current_user):
        """Create a pending clinical report for the authenticated patient."""
        data = request.get_json() or {}
        ai_summary = (data.get("ai_summary") or "").strip()
        if not ai_summary:
            return {"message": "ai_summary is required"}, 400

        report = ClinicalReport(
            patient_id=current_user.id,
            ai_summary=ai_summary,
            visual_acuity_test_id=data.get("visual_acuity_test_id"),
            colour_vision_test_id=data.get("colour_vision_test_id"),
            pupil_reflex_test_id=data.get("pupil_reflex_test_id"),
            blink_fatigue_test_id=data.get("blink_fatigue_test_id"),
        )
        db.session.add(report)
        db.session.commit()
        return report.to_dict(), 201

    @clinical_report_ns.doc(security="Bearer")
    @token_required
    @audit_log("read", "clinical_report")
    def get(self, current_user):
        """List all clinical reports for the authenticated patient."""
        reports = (
            ClinicalReport.query.filter_by(patient_id=current_user.id)
            .order_by(ClinicalReport.created_at.desc())
            .all()
        )
        return [r.to_dict() for r in reports], 200


@clinical_report_ns.route("/<int:report_id>/download")
class ClinicalReportDownload(Resource):
    @clinical_report_ns.doc(security="Bearer")
    @token_required
    def get(self, current_user, report_id):
        """Download the PDF for a clinical report if available and authorised."""
        report = ClinicalReport.query.get(report_id)
        if not report:
            return {"message": "Report not found"}, 404

        # Allow the patient owner or clinicians/admins
        if report.patient_id != current_user.id and getattr(
            current_user, "role", "user"
        ) not in ("doctor", "admin"):
            return {"message": "Not authorised to download this report"}, 403

        if not report.pdf_path:
            return {"message": "No PDF available for this report"}, 404

        file_path = os.path.join(current_app.root_path, report.pdf_path)
        if not os.path.exists(file_path):
            return {"message": "Stored PDF not found on server"}, 404

        return send_file(
            file_path,
            mimetype="application/pdf",
            as_attachment=True,
            download_name=os.path.basename(file_path),
        )


@clinical_report_ns.route("/<int:report_id>/review")
class ClinicalReportReview(Resource):
    @clinical_report_ns.doc(security="Bearer")
    @clinical_report_ns.expect(review_model)
    @token_required
    @audit_log("review", "clinical_report")
    def patch(self, current_user, report_id):
        """Clinician countersigns (validates or rejects) a pending report.

        Only users with role 'doctor' may call this endpoint.
        """
        if getattr(current_user, "role", "user") not in ("doctor", "admin"):
            return {"message": "Only clinicians may review reports"}, 403

        report = ClinicalReport.query.get(report_id)
        if not report:
            return {"message": "Report not found"}, 404

        if report.status != "pending":
            return {"message": f"Report is already {report.status}"}, 409

        data = request.get_json() or {}
        action = data.get("action", "").strip()
        if action not in ("validated", "rejected"):
            return {"message": "action must be 'validated' or 'rejected'"}, 400

        report.status = action
        report.clinician_id = current_user.id
        report.clinician_notes = data.get("clinician_notes")
        report.reviewed_at = datetime.now(timezone.utc).replace(
            tzinfo=None, microsecond=0
        )
        db.session.commit()

        doctor_name = getattr(current_user, "name", "Your clinician")
        notif = Notification.create_review_complete(
            patient_id=report.patient_id,
            report_id=report.id,
            status=action,
            doctor_name=doctor_name,
        )
        db.session.add(notif)
        db.session.commit()

        return report.to_dict(), 200
