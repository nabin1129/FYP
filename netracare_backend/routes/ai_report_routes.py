"""
AI Report Generation Routes
Uses Google Generative AI (Gemini) for comprehensive eye health report generation
and ReportLab/FPDF for PDF creation.
"""
import io
import os
import textwrap
from datetime import datetime, timedelta

from flask import request, jsonify, send_file
from flask_restx import Namespace, Resource, fields
from sqlalchemy import desc

from core.security import token_required, admin_token_required
from core.config import BaseConfig
from db_model import (
    db, User, VisualAcuityTest, ColourVisionTest,
    BlinkFatigueTest, PupilReflexTest,
)

# Gemini client setup
try:
    import google.generativeai as genai  # type: ignore[import-not-found]
    genai.configure(api_key=BaseConfig.GEMINI_API_KEY)
    _gemini_model = genai.GenerativeModel("gemini-1.5-flash")
    GEMINI_AVAILABLE = bool(BaseConfig.GEMINI_API_KEY)
except Exception:
    _gemini_model = None
    GEMINI_AVAILABLE = False

# PDF library - prefer reportlab, fall back to fpdf2
try:
    from reportlab.lib.pagesizes import A4  # type: ignore[import-not-found]
    from reportlab.lib.units import cm  # type: ignore[import-not-found]
    from reportlab.lib import colors  # type: ignore[import-not-found]
    from reportlab.platypus import (  # type: ignore[import-not-found]
        SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable,
    )
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle  # type: ignore[import-not-found]
    from reportlab.lib.enums import TA_CENTER, TA_LEFT  # type: ignore[import-not-found]
    PDF_BACKEND = "reportlab"
except ImportError:
    try:
        from fpdf import FPDF  # type: ignore[import-not-found]
        PDF_BACKEND = "fpdf"
    except ImportError:
        PDF_BACKEND = None

# Namespace
ai_report_ns = Namespace(
    "ai-report", description="AI-Powered Comprehensive Eye Health Reports"
)

generate_report_model = ai_report_ns.model("GenerateReport", {
    "time_range_days": fields.Integer(description="Days of history to include (default 30)"),
})


# Score calculators

def calculate_visual_acuity_score(tests):
    if not tests:
        return None, "No visual acuity tests available"
    t = tests[0]
    try:
        if t.snellen_value:
            # snellen_value is like "6/6" or "6/12"
            n, d = t.snellen_value.split("/")
            ratio = (float(n) / float(d)) * 100
            if ratio >= 95:
                finding = "Excellent visual acuity"
            elif ratio >= 80:
                finding = "Good visual acuity with minor impairment"
            elif ratio >= 60:
                finding = "Moderate visual impairment"
            else:
                finding = "Severe visual impairment requiring correction"
            score_pct = round((t.correct_answers / t.total_questions) * 100) if t.total_questions else ratio
            return min(score_pct, 100), finding
    except Exception:
        pass
    if t.total_questions:
        score_pct = round((t.correct_answers / t.total_questions) * 100)
        return score_pct, f"Visual acuity score: {score_pct}% ({t.severity})"
    return 70, "Visual acuity test completed, results inconclusive"


def calculate_colour_vision_score(tests):
    if not tests:
        return None, "No colour vision tests available"
    t = tests[0]
    # severity column: 'Normal', 'Mild', 'Deficiency'
    severity_lower = (t.severity or "").lower()
    if severity_lower == "normal":
        return 100, "Normal colour vision detected"
    severity_scores = {"mild": 85, "moderate": 65, "deficiency": 50, "severe": 40}
    score = severity_scores.get(severity_lower, t.score if t.score else 70)
    finding = f"Colour vision: {t.severity} ({t.correct_count}/{t.total_plates} plates correct)"
    return score, finding


