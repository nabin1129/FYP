"""
Complete Example: Run Eye Tracking and Save to Database
This script demonstrates the full workflow from camera tracking to database storage
"""

import sys
from eye_tracking_opencv import EyeTracker
from app import app
from db_model import db, User, CameraEyeTrackingSession
from eye_tracking_db_helper import save_eye_tracking_session, get_user_sessions
import time


def create_test_user():
    """Create a test user for demonstration"""
    with app.app_context():
        # Check if test user exists
        test_user = User.query.filter_by(email='test@eyetracking.com').first()
        
        if not test_user:
            from werkzeug.security import generate_password_hash
            test_user = User(
                name='Eye Tracking Test User',
                email='test@eyetracking.com',
                password_hash=generate_password_hash('password123'),
                age=25,
                sex='Male'
            )
            db.session.add(test_user)
            db.session.commit()
            print(f"✓ Created test user: {test_user.email}")
        else:
            print(f"✓ Using existing test user: {test_user.email}")
        
        return test_user.id


def run_tracking_and_save(duration=10, user_id=None):
    """
    Run eye tracking session and save to database
    
    Args:
        duration: Tracking duration in seconds
        user_id: User ID to associate with the session
    """
    
    print("\n" + "="*60)
    print(f"RUNNING EYE TRACKING SESSION ({duration} seconds)")
    print("="*60)
    print("\nInstructions:")
    print("  - Look at your camera")
    print("  - Blink naturally")
    print("  - Try moving your eyes in different directions")
    print(f"\nStarting in 3 seconds...")
    
    time.sleep(3)
    
    # Create tracker
    tracker = EyeTracker(camera_id=0)
    
    # Run tracking
    print("\n📹 Tracking started...")
    tracker.run_live_tracking(duration=duration)
    
    # Get statistics
    stats = tracker.get_statistics()
    
    if "error" in stats:
        print("\n❌ No data collected. Make sure your face is visible to the camera.")
        return None
    
    # Display results
    print("\n" + "="*60)
    print("TRACKING RESULTS")
    print("="*60)
    
    print(f"\n⏱️  Duration: {stats['duration_seconds']:.2f} seconds")
    print(f"👁️  Total Blinks: {stats['total_blinks']}")
    print(f"💫 Blink Rate: {stats['blink_rate_per_minute']:.1f} blinks/min")
    
    ear = stats['ear_statistics']['average']
    print(f"\n📈 Average EAR: {ear['mean']:.3f} ± {ear['std']:.3f}")
    
    # Collect blink events
    blink_events = []
    for data in tracker.blink_history:
        if data.is_blinking:
            blink_events.append({
                'timestamp': data.timestamp,
                'ear': data.avg_ear
            })
    
    # Collect gaze events
    gaze_events = []
    for data in tracker.movement_history:
        gaze_events.append({
            'timestamp': data.timestamp,
            'direction': data.gaze_direction,
            'left_x': data.left_gaze_x,
            'left_y': data.left_gaze_y,
            'right_x': data.right_gaze_x,
            'right_y': data.right_gaze_y
        })
    
    # Save to database
    if user_id:
        print("\n💾 Saving to database...")
        
        with app.app_context():
            try:
                session_name = f"Eye Tracking Session - {time.strftime('%Y-%m-%d %H:%M:%S')}"
                notes = f"Tracked for {duration} seconds with {stats['total_blinks']} blinks detected"
                
                session_id = save_eye_tracking_session(
                    user_id=user_id,
                    stats=stats,
                    session_name=session_name,
                    blink_events=blink_events,
                    gaze_events=gaze_events,
                    notes=notes
                )
                
                print(f"✓ Session saved successfully! Session ID: {session_id}")
                
                return session_id
                
            except Exception as e:
                print(f"❌ Error saving to database: {e}")
                return None
    else:
        print("\n⚠️  No user ID provided. Results not saved to database.")
        print("   Run with user_id parameter to save results.")
        return None


def view_saved_sessions(user_id):
    """View all saved sessions for a user"""
    
    print("\n" + "="*60)
    print("SAVED SESSIONS")
    print("="*60)
    
    with app.app_context():
        sessions = get_user_sessions(user_id, limit=10)
        
        if not sessions:
            print("\nNo sessions found.")
            return
        
        print(f"\nFound {len(sessions)} session(s):\n")
        
        for i, session in enumerate(sessions, 1):
            print(f"{i}. {session['session_name']}")
            print(f"   ID: {session['id']}")
            print(f"   Duration: {session['duration_seconds']:.2f}s")
            print(f"   Blinks: {session['blink_metrics']['total_blinks']}")
            print(f"   Blink Rate: {session['blink_metrics']['blink_rate_per_minute']:.1f}/min")
            print(f"   Average EAR: {session['ear_statistics']['average']['mean']:.3f}")
            print(f"   Date: {session['created_at']}")
            print()


