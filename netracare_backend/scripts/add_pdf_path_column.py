"""Add `pdf_path` column to existing clinical_reports table in db.sqlite3 if missing."""

import os
import sqlite3

ROOT = os.path.dirname(os.path.dirname(__file__))
db_path = os.path.join(ROOT, "db.sqlite3")

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Check if column exists
cur.execute("PRAGMA table_info(clinical_reports)")
cols = [r[1] for r in cur.fetchall()]
if "pdf_path" in cols:
    print("pdf_path already present in clinical_reports")
else:
    print("Adding pdf_path column to clinical_reports")
    cur.execute("ALTER TABLE clinical_reports ADD COLUMN pdf_path VARCHAR(500)")
    conn.commit()
    print("Done")

conn.close()