def calculate_blink_fatigue_score(tests):
    if not tests:
        return None, "No blink fatigue tests available"
    t = tests[0]
    # prediction: 'drowsy' or 'notdrowsy'
    is_drowsy = t.prediction == "drowsy"
    alertness_pct = round((1 - t.drowsy_probability) * 100) if t.drowsy_probability is not None else 100
    blink_rate = t.avg_blinks_per_minute if t.avg_blinks_per_minute else 15
    if 15 <= blink_rate <= 20:
        score = 100
    elif 10 <= blink_rate < 15 or 20 < blink_rate <= 25:
        score = 80
    else:
        score = 60
    if is_drowsy:
        penalty = 20 if t.confidence and t.confidence > 0.8 else 10
        score -= penalty
    finding = f"{t.fatigue_level}; alertness {alertness_pct}%"
    return max(score, 0), finding


def calculate_pupil_reflex_score(tests):
    if not tests:
        return None, "No pupil reflex tests available"
    t = tests[0]
    score = 100
    findings = []
    # reaction_time is in seconds
    if t.reaction_time is not None:
        rt_ms = t.reaction_time * 1000
        if rt_ms > 400:
            score -= 20
            findings.append("Delayed pupil response")
        elif rt_ms > 300:
            score -= 10
            findings.append("Slightly delayed pupil response")
        else:
            findings.append("Normal pupil response time")
    # constriction_amplitude: 'Normal', 'Weak', 'Strong'
    if t.constriction_amplitude:
        amp = t.constriction_amplitude.lower()
        if amp == "weak":
            score -= 20
            findings.append("Weak pupil constriction")
        elif amp == "strong":
            score -= 10
            findings.append("Strong pupil constriction")
        else:
            findings.append(f"Pupil constriction: {t.constriction_amplitude}")
    if t.nystagmus_detected:
        penalties = {"mild": 15, "moderate": 25, "severe": 40}
        score -= penalties.get((t.nystagmus_severity or "").lower(), 20)
        findings.append(
            f"{(t.nystagmus_severity or '').title()} {t.nystagmus_type or ''} nystagmus detected"
        )
    else:
        findings.append("No nystagmus detected")
    return max(score, 0), "; ".join(findings) if findings else "Pupil reflex test completed"


def analyze_trends(tests_by_type):
    trends = {}
    if len(tests_by_type.get("visual_acuity", [])) > 1:
        try:
            recent = tests_by_type["visual_acuity"][0].snellen_value
            older = tests_by_type["visual_acuity"][-1].snellen_value
            rs = float(recent.split("/")[0]) / float(recent.split("/")[1])
            os_ = float(older.split("/")[0]) / float(older.split("/")[1])
            if rs > os_ * 1.1:
                trends["visual_acuity"] = "improving"
            elif rs < os_ * 0.9:
                trends["visual_acuity"] = "declining"
            else:
                trends["visual_acuity"] = "stable"
        except Exception:
            trends["visual_acuity"] = "insufficient_data"
    if len(tests_by_type.get("blink_fatigue", [])) > 1:
        recent_fat = sum(1 for t in tests_by_type["blink_fatigue"][:3] if t.prediction == "drowsy")
        older_fat = sum(1 for t in tests_by_type["blink_fatigue"][-3:] if t.prediction == "drowsy")
        if recent_fat > older_fat:
            trends["blink_fatigue"] = "worsening"
        elif recent_fat < older_fat:
            trends["blink_fatigue"] = "improving"
        else:
            trends["blink_fatigue"] = "stable"
    return trends


