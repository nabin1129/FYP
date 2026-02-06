"""Test the API response for colour vision tests"""
from app import app, db
from db_model import ColourVisionTest, User
import json

with app.app_context():
    # Get the latest test
    test = ColourVisionTest.query.order_by(ColourVisionTest.created_at.desc()).first()
    
    if test:
        print("=== API RESPONSE SIMULATION ===\n")
        
        # Simulate what the API returns
        result = test.to_dict()
        
        print("Full to_dict() result:")
        print(json.dumps(result, indent=2, default=str))
        
        print("\n=== SPECIFIC FIELDS ===\n")
        print(f"plate_ids type: {type(result['plate_ids'])}")
        print(f"plate_ids: {result['plate_ids']}")
        print()
        
        print(f"user_answers type: {type(result['user_answers'])}")
        print(f"user_answers: {result['user_answers']}")
        print(f"user_answers length: {len(result['user_answers'])}")
        print()
        
        print(f"correct_answers type: {type(result['correct_answers'])}")  
        print(f"correct_answers: {result['correct_answers']}")
        print(f"correct_answers length: {len(result['correct_answers'])}")
        
    else:
        print("No tests found!")
