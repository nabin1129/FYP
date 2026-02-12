"""
Quick test to verify blink detection implementation
Tests without requiring dlib installation
"""
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(__file__))

def test_imports():
    """Test that all modules can be imported"""
    print("Testing imports...")
    try:
        from blink_detector import BlinkDetector
        print("✓ BlinkDetector imported successfully")
        
        from blink_detection_routes import blink_detection_ns
        print("✓ Blink detection routes imported successfully")
        
        from app import app
        print("✓ Flask app imported successfully")
        
        return True
    except Exception as e:
        print(f"✗ Import failed: {e}")
        return False

def test_blink_detector_class():
    """Test BlinkDetector class functionality"""
    print("\nTesting BlinkDetector class...")
    try:
        from blink_detector import BlinkDetector
        
        detector = BlinkDetector()
        print(f"✓ BlinkDetector initialized")
        print(f"  - Initial blink count: {detector.get_blink_count()}")
        print(f"  - EAR threshold: {BlinkDetector.EAR_THRESHOLD}")
        print(f"  - Consecutive frames: {BlinkDetector.CONSEC_FRAMES}")
        
        # Test reset
        detector.reset()
        print(f"✓ Reset successful, count: {detector.get_blink_count()}")
        
        return True
    except Exception as e:
        print(f"✗ BlinkDetector test failed: {e}")
        return False

def test_routes_registration():
    """Test that routes are registered"""
    print("\nTesting route registration...")
    try:
        from app import api
        
        namespaces = [ns.name for ns in api.namespaces]
        print(f"Registered namespaces: {namespaces}")
        
        if 'blink-detection' in namespaces:
            print("✓ blink-detection namespace registered")
            return True
        else:
            print("✗ blink-detection namespace NOT registered")
            return False
    except Exception as e:
        print(f"✗ Route registration test failed: {e}")
        return False

def main():
    print("="*60)
    print("Blink Detection Implementation Test")
    print("="*60)
    
    results = []
    
    # Run tests
    results.append(("Imports", test_imports()))
    results.append(("BlinkDetector Class", test_blink_detector_class()))
    results.append(("Route Registration", test_routes_registration()))
    
    # Summary
    print("\n" + "="*60)
    print("Test Summary")
    print("="*60)
    
    for test_name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{status}: {test_name}")
    
    all_passed = all(result[1] for result in results)
    
    print("\n" + "="*60)
    if all_passed:
        print("✓ ALL TESTS PASSED")
        print("\nNext steps:")
        print("1. Install dlib (optional): pip install dlib")
        print("2. Download model: shape_predictor_68_face_landmarks.dat")
        print("3. Restart Flask: python app.py")
        print("4. Test frontend: flutter run")
    else:
        print("✗ SOME TESTS FAILED")
        print("Please check the errors above and fix them.")
    print("="*60)
    
    return 0 if all_passed else 1

if __name__ == '__main__':
    exit(main())
