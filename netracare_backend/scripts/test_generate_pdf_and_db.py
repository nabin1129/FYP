"""Generate a PDF (fallback or Weasy) and create a ClinicalReport DB record pointing to it.
Usage: run inside the project's venv: python scripts/test_generate_pdf_and_db.py
"""

import os
import sys
import shutil
from jinja2 import Template

ROOT = os.path.dirname(os.path.dirname(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from routes.ai_report_routes import WEASY_AVAILABLE, generate_pdf_from_report

try:
    from weasyprint import HTML, CSS
except Exception:
    HTML = None
    CSS = None

from flask import Flask
from db_model import db, ClinicalReport


def main():
    # render html
    tpl_path = os.path.join(ROOT, "templates", "report_template.html")
    with open(tpl_path, "r", encoding="utf-8") as fh:
        tpl_text = fh.read()
    template = Template(tpl_text)
    report = {
        "report_id": "R-DUMMY-0001",
        "report_version": 1,
        "user_id": "DUMMY",
        "user_name": "Test User",
        "ai_report_text": "EXECUTIVE SUMMARY:\nAll tests processed.\n",
        "findings": {},
        "test_counts": {},
        "report_metadata": {},
    }
    generation_date = "May 24, 2026 12:00 UTC"
    html = template.render(report=report, generation_date=generation_date)

    out_name = f"test_ai_report_output.pdf"
    out_path = os.path.join(os.getcwd(), out_name)

    if WEASY_AVAILABLE and HTML is not None:
        css_path = os.path.join(ROOT, "static", "report_styles.css")
        styles = [CSS(filename=css_path)] if os.path.exists(css_path) else None
        pdf_bytes = HTML(string=html, base_url=ROOT).write_pdf(stylesheets=styles)
        with open(out_path, "wb") as f:
            f.write(pdf_bytes)
        print("PDF saved to", out_path, "(WeasyPrint)")
    else:
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

    # Move file to app uploads and insert DB record using a minimal Flask app
    app = Flask(__name__)
    sqlite_path = os.path.join(ROOT, "db.sqlite3")
    app.config["SQLALCHEMY_DATABASE_URI"] = f"sqlite:///{sqlite_path}"
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    db.init_app(app)

    with app.app_context():
        reports_dir = os.path.join(app.root_path, "uploads", "reports")
        os.makedirs(reports_dir, exist_ok=True)
        dest_name = f"netracare_report_test_{int(os.path.getmtime(out_path))}.pdf"
        dest_path = os.path.join(reports_dir, dest_name)
        shutil.copyfile(out_path, dest_path)

        cr = ClinicalReport(
            patient_id=1,
            ai_summary="Test AI summary",
            status="pending",
            pdf_path=os.path.join("uploads", "reports", dest_name),
        )
        db.session.add(cr)
        db.session.commit()
        print("ClinicalReport created with id", cr.id)
        fetched = ClinicalReport.query.get(cr.id)
        print("Fetched record:", fetched.to_dict())


if __name__ == "__main__":
    main()