def _assemble_report(user, time_range_days: int):
    """Shared report assembly for user/admin paths."""
    if time_range_days <= 0:
        raise ValueError("time_range_days must be > 0")

    cutoff_date = datetime.utcnow() - timedelta(days=time_range_days)

    tests_by_type = {
        "visual_acuity": VisualAcuityTest.query.filter(
            VisualAcuityTest.user_id == user.id,
            VisualAcuityTest.created_at >= cutoff_date,
        ).order_by(desc(VisualAcuityTest.created_at)).all(),
        "colour_vision": ColourVisionTest.query.filter(
            ColourVisionTest.user_id == user.id,
            ColourVisionTest.created_at >= cutoff_date,
        ).order_by(desc(ColourVisionTest.created_at)).all(),
        "blink_fatigue": BlinkFatigueTest.query.filter(
            BlinkFatigueTest.user_id == user.id,
            BlinkFatigueTest.created_at >= cutoff_date,
        ).order_by(desc(BlinkFatigueTest.created_at)).all(),
        "pupil_reflex": PupilReflexTest.query.filter(
            PupilReflexTest.user_id == user.id,
            PupilReflexTest.created_at >= cutoff_date,
        ).order_by(desc(PupilReflexTest.created_at)).all(),
    }

    scores, findings = {}, {}
    for fn, key in [
        (calculate_visual_acuity_score, "visual_acuity"),
        (calculate_colour_vision_score, "colour_vision"),
        (calculate_blink_fatigue_score, "blink_fatigue"),
        (calculate_pupil_reflex_score, "pupil_reflex"),
    ]:
        score, finding = fn(tests_by_type[key])
        if score is not None:
            scores[key] = score
            findings[key] = finding

    if not scores:
        raise ValueError("No tests available to generate report")

    overall_score = sum(scores.values()) / len(scores)
    trends = analyze_trends(tests_by_type)
    ai_text = call_gemini_for_report(
        user, scores, findings, trends, tests_by_type, overall_score
    )

    report = {
        "report_id": f"R-{user.id}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
        "user_id": user.id,
        "user_name": user.name or "Patient",
        "generation_date": datetime.utcnow().isoformat(),
        "overall_score": round(overall_score, 2),
        "scores": scores,
        "findings": findings,
        "trends": trends,
        "ai_report_text": ai_text,
        "test_counts": {k: len(v) for k, v in tests_by_type.items()},
        "gemini_used": GEMINI_AVAILABLE,
        "time_range_days": time_range_days,
    }

    return report, ai_text, overall_score, scores


# Gemini report generation

