"""
Seed script to add sample doctors to the database
Run this script to populate the database with verified doctors
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from flask import Flask
from db_model import db
from models.doctor import Doctor
from werkzeug.security import generate_password_hash

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Create minimal Flask app for database operations
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(BASE_DIR, 'db.sqlite3')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)

# Sample doctors for Nepal
SAMPLE_DOCTORS = [
    {
        'name': 'Dr. Rajesh Kumar Shrestha',
        'email': 'dr.rajesh.shrestha@netracare.np',
        'password': 'doctor123',
        'phone': '+977-9841234567',
        'nhpc_number': 'NHPC-12345',
        'qualification': 'MBBS, MD (Ophthalmology)',
        'specialization': 'Ophthalmology',
        'experience_years': 15,
        'working_place': 'Tilganga Institute of Ophthalmology',
        'address': 'Gaushala, Kathmandu',
        'rating': 4.8,
        'is_available': True,
        'is_verified': True,
        'is_active': True,
    },
    {
        'name': 'Dr. Srijana Poudel',
        'email': 'dr.srijana.poudel@netracare.np',
        'password': 'doctor123',
        'phone': '+977-9851234568',
        'nhpc_number': 'NHPC-23456',
        'qualification': 'MBBS, MS (Ophthalmology)',
        'specialization': 'Ophthalmology',
        'experience_years': 12,
        'working_place': 'Nepal Eye Hospital',
        'address': 'Tripureshwor, Kathmandu',
        'rating': 4.9,
        'is_available': True,
        'is_verified': True,
        'is_active': True,
    },
    {
        'name': 'Dr. Bikash Thapa',
        'email': 'dr.bikash.thapa@netracare.np',
        'password': 'doctor123',
        'phone': '+977-9861234569',
        'nhpc_number': 'NHPC-34567',
        'qualification': 'MBBS, MD (Ophthalmology)',
        'specialization': 'Retinal Surgery',
        'experience_years': 10,
        'working_place': 'Lumbini Eye Institute',
        'address': 'Bhairahawa, Rupandehi',
        'rating': 4.7,
        'is_available': True,
        'is_verified': True,
        'is_active': True,
    },
    {
        'name': 'Dr. Anita Gurung',
        'email': 'dr.anita.gurung@netracare.np',
        'password': 'doctor123',
        'phone': '+977-9841234570',
        'nhpc_number': 'NHPC-45678',
        'qualification': 'MBBS, MS (Ophthalmology)',
        'specialization': 'Pediatric Ophthalmology',
        'experience_years': 8,
        'working_place': 'B.P. Koirala Lions Centre',
        'address': 'Maharajgunj, Kathmandu',
        'rating': 4.6,
        'is_available': True,
        'is_verified': True,
        'is_active': True,
    },
    {
        'name': 'Dr. Prakash Karki',
        'email': 'dr.prakash.karki@netracare.np',
        'password': 'doctor123',
        'phone': '+977-9801234571',
        'nhpc_number': 'NHPC-56789',
        'qualification': 'MBBS, MD (Ophthalmology), Fellowship',
        'specialization': 'Glaucoma Specialist',
        'experience_years': 18,
        'working_place': 'TU Teaching Hospital',
        'address': 'Maharajgunj, Kathmandu',
        'rating': 4.9,
        'is_available': True,
        'is_verified': True,
        'is_active': True,
    },
]


def seed_doctors():
    """Add sample doctors to the database"""
    with app.app_context():
        added_count = 0
        updated_count = 0
        
        for doctor_data in SAMPLE_DOCTORS:
            # Check if doctor already exists
            existing = Doctor.query.filter_by(email=doctor_data['email']).first()
            
            if existing:
                # Update existing doctor to ensure they are available
                existing.is_available = True
                existing.is_verified = True
                existing.is_active = True
                updated_count += 1
                print(f"Updated: {doctor_data['name']}")
            else:
                # Create new doctor
                password = doctor_data.pop('password')
                doctor = Doctor(
                    **doctor_data,
                    password_hash=generate_password_hash(password)
                )
                db.session.add(doctor)
                added_count += 1
                print(f"Added: {doctor_data['name']}")
        
        db.session.commit()
        print(f"\n✅ Seeding complete: {added_count} added, {updated_count} updated")
        
        # List all available doctors
        available_doctors = Doctor.query.filter_by(
            is_active=True, 
            is_verified=True, 
            is_available=True
        ).all()
        
        print(f"\n📋 Total available doctors: {len(available_doctors)}")
        for doc in available_doctors:
            print(f"  - {doc.name} ({doc.specialization}) - {doc.working_place}")


if __name__ == '__main__':
    seed_doctors()
