"""Check database schema using sqlite3"""
import sqlite3
import os

db_path = os.path.join(os.path.dirname(__file__), 'db.sqlite3')

print(f"Database path: {db_path}")
print(f"Database exists: {os.path.exists(db_path)}\n")

if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Check if table exists
    cursor.execute("""
        SELECT name FROM sqlite_master 
        WHERE type='table' AND name='colour_vision_tests'
    """)
    table_exists = cursor.fetchone()
    
    if table_exists:
        print("=== COLOUR_VISION_TESTS TABLE SCHEMA ===\n")
        
        # Get table info
        cursor.execute("PRAGMA table_info(colour_vision_tests)")
        columns = cursor.fetchall()
        
        print(f"Total columns: {len(columns)}\n")
        print(f"{'Column Name':<20} {'Type':<15} {'Not Null':<10} {'Default'}")
        print("-" * 70)
        
        for col in columns:
            cid, name, col_type, notnull, default_val, pk = col
            not_null_str = "NOT NULL" if notnull else "NULL"
            default_str = str(default_val) if default_val is not None else "None"
            print(f"{name:<20} {col_type:<15} {not_null_str:<10} {default_str}")
        
        # Check if there are any records
        print("\n=== RECORD COUNT ===\n")
        cursor.execute("SELECT COUNT(*) FROM colour_vision_tests")
        count = cursor.fetchone()[0]
        print(f"Total records: {count}")
        
        if count > 0:
            # Get latest record
            print("\n=== LATEST RECORD (checking for NULL values) ===\n")
            cursor.execute("""
                SELECT id, user_id, total_plates, 
                       LENGTH(plate_ids) as plate_ids_len,
                       LENGTH(plate_images) as plate_images_len,
                       LENGTH(user_answers) as user_answers_len,
                       LENGTH(correct_answers) as correct_answers_len,
                       correct_count, score, severity
                FROM colour_vision_tests 
                ORDER BY created_at DESC LIMIT 1
            """)
            record = cursor.fetchone()
            
            col_names = ['id', 'user_id', 'total_plates', 'plate_ids_len', 
                        'plate_images_len', 'user_answers_len', 'correct_answers_len',
                        'correct_count', 'score', 'severity']
            
            for name, value in zip(col_names, record):
                print(f"{name}: {value}")
    else:
        print("Table 'colour_vision_tests' does NOT exist!")
        print("\nAvailable tables:")
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
        tables = cursor.fetchall()
        for table in tables:
            print(f"  - {table[0]}")
    
    conn.close()
else:
    print("Database file not found!")
