"""Check the actual content of the latest colour vision test"""
import sqlite3
import os
import json

db_path = os.path.join(os.path.dirname(__file__), 'db.sqlite3')

conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Get the latest record with full data
cursor.execute("""
    SELECT id, user_id, total_plates, 
           plate_ids, plate_images, user_answers, correct_answers,
           correct_count, score, severity, created_at
    FROM colour_vision_tests 
    ORDER BY created_at DESC LIMIT 1
""")

record = cursor.fetchone()

if record:
    id, user_id, total_plates, plate_ids, plate_images, user_answers, correct_answers, correct_count, score, severity, created_at = record
    
    print("=== LATEST COLOUR VISION TEST ===\n")
    print(f"ID: {id}")
    print(f"User ID: {user_id}")
    print(f"Total Plates: {total_plates}")
    print(f"Correct Count: {correct_count}")
    print(f"Score: {score}%")
    print(f"Severity: {severity}")
    print(f"Created At: {created_at}")
    print()
    
    print("=== RAW DATA ===\n")
    print(f"plate_ids (raw): {plate_ids}")
    print(f"plate_images (raw): {plate_images}")
    print(f"user_answers (raw): {user_answers}")
    print(f"correct_answers (raw): {correct_answers}")
    print()
    
    print("=== PARSED JSON ===\n")
    
    try:
        plate_ids_list = json.loads(plate_ids)
        print(f"plate_ids: {plate_ids_list}")
    except Exception as e:
        print(f"ERROR parsing plate_ids: {e}")
    
    try:
        plate_images_list = json.loads(plate_images)
        print(f"plate_images: {plate_images_list}")
    except Exception as e:
        print(f"ERROR parsing plate_images: {e}")
    
    try:
        user_answers_list = json.loads(user_answers)
        print(f"user_answers: {user_answers_list}")
    except Exception as e:
        print(f"ERROR parsing user_answers: {e}")
    
    try:
        correct_answers_list = json.loads(correct_answers)
        print(f"correct_answers: {correct_answers_list}")
    except Exception as e:
        print(f"ERROR parsing correct_answers: {e}")
    
else:
    print("No records found!")

conn.close()