def _build_system_prompt(user, scores, findings, trends, tests_by_type, overall_score):
    test_counts = {k: len(v) for k, v in tests_by_type.items()}

    va_tests = tests_by_type.get("visual_acuity", [])
    cv_tests = tests_by_type.get("colour_vision", [])
    bf_tests = tests_by_type.get("blink_fatigue", [])
    pr_tests = tests_by_type.get("pupil_reflex", [])

    va_detail = ""
    if va_tests:
        t = va_tests[0]
        score_pct = round((t.correct_answers / t.total_questions) * 100) if t.total_questions else 0
        va_detail = (
            f"Snellen: {t.snellen_value or 'N/A'}, "
            f"Correct: {t.correct_answers or 'N/A'}/{t.total_questions or 'N/A'}, "
            f"Score: {score_pct}%, Severity: {t.severity or 'N/A'}"
        )

    cv_detail = ""
    if cv_tests:
        t = cv_tests[0]
        cv_detail = (
            f"Severity: {t.severity or 'N/A'}, "
            f"Correct plates: {t.correct_count or 'N/A'}/{t.total_plates or 'N/A'}, "
            f"Score: {t.score or 'N/A'}%"
        )

    bf_detail = ""
    if bf_tests:
        t = bf_tests[0]
        alertness_pct = round((1 - t.drowsy_probability) * 100) if t.drowsy_probability is not None else 'N/A'
        bf_detail = (
            f"Prediction: {t.prediction or 'N/A'}, "
            f"Fatigue level: {t.fatigue_level or 'N/A'}, "
            f"Alertness: {alertness_pct}%, "
            f"Avg blinks/min: {t.avg_blinks_per_minute or 'N/A'}"
        )

    pr_detail = ""
    if pr_tests:
        t = pr_tests[0]
        pr_detail = (
            f"Reaction time: {round(t.reaction_time * 1000) if t.reaction_time else 'N/A'} ms, "
            f"Constriction: {t.constriction_amplitude or 'N/A'}, "
            f"Nystagmus: {t.nystagmus_detected}, "
            f"Nystagmus severity: {t.nystagmus_severity or 'N/A'}"
        )

    trend_text = "\n".join(
        f"  - {k.replace('_', ' ').title()}: {v}" for k, v in trends.items()
    ) or "  - Insufficient data for trend analysis"

    prompt = f"""You are a professional ophthalmology AI assistant. Generate a comprehensive,
clinically-informative eye health report for a patient based on the data below.

PATIENT INFORMATION:
Name: {user.name or 'Patient'}
Report Date: {datetime.utcnow().strftime('%B %d, %Y')}

TEST SCORES SUMMARY:
Overall Eye Health Score: {overall_score:.1f}/100
Visual Acuity Score: {scores.get('visual_acuity', 'N/A')}
Colour Vision Score: {scores.get('colour_vision', 'N/A')}
Blink & Fatigue Score: {scores.get('blink_fatigue', 'N/A')}
Pupil Reflex Score: {scores.get('pupil_reflex', 'N/A')}

DETAILED TEST DATA:
Visual Acuity - {findings.get('visual_acuity', 'Not tested')}
Latest: {va_detail or 'No data'} | Tests completed: {test_counts.get('visual_acuity', 0)}

Colour Vision - {findings.get('colour_vision', 'Not tested')}
Latest: {cv_detail or 'No data'} | Tests completed: {test_counts.get('colour_vision', 0)}

Blink & Fatigue - {findings.get('blink_fatigue', 'Not tested')}
Latest: {bf_detail or 'No data'} | Tests completed: {test_counts.get('blink_fatigue', 0)}

Pupil Reflex - {findings.get('pupil_reflex', 'Not tested')}
Latest: {pr_detail or 'No data'} | Tests completed: {test_counts.get('pupil_reflex', 0)}

TREND ANALYSIS:
{trend_text}

INSTRUCTIONS:
Generate a structured report with the following sections (use UPPERCASE section names ending with colon):

EXECUTIVE SUMMARY:
CLINICAL ASSESSMENT:
KEY FINDINGS:
RISK ASSESSMENT:
PERSONALIZED RECOMMENDATIONS:
FOLLOW-UP PLAN:
DISCLAIMER:

Be professional but understandable. Do NOT use markdown (no **, ##, *, etc.).
Keep total report under 800 words."""

    return prompt


def call_gemini_for_report(user, scores, findings, trends, tests_by_type, overall_score):
    if not GEMINI_AVAILABLE or _gemini_model is None:
        return _fallback_report(scores, findings, trends, overall_score)
    prompt = _build_system_prompt(user, scores, findings, trends, tests_by_type, overall_score)
    try:
        response = _gemini_model.generate_content(prompt)
        return response.text.strip()
    except Exception as e:
        print(f"Gemini API error: {e}")
        return _fallback_report(scores, findings, trends, overall_score)


def _fallback_report(scores, findings, trends, overall_score):
    lines = [
        "EXECUTIVE SUMMARY:",
        f"Overall eye health score: {overall_score:.1f}/100. "
        + ("All metrics are within normal range." if overall_score >= 80
           else "Some areas require attention; please consult a specialist."),
        "",
        "KEY FINDINGS:",
    ]
    for key, val in findings.items():
        lines.append(f"  - {key.replace('_', ' ').title()}: {val}")
    lines += [
        "",
        "PERSONALIZED RECOMMENDATIONS:",
        "  - Schedule a comprehensive eye exam with an optometrist.",
        "  - Follow the 20-20-20 rule for screen use.",
        "  - Maintain a balanced diet rich in Vitamins A, C, and E.",
        "",
        "DISCLAIMER:",
        "This report is generated from self-assessment tests and is not a substitute "
        "for a professional medical examination.",
    ]
    return "\n".join(lines)


