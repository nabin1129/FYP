"""Test PDF generation by calling generate_pdf_from_report directly.
Saves output to ./test_ai_report_direct_output.pdf
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(__file__))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from routes.ai_report_routes import generate_pdf_from_report


class DummyUser:
    def __init__(self, id, name):
        self.id = id
        self.name = name


def main():
    user = DummyUser(1, "Test PDF User")
    report_text = "EXECUTIVE SUMMARY:\nAll supplied tests processed.\n\nKEY FINDINGS:\n - Visual acuity: Not tested"
    overall_score = 85.0
    scores = {"visual_acuity": 90, "colour_vision": 100}
    generation_date = "May 24, 2026 12:00 UTC"

    buf = generate_pdf_from_report(
        user, report_text, overall_score, scores, generation_date
    )
    out_path = os.path.join(os.getcwd(), "test_ai_report_direct_output.pdf")
    with open(out_path, "wb") as f:
        f.write(buf.getvalue())
    print("PDF written to", out_path)


if __name__ == "__main__":
    main()
