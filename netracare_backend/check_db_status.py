import sqlite3

conn = sqlite3.connect('db.sqlite3')
cursor = conn.cursor()

# List all tables
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tables = cursor.fetchall()
print("=== Tables in database ===")
for t in tables:
    table_name = t[0]
    cursor.execute(f"SELECT COUNT(*) FROM [{table_name}]")
    count = cursor.fetchone()[0]
    print(f"  {table_name}: {count} rows")

# Check users
print("\n=== Users ===")
try:
    cursor.execute("SELECT * FROM users")
    rows = cursor.fetchall()
    cols = [desc[0] for desc in cursor.description]
    print(f"  Columns: {cols}")
    for row in rows:
        print(f"  {row}")
except Exception as e:
    print(f"  Error: {e}")

# Check doctors
print("\n=== Doctors ===")
try:
    cursor.execute("SELECT * FROM doctors")
    rows = cursor.fetchall()
    cols = [desc[0] for desc in cursor.description]
    print(f"  Columns: {cols}")
    for row in rows:
        print(f"  {row}")
except Exception as e:
    print(f"  Error: {e}")

conn.close()