# PDF generation

def generate_pdf_from_report(user, report_text, overall_score, scores, generation_date):
    buffer = io.BytesIO()
    if PDF_BACKEND == "reportlab":
        _generate_pdf_reportlab(buffer, user, report_text, overall_score, scores, generation_date)
    elif PDF_BACKEND == "fpdf":
        _generate_pdf_fpdf(buffer, user, report_text, overall_score, scores, generation_date)
    else:
        buffer.write(report_text.encode("utf-8"))
    buffer.seek(0)
    return buffer


def _generate_pdf_reportlab(buffer, user, report_text, overall_score, scores, generation_date):
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=2 * cm,
        leftMargin=2 * cm,
        topMargin=2 * cm,
        bottomMargin=2 * cm,
    )
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        "ReportTitle",
        parent=styles["Title"],
        fontSize=20,
        textColor=colors.HexColor("#1a56db"),
        spaceAfter=6,
        alignment=TA_CENTER,
    )
    subtitle_style = ParagraphStyle(
        "Subtitle",
        parent=styles["Normal"],
        fontSize=10,
        textColor=colors.grey,
        alignment=TA_CENTER,
        spaceAfter=12,
    )
    section_style = ParagraphStyle(
        "SectionHead",
        parent=styles["Heading2"],
        fontSize=12,
        textColor=colors.HexColor("#1a56db"),
        spaceBefore=14,
        spaceAfter=4,
    )
    body_style = ParagraphStyle(
        "Body",
        parent=styles["Normal"],
        fontSize=10,
        leading=14,
        spaceAfter=6,
    )

    story = []
    story.append(Paragraph("NetraCare Eye Health Report", title_style))
    story.append(Paragraph(
        f"Generated on {generation_date}  |  Patient: {user.name or 'Patient'}",
        subtitle_style,
    ))
    story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor("#1a56db")))
    story.append(Spacer(1, 0.4 * cm))

    # Scores table
    score_data = [["Test Area", "Score"]]
    for key, val in scores.items():
        label = key.replace("_", " ").title()
        score_data.append([label, f"{val:.1f}/100" if isinstance(val, (int, float)) else str(val)])
    score_data.append(["OVERALL", f"{overall_score:.1f}/100"])

    tbl = Table(score_data, colWidths=[10 * cm, 5 * cm])
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1a56db")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ("FONTSIZE", (0, 0), (-1, 0), 11),
        ("ROWBACKGROUNDS", (0, 1), (-1, -2), [colors.white, colors.HexColor("#f0f4ff")]),
        ("BACKGROUND", (0, -1), (-1, -1), colors.HexColor("#e8f0fe")),
        ("FONTNAME", (0, -1), (-1, -1), "Helvetica-Bold"),
        ("ALIGN", (1, 0), (1, -1), "CENTER"),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#c7d2fe")),
        ("TOPPADDING", (0, 0), (-1, -1), 6),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
    ]))
    story.append(tbl)
    story.append(Spacer(1, 0.5 * cm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.lightgrey))
    story.append(Spacer(1, 0.3 * cm))

    story.append(Paragraph("AI-Generated Clinical Report", section_style))
    for line in report_text.splitlines():
        stripped = line.strip()
        if not stripped:
            story.append(Spacer(1, 0.2 * cm))
        elif stripped.endswith(":") and stripped == stripped.upper():
            story.append(Paragraph(stripped, section_style))
        else:
            story.append(Paragraph(stripped, body_style))

    story.append(Spacer(1, 0.5 * cm))
    story.append(HRFlowable(width="100%", thickness=0.5, color=colors.lightgrey))
    story.append(Spacer(1, 0.2 * cm))
    story.append(Paragraph(
        "This report is generated by NetraCare AI and is not a substitute for professional medical advice.",
        ParagraphStyle("Footer", parent=styles["Normal"], fontSize=8, textColor=colors.grey, alignment=TA_CENTER),
    ))
    doc.build(story)


