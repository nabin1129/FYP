"""Check database schema for colour_vision_tests table"""
from app import app, db
from sqlalchemy import inspect

with app.app_context():
    inspector = inspect(db.engine)
    
    print("=== COLOUR VISION TESTS TABLE SCHEMA ===\n")
    
    if 'colour_vision_tests' in inspector.get_table_names():
        columns = inspector.get_columns('colour_vision_tests')
        print(f"Total columns: {len(columns)}\n")
        
        for col in columns:
            nullable_str = "NULL" if col['nullable'] else "NOT NULL"
            print(f"{col['name']:20} {str(col['type']):15} {nullable_str}")
    else:
        print("Table 'colour_vision_tests' does not exist!")
        print("\nAvailable tables:")
        for table in inspector.get_table_names():
            print(f"  - {table}")
