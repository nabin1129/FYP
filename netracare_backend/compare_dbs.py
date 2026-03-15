import sqlite3
import os

def inspect_db(db_path, label):
    if not os.path.exists(db_path):
        print(f"\n{label}: FILE NOT FOUND")
        return
    
    size = os.path.getsize(db_path)
    print(f"\n{'='*60}")
    print(f"{label} ({size} bytes)")
    print(f"{'='*60}")
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        
        for t in tables:
            table_name = t[0]
            try:
                cursor.execute(f"SELECT COUNT(*) FROM [{table_name}]")
                count = cursor.fetchone()[0]
                print(f"  {table_name}: {count} rows")
                
                if count > 0 and count <= 20:
                    cursor.execute(f"SELECT * FROM [{table_name}]")
                    cols = [desc[0] for desc in cursor.description]
                    rows = cursor.fetchall()
                    print(f"    Columns: {cols}")
                    for row in rows:
                        # Truncate long values
                        display = []
                        for v in row:
                            s = str(v)
                            if len(s) > 80:
                                s = s[:80] + "..."
                            display.append(s)
                        print(f"    {display}")
            except Exception as e:
                print(f"  {table_name}: ERROR - {e}")
        
        conn.close()
    except Exception as e:
        print(f"  Error opening DB: {e}")

# Current database
inspect_db('db.sqlite3', 'CURRENT DATABASE')

# Recovered backup
inspect_db('db_backup_recovered.sqlite3', 'BACKUP FROM GIT (backup-local branch)')