def _generate_pdf_fpdf(buffer, user, report_text, overall_score, scores, generation_date):
    pdf = FPDF()
    pdf.add_page()
    pdf.set_margins(20, 20, 20)
    pdf.set_font("Helvetica", "B", 18)
    pdf.set_text_color(26, 86, 219)
    pdf.cell(0, 10, "NetraCare Eye Health Report", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(128, 128, 128)
    pdf.cell(0, 6, f"Generated: {generation_date}  |  Patient: {user.name or 'Patient'}", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(0, 0, 0)
    pdf.cell(0, 8, f"Overall Score: {overall_score:.1f}/100", new_x="LMARGIN", new_y="NEXT")
    for key, val in scores.items():
        pdf.set_font("Helvetica", "", 10)
        label = key.replace("_", " ").title()
        display = f"{val:.1f}/100" if isinstance(val, (int, float)) else str(val)
        pdf.cell(0, 7, f"  {label}: {display}", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(0, 0, 0)
    for line in report_text.splitlines():
        stripped = line.strip()
        if not stripped:
            pdf.ln(3)
        elif stripped.endswith(":") and stripped == stripped.upper():
            pdf.set_font("Helvetica", "B", 11)
            pdf.set_text_color(26, 86, 219)
            pdf.multi_cell(0, 7, stripped)
            pdf.set_font("Helvetica", "", 10)
            pdf.set_text_color(0, 0, 0)
        else:
            pdf.multi_cell(0, 6, stripped)
    pdf.output(buffer)


# API Endpoints

@ai_report_ns.route("/generate")
class GenerateReport(Resource):
    @ai_report_ns.doc(security="Bearer")
    @ai_report_ns.expect(generate_report_model)
    @token_required
    def post(self, current_user):
        """Generate a new AI-powered eye health report (returns JSON)."""
        try:
            data = request.get_json() or {}
            time_range_days = data.get("time_range_days", 30)

            report, _, _, _ = _assemble_report(current_user, time_range_days)

            return {"message": "Report generated successfully", "report": report}, 200
        except ValueError as e:
            return {"message": str(e)}, 400
        except Exception as e:
            return {"message": f"Failed to generate report: {str(e)}"}, 500


@ai_report_ns.route("/generate-pdf")
class GenerateReportPDF(Resource):
    @ai_report_ns.doc(security="Bearer")
    @token_required
    def post(self, current_user):
        """Generate AI report and return as a downloadable PDF file."""
        try:
            data = request.get_json() or {}
            time_range_days = data.get("time_range_days", 30)

            _, ai_text, overall_score, scores = _assemble_report(
                current_user, time_range_days
            )

            generation_date = datetime.utcnow().strftime("%B %d, %Y %H:%M UTC")
            pdf_buffer = generate_pdf_from_report(
                current_user, ai_text, overall_score, scores, generation_date
            )

            filename = f"netracare_report_{current_user.id}_{datetime.utcnow().strftime('%Y%m%d')}.pdf"
            mimetype = "application/pdf" if PDF_BACKEND else "text/plain"

            return send_file(
                pdf_buffer,
                mimetype=mimetype,
                as_attachment=True,
                download_name=filename,
            )
        except ValueError as e:
            return {"message": str(e)}, 400
        except Exception as e:
            return {"message": f"Failed to generate PDF: {str(e)}"}, 500


@ai_report_ns.route("/admin/users/<int:user_id>/report")
class AdminUserReport(Resource):
    @ai_report_ns.doc(security="Bearer")
    @admin_token_required
    def get(self, current_admin, user_id):
        """Admin: generate AI report JSON for a specific user."""
        user = db.session.get(User, user_id)
        if not user:
            return {"message": "User not found"}, 404

        try:
            time_range_days = request.args.get("days", default=30, type=int)
            report, _, _, _ = _assemble_report(user, time_range_days)
            return {"message": "Report generated successfully", "report": report}, 200
        except ValueError as e:
            return {"message": str(e)}, 400
        except Exception as e:
            return {"message": f"Failed to generate admin report: {str(e)}"}, 500


@ai_report_ns.route("/admin/users/<int:user_id>/report-pdf")
class AdminUserReportPDF(Resource):
    @ai_report_ns.doc(security="Bearer")
    @admin_token_required
    def get(self, current_admin, user_id):
        """Admin: generate AI report PDF for a specific user."""
        user = db.session.get(User, user_id)
        if not user:
            return {"message": "User not found"}, 404

        try:
            time_range_days = request.args.get("days", default=30, type=int)
            _, ai_text, overall_score, scores = _assemble_report(user, time_range_days)

            generation_date = datetime.utcnow().strftime("%B %d, %Y %H:%M UTC")
            pdf_buffer = generate_pdf_from_report(
                user, ai_text, overall_score, scores, generation_date
            )

            filename = f"netracare_report_{user.id}_{datetime.utcnow().strftime('%Y%m%d')}.pdf"
            mimetype = "application/pdf" if PDF_BACKEND else "text/plain"

            return send_file(
                pdf_buffer,
                mimetype=mimetype,
                as_attachment=True,
                download_name=filename,
            )
        except ValueError as e:
            return {"message": str(e)}, 400
        except Exception as e:
            return {"message": f"Failed to generate admin report PDF: {str(e)}"}, 500


@ai_report_ns.route("/insights")
class GetInsights(Resource):
    @ai_report_ns.doc(security="Bearer")
    @token_required
    def get(self, current_user):
        """Get quick eye health insights."""
        try:
            latest_visual = VisualAcuityTest.query.filter_by(user_id=current_user.id).order_by(desc(VisualAcuityTest.created_at)).first()
            latest_colour = ColourVisionTest.query.filter_by(user_id=current_user.id).order_by(desc(ColourVisionTest.created_at)).first()
            latest_blink = BlinkFatigueTest.query.filter_by(user_id=current_user.id).order_by(desc(BlinkFatigueTest.created_at)).first()
            latest_pupil = PupilReflexTest.query.filter_by(user_id=current_user.id).order_by(desc(PupilReflexTest.created_at)).first()

            insights = []
            if latest_visual:
                score_pct = round((latest_visual.correct_answers / latest_visual.total_questions) * 100) if latest_visual.total_questions else 0
                insights.append({
                    "type": "visual_acuity",
                    "message": f"Last visual acuity test: {latest_visual.snellen_value or 'N/A'} ({score_pct}%)",
                    "date": latest_visual.created_at.isoformat() if latest_visual.created_at else None,
                })
            if latest_colour and (latest_colour.severity or "").lower() != "normal":
                insights.append({
                    "type": "colour_vision",
                    "message": f"Colour vision: {latest_colour.severity} ({latest_colour.correct_count}/{latest_colour.total_plates} plates correct)",
                    "severity": latest_colour.severity,
                    "date": latest_colour.created_at.isoformat() if latest_colour.created_at else None,
                })
            if latest_blink and latest_blink.prediction == "drowsy":
                insights.append({
                    "type": "blink_fatigue",
                    "message": f"{(latest_blink.fatigue_level or 'Drowsy').title()} eye fatigue detected",
                    "date": latest_blink.created_at.isoformat() if latest_blink.created_at else None,
                })
            if latest_pupil and latest_pupil.nystagmus_detected:
                insights.append({
                    "type": "pupil_reflex",
                    "message": f"{latest_pupil.nystagmus_severity.title()} nystagmus detected",
                    "date": latest_pupil.created_at.isoformat() if latest_pupil.created_at else None,
                })

            return {
                "total_insights": len(insights),
                "insights": insights,
                "last_updated": datetime.utcnow().isoformat(),
            }, 200

        except Exception as e:
            return {"message": f"Failed to get insights: {str(e)}"}, 500


# ---------------------------------------------------------------------------
# SEND REPORT TO DOCTOR
# ---------------------------------------------------------------------------

send_to_doctor_model = ai_report_ns.model("SendReportToDoctor", {
    "doctor_id": fields.Integer(required=True, description="Doctor ID to send report to"),
    "time_range_days": fields.Integer(description="Days of history to include (default 30)"),
    "message": fields.String(description="Optional personal message to the doctor"),
})


@ai_report_ns.route("/send-to-doctor")
class SendReportToDoctor(Resource):
    @ai_report_ns.doc(security="Bearer")
    @ai_report_ns.expect(send_to_doctor_model)
    @token_required
    def post(self, current_user):
        """Generate an AI report and send it to a linked doctor via notification."""
        try:
            from models.doctor import Doctor, DoctorPatient
            from models.notification import Notification

            data = request.get_json() or {}
            doctor_id = data.get("doctor_id")
            time_range_days = data.get("time_range_days", 30)
            personal_message = (data.get("message") or "").strip()

            if not doctor_id:
                return {"message": "doctor_id is required"}, 400

            # Verify the doctor exists and is active
            doctor = db.session.get(Doctor, doctor_id)
            if not doctor or not doctor.is_active:
                return {"message": "Doctor not found or inactive"}, 404

            # Generate the report
            try:
                report, ai_text, overall_score, scores = _assemble_report(
                    current_user, time_range_days
                )
            except ValueError as e:
                return {"message": str(e)}, 400

            # Build a compact summary to embed in the notification
            score_lines = ", ".join(
                f"{k.replace('_', ' ').title()}: {v:.0f}/100"
                for k, v in scores.items()
                if isinstance(v, (int, float))
            )
            patient_name = current_user.name or "Patient"
            notif_title = f"Eye Health Report from {patient_name}"
            notif_body = (
                f"{patient_name} has shared their AI-generated eye health report with you.\n"
                f"Overall score: {overall_score:.1f}/100\n"
                f"{score_lines}"
            )
            if personal_message:
                notif_body += f"\n\nMessage: {personal_message}"

            notification = Notification(
                recipient_type="doctor",
                recipient_id=doctor_id,
                notification_type="report_shared",
                title=notif_title,
                message=notif_body,
                related_type="ai_report",
                related_id=current_user.id,
                priority="normal",
            )
            # Store the full report JSON in action_data so the doctor can view it
            notification.set_action_data({
                "report": report,
                "patient_id": current_user.id,
                "patient_name": patient_name,
            })
            db.session.add(notification)
            db.session.commit()

            return {
                "message": f"Report successfully sent to Dr. {doctor.name}",
                "doctor": {
                    "id": doctor.id,
                    "name": doctor.name,
                    "specialization": doctor.specialization,
                },
                "report_summary": {
                    "overall_score": round(overall_score, 2),
                    "scores": scores,
                    "generation_date": report["generation_date"],
                },
            }, 200

        except Exception as e:
            db.session.rollback()
            return {"message": f"Failed to send report: {str(e)}"}, 500


@ai_report_ns.route("/my-doctors")
class MyDoctors(Resource):
    @ai_report_ns.doc(security="Bearer")
    @token_required
    def get(self, current_user):
        """Get list of doctors linked to the current patient."""
        try:
            from models.doctor import Doctor, DoctorPatient

            links = DoctorPatient.query.filter_by(
                patient_id=current_user.id
            ).all()

            doctors = []
            for link in links:
                doc = db.session.get(Doctor, link.doctor_id)
                if doc and doc.is_active:
                    doctors.append({
                        "id": doc.id,
                        "name": doc.name,
                        "specialization": doc.specialization or "Ophthalmology",
                        "working_place": doc.working_place or "",
                        "is_available": doc.is_available,
                    })

            return {"doctors": doctors, "total": len(doctors)}, 200

        except Exception as e:
            return {"message": f"Failed to fetch doctors: {str(e)}"}, 500
