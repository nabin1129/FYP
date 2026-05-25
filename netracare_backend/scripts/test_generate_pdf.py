"""Integration helper: create test user and request AI PDF report via test client.
Saves output to ./test_ai_report_output.pdf and prints status summary.
"""

import os
import sys
from jinja2 import Template

# Ensure project package imports work when running this script directly
ROOT = os.path.dirname(os.path.dirname(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

# Avoid importing full app factory (it pulls socketio). Instead use template rendering
from routes.ai_report_routes import WEASY_AVAILABLE, generate_pdf_from_report

try:
    from weasyprint import HTML, CSS
except Exception:
    HTML = None
    CSS = None


def main():
    # Build a dummy report payload similar to what _assemble_report would return
    report = {
        "report_id": "R-DUMMY-0001",
        "report_version": 1,
        "user_id": "DUMMY",
        "user_name": "Test User",
        "ai_report_text": "EXECUTIVE SUMMARY:\nAll tests processed.\n\nKEY FINDINGS:\n - Visual acuity: Not Recorded",
        "findings": {
            "visual_acuity": "Not Recorded",
            "colour_vision": "Not Recorded",
            "blink_fatigue": "Not Recorded",
            "pupil_reflex": "Not Recorded",
        },
        "test_counts": {
            "visual_acuity": 0,
            "colour_vision": 0,
            "blink_fatigue": 0,
            "pupil_reflex": 0,
        },
        "report_metadata": {"clinic": "Demo Clinic"},
    }

    # Render the HTML template using Jinja2 (without Flask)
    tpl_path = os.path.join(ROOT, "templates", "report_template.html")
    with open(tpl_path, "r", encoding="utf-8") as fh:
        tpl_text = fh.read()
    template = Template(tpl_text)
    generation_date = "May 24, 2026 12:00 UTC"
    html = template.render(report=report, generation_date=generation_date)

    # Try WeasyPrint if available
    out_path = os.path.join(os.getcwd(), "test_ai_report_output.pdf")
    if WEASY_AVAILABLE and HTML is not None:
        css_path = os.path.join(ROOT, "static", "report_styles.css")
        styles = [CSS(filename=css_path)] if os.path.exists(css_path) else None
        pdf_bytes = HTML(string=html, base_url=ROOT).write_pdf(stylesheets=styles)
        with open(out_path, "wb") as f:
            f.write(pdf_bytes)
        print("PDF saved to", out_path, "(WeasyPrint)")
    else:
        # Fallback to the existing PDF generator using report text
        buf = generate_pdf_from_report(
            type("U", (), {"id": 1, "name": "Test User"}),
            report["ai_report_text"],
            85.0,
            {"visual_acuity": 85},
            generation_date,
        )
        with open(out_path, "wb") as f:
            f.write(buf.getvalue())
        print("PDF saved to", out_path, "(fallback)")


if __name__ == "__main__":
    main()
