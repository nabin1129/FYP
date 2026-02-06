"""
Verification Script - Check Blink Fatigue Implementation
Run this to verify all components are properly set up
"""

import os
import sys
from pathlib import Path

def print_header(text):
    """Print formatted header"""
    print("\n" + "=" * 60)
    print(f"  {text}")
    print("=" * 60)

def print_success(text):
    """Print success message"""
    print(f"✅ {text}")

def print_error(text):
    """Print error message"""
    print(f"❌ {text}")

def print_info(text):
    """Print info message"""
    print(f"ℹ️  {text}")

def check_dataset():
    """Verify dataset exists and has images"""
    print_header("Checking Dataset")
    
    dataset_path = r"D:\3rd_Year\Dataset\train_data"
    
    if not os.path.exists(dataset_path):
        print_error(f"Dataset not found at {dataset_path}")
        return False
    
    print_success(f"Dataset directory found")
    
    # Check drowsy folder
    drowsy_path = os.path.join(dataset_path, 'drowsy')
    if os.path.exists(drowsy_path):
        drowsy_count = len([f for f in os.listdir(drowsy_path) if f.endswith('.jpg')])
        print_success(f"Drowsy folder: {drowsy_count} images")
    else:
        print_error("Drowsy folder not found")
        return False
    
    # Check notdrowsy folder
    notdrowsy_path = os.path.join(dataset_path, 'notdrowsy')
    if os.path.exists(notdrowsy_path):
        notdrowsy_count = len([f for f in os.listdir(notdrowsy_path) if f.endswith('.jpg')])
        print_success(f"Not drowsy folder: {notdrowsy_count} images")
    else:
        print_error("Not drowsy folder not found")
        return False
    
    total = drowsy_count + notdrowsy_count
    print_info(f"Total training images: {total}")
    
    if total < 100:
        print_error("Insufficient training data (need at least 100 images)")
        return False
    
    return True

def check_dependencies():
    """Check if required Python packages are installed"""
    print_header("Checking Python Dependencies")
    
    required_packages = [
        'flask',
        'flask_restx',
        'flask_cors',
        'flask_sqlalchemy',
        'bcrypt',
        'jwt',
        'cv2',
        'mediapipe',
        'numpy',
        'tensorflow',
        'PIL'
    ]
    
    missing = []
    
    for package in required_packages:
        try:
            __import__(package)
            print_success(f"{package} installed")
        except ImportError:
            print_error(f"{package} NOT installed")
            missing.append(package)
    
    if missing:
        print_info(f"Install missing packages: pip install {' '.join(missing)}")
        return False
    
    return True

def check_files():
    """Check if all required files exist"""
    print_header("Checking Implementation Files")
    
    base_dir = os.path.dirname(__file__)
    
    required_files = [
        'blink_fatigue_model.py',
        'train_blink_model.py',
        'blink_fatigue_routes.py',
        'db_model.py',
        'app.py',
        'requirements.txt'
    ]
    
    all_exist = True
    
    for filename in required_files:
        filepath = os.path.join(base_dir, filename)
        if os.path.exists(filepath):
            print_success(f"{filename} exists")
        else:
            print_error(f"{filename} NOT found")
            all_exist = False
    
    return all_exist

def check_model():
    """Check if trained model exists"""
    print_header("Checking Trained Model")
    
    base_dir = os.path.dirname(__file__)
    model_path = os.path.join(base_dir, 'models', 'blink_fatigue_model.keras')
    
    if os.path.exists(model_path):
        size_mb = os.path.getsize(model_path) / (1024 * 1024)
        print_success(f"Trained model found ({size_mb:.2f} MB)")
        return True
    else:
        print_error("Trained model NOT found")
        print_info("Run: python train_blink_model.py")
        return False

def check_database():
    """Check if database exists"""
    print_header("Checking Database")
    
    base_dir = os.path.dirname(__file__)
    db_path = os.path.join(base_dir, 'db.sqlite3')
    
    if os.path.exists(db_path):
        size_kb = os.path.getsize(db_path) / 1024
        print_success(f"Database found ({size_kb:.2f} KB)")
        
        # Try to check if BlinkFatigueTest table exists
        try:
            import sqlite3
            conn = sqlite3.connect(db_path)
            cursor = conn.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='blink_fatigue_tests'")
            result = cursor.fetchone()
            conn.close()
            
            if result:
                print_success("BlinkFatigueTest table exists")
                return True
            else:
                print_error("BlinkFatigueTest table NOT found")
                print_info("Run the Flask app to create tables")
                return False
        except Exception as e:
            print_error(f"Could not check tables: {e}")
            return False
    else:
        print_info("Database not created yet (will be created on first run)")
        return True  # Not an error, will be created automatically

def check_frontend():
    """Check frontend files"""
    print_header("Checking Frontend Files")
    
    frontend_base = r"D:\3rd_Year\FYP\netracare\lib"
    
    required_files = [
        'services/blink_fatigue_service.dart',
        'pages/blink_fatigue_cnn_test_page.dart',
        'pages/blink_fatigue_page.dart'
    ]
    
    all_exist = True
    
    for filename in required_files:
        filepath = os.path.join(frontend_base, filename)
        if os.path.exists(filepath):
            print_success(f"{filename} exists")
        else:
            print_error(f"{filename} NOT found")
            all_exist = False
    
    return all_exist

def main():
    """Run all verification checks"""
    print("\n" + "🔍 " + "=" * 56)
    print("  BLINK FATIGUE DETECTION - IMPLEMENTATION VERIFICATION")
    print("=" * 60)
    
    checks = {
        "Dataset": check_dataset(),
        "Python Dependencies": check_dependencies(),
        "Backend Files": check_files(),
        "Trained Model": check_model(),
        "Database": check_database(),
        "Frontend Files": check_frontend()
    }
    
    print_header("Verification Summary")
    
    passed = sum(1 for result in checks.values() if result)
    total = len(checks)
    
    for check_name, result in checks.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {check_name}: {status}")
    
    print(f"\n  Results: {passed}/{total} checks passed")
    
    if passed == total:
        print("\n" + "🎉 " + "=" * 56)
        print("  ALL CHECKS PASSED!")
        print("  Ready to train model and deploy!")
        print("=" * 60)
        print("\nNext steps:")
        print("  1. python train_blink_model.py   # Train the model")
        print("  2. python app.py                 # Start backend server")
        print("  3. flutter run                   # Run Flutter app")
    else:
        print("\n" + "⚠️  " + "=" * 56)
        print("  SOME CHECKS FAILED")
        print("  Fix the issues above before proceeding")
        print("=" * 60)
        sys.exit(1)

if __name__ == "__main__":
    main()