def demonstrate_full_workflow():
    """Demonstrate complete workflow"""
    
    print("\n" + "="*60)
    print("COMPLETE EYE TRACKING WORKFLOW")
    print("="*60)
    
    # Initialize database
    print("\n1️⃣  Initializing database...")
    with app.app_context():
        db.create_all()
        print("✓ Database initialized")
    
    # Create test user
    print("\n2️⃣  Setting up test user...")
    user_id = create_test_user()
    
    # Run tracking session
    print("\n3️⃣  Running eye tracking session...")
    session_id = run_tracking_and_save(duration=10, user_id=user_id)
    
    if session_id:
        # View saved sessions
        print("\n4️⃣  Viewing saved sessions...")
        view_saved_sessions(user_id)
        
        print("\n✅ Complete workflow executed successfully!")
        print(f"\n📊 Session Statistics:")
        print(f"   - Session ID: {session_id}")
        print(f"   - User ID: {user_id}")
        print(f"   - Data saved to: db.sqlite3")
        
        print("\n📝 Next Steps:")
        print("   1. View API docs: http://localhost:5000/docs")
        print("   2. Access via API: GET /camera-eye-tracking/sessions")
        print("   3. Use Flutter app to view results")
    else:
        print("\n⚠️  Workflow completed but session was not saved.")


def quick_test():
    """Quick 5-second test without database"""
    
    print("\n" + "="*60)
    print("QUICK TEST (5 seconds - No Database)")
    print("="*60)
    
    tracker = EyeTracker(camera_id=0)
    
    print("\nLook at your camera for 5 seconds...")
    time.sleep(2)
    
    tracker.run_live_tracking(duration=5)
    
    stats = tracker.get_statistics()
    
    if "error" not in stats:
        print(f"\n✓ Test completed!")
        print(f"  Blinks: {stats['total_blinks']}")
        print(f"  Blink Rate: {stats['blink_rate_per_minute']:.1f}/min")
        print(f"  Average EAR: {stats['ear_statistics']['average']['mean']:.3f}")
    else:
        print("\n❌ No face detected during test")


def main():
    """Main menu"""
    
    print("\n" + "╔" + "="*58 + "╗")
    print("║" + " "*58 + "║")
    print("║" + "  EYE TRACKING WITH DATABASE STORAGE".center(58) + "║")
    print("║" + "  OpenCV + MediaPipe + SQLite".center(58) + "║")
    print("║" + " "*58 + "║")
    print("╚" + "="*58 + "╝")
    
    while True:
        print("\n" + "="*60)
        print("SELECT AN OPTION")
        print("="*60)
        print("1. Quick Test (5s, no database)")
        print("2. Run 10s Session and Save to Database")
        print("3. Run 20s Session and Save to Database")
        print("4. Run Custom Duration and Save")
        print("5. Complete Workflow Demo")
        print("6. View Saved Sessions")
        print("7. Exit")
        print("="*60)
        
        choice = input("\nEnter choice (1-7): ").strip()
        
        if choice == "1":
            quick_test()
            
        elif choice == "2":
            print("\nInitializing...")
            with app.app_context():
                db.create_all()
            user_id = create_test_user()
            run_tracking_and_save(duration=10, user_id=user_id)
            
        elif choice == "3":
            print("\nInitializing...")
            with app.app_context():
                db.create_all()
            user_id = create_test_user()
            run_tracking_and_save(duration=20, user_id=user_id)
            
        elif choice == "4":
            try:
                duration = int(input("Enter duration in seconds: "))
                if duration <= 0:
                    print("Duration must be positive!")
                    continue
                
                print("\nInitializing...")
                with app.app_context():
                    db.create_all()
                user_id = create_test_user()
                run_tracking_and_save(duration=duration, user_id=user_id)
                
            except ValueError:
                print("Invalid input! Please enter a number.")
                
        elif choice == "5":
            demonstrate_full_workflow()
            
        elif choice == "6":
            with app.app_context():
                db.create_all()
            user_id = create_test_user()
            view_saved_sessions(user_id)
            
        elif choice == "7":
            print("\nExiting...")
            break
            
        else:
            print("\n❌ Invalid choice! Please enter 1-7.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Program interrupted by user")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
