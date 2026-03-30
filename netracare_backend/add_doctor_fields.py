"""
Migration: Add force_password_change column to doctors table.
Run once: python add_doctor_fields.py
"""
import sqlite3, os

DB_PATH = os.path.join(os.path.dirname(__file__), 'db.sqlite3')

def run():
    con = sqlite3.connect(DB_PATH)
    cur = con.cursor()

    # Check existing columns
    cur.execute("PRAGMA table_info(doctors)")
    cols = {row[1] for row in cur.fetchall()}

    if 'force_password_change' not in cols:
        cur.execute("ALTER TABLE doctors ADD COLUMN force_password_change BOOLEAN DEFAULT 0")
        print("Added: force_password_change")
    else:
        print("Already exists: force_password_change")

    con.commit()
    con.close()
    print("Migration complete.")

if __name__ == '__main__':
    run()
