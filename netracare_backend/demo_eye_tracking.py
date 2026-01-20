"""
Simple Usage Example - Eye Movement and Blink Tracking
Using OpenCV and MediaPipe with Manual EAR Calculation
"""

from eye_tracking_opencv import EyeTracker
from eye_tracking_db_helper import save_eye_tracking_session
import sys


def quick_demo(user_id=None):
    """Quick 10-second demo"""
    print("=" * 60)
    print("Eye Movement and Blink Tracking Demo")
    print("Using OpenCV + MediaPipe + Manual EAR Calculation")
    print("=" * 60)
    print()
    print("Features:")
    print("  ✓ Real-time facial landmark detection (MediaPipe)")
    print("  ✓ Manual Eye Aspect Ratio (EAR) calculation")
    print("  ✓ Blink detection and counting")
    print("  ✓ Eye movement tracking (gaze direction)")
    print("  ✓ Statistics and analysis")
    print()
    print("Starting 10-second tracking session...")
    print("Look at the camera and blink naturally.")
    print("Try looking left, right, up, and down.")
    print()
    
    # Create tracker
    tracker = EyeTracker(camera_id=0)
    
    try:
        # Run 10-second tracking
        tracker.run_live_tracking(duration=10)
        
        # Display statistics
        print("\n" + "=" * 60)
        print("TRACKING RESULTS")
        print("=" * 60)
        
        stats = tracker.get_statistics()
        
        if "error" not in stats:
            print(f"\nSession Duration: {stats['duration_seconds']:.2f} seconds")
            print(f"Total Blinks Detected: {stats['total_blinks']}")
            print(f"Blink Rate: {stats['blink_rate_per_minute']:.1f} blinks/minute")
            print(f"  (Normal range: 15-20 blinks/minute)")
            
            print("\n--- Eye Aspect Ratio (EAR) Analysis ---")
            left_ear = stats['ear_statistics']['left_eye']
            right_ear = stats['ear_statistics']['right_eye']
            avg_ear = stats['ear_statistics']['average']
            
            print(f"Left Eye EAR:  {left_ear['mean']:.3f} ± {left_ear['std']:.3f}")
            print(f"Right Eye EAR: {right_ear['mean']:.3f} ± {right_ear['std']:.3f}")
            print(f"Average EAR:   {avg_ear['mean']:.3f} ± {avg_ear['std']:.3f}")
            print(f"  (EAR > 0.21: Eyes open, EAR < 0.21: Eyes closed/blinking)")
            
            print("\n--- Gaze Direction Analysis ---")
            gaze_dist = stats['gaze_distribution']
            total_frames = sum(gaze_dist.values())
            
            for direction in ['center', 'left', 'right', 'up', 'down']:
                if direction in gaze_dist:
                    count = gaze_dist[direction]
                    percentage = (count / total_frames) * 100
                    bar = "█" * int(percentage / 2)
                    print(f"{direction.capitalize():8s}: {bar} {percentage:5.1f}%")
            
            print(f"\nTotal Data Points Collected: {stats['data_points']}")
            
            # Save to database if user_id provided
            if user_id:
                try:
                    session_id = save_eye_tracking_session(
                        user_id=user_id,
                        stats=stats,
                        session_name="Quick Demo - 10s",
                        notes="Quick demo session"
                    )
                    print(f"\n✓ Session saved to database (ID: {session_id})")
                except Exception as e:
                    print(f"\n⚠️  Could not save to database: {e}")
            else:
                print("\n⚠️  No user ID provided. Results not saved to database.")
                print("   To save results, run: quick_demo(user_id=YOUR_USER_ID)")
            
        else:
            print("No tracking data collected.")
            print("Make sure your camera is working and your face is visible.")
        
    except KeyboardInterrupt:
        print("\n\nTracking interrupted by user.")
    except Exception as e:
        print(f"\n\nError during tracking: {e}")
        print("Make sure:")
        print("  1. Your webcam is connected and working")
        print("  2. No other application is using the camera")
        print("  3. You have installed: opencv-python, mediapipe, numpy")
    
    print("\n" + "=" * 60)


def continuous_tracking(user_id=None):
    """Continuous tracking until user presses 'q'"""
    print("=" * 60)
    print("Continuous Eye Tracking Mode")
    print("=" * 60)
    print()
    print("Press 'Q' to stop tracking")
    print()
    
    tracker = EyeTracker(camera_id=0)
    
    try:
        tracker.run_live_tracking(duration=None)
        
        # Display final statistics
        print("\n" + "=" * 60)
        print("FINAL STATISTICS")
        print("=" * 60)
        
        stats = tracker.get_statistics()
        
        if "error" not in stats:
            print(f"\nTotal Duration: {stats['duration_seconds']:.2f} seconds")
            print(f"Total Blinks: {stats['total_blinks']}")
            print(f"Blink Rate: {stats['blink_rate_per_minute']:.1f} blinks/minute")
            print(f"Average EAR: {stats['ear_statistics']['average']['mean']:.3f}")
            
            # Save to database if user_id provided
            if user_id:
                try:
                    session_id = save_eye_tracking_session(
                        user_id=user_id,
                        stats=stats,
                        session_name="Continuous Tracking Session",
                        notes="Continuous tracking until user stopped"
                    )
                    print(f"\n✓ Session saved to database (ID: {session_id})")
                except Exception as e:
                    print(f"\n⚠️  Could not save to database: {e}")
            else:
                print("\n⚠️  No user ID provided. Results not saved to database.")
            
    except Exception as e:
        print(f"\nError: {e}")


def custom_duration_tracking(user_id=None):
    """Custom duration tracking"""
    print("=" * 60)
    print("Custom Duration Tracking")
    print("=" * 60)
    print()
    
    try:
        duration = int(input("Enter tracking duration in seconds: "))
        
        if duration <= 0:
            print("Duration must be positive!")
            
            # Save to database if user_id provided
            if user_id:
                try:
                    session_id = save_eye_tracking_session(
                        user_id=user_id,
                        stats=stats,
                        session_name=f"Custom Duration - {duration}s",
                        notes=f"Custom tracking session of {duration} seconds"
                    )
                    print(f"\n✓ Session saved to database (ID: {session_id})")
                except Exception as e:
                    print(f"\n⚠️  Could not save to database: {e}")
            else:
                print("\n⚠️  No user ID provided. Results not saved to database.")
            return
        
        print(f"\nStarting {duration}-second tracking session...")
        
        tracker = EyeTracker(camera_id=0)
        tracker.run_live_tracking(duration=duration)
        
        # Show statistics
        stats = tracker.get_statistics()
    # Ask for user ID at the start
    print("\n" + "=" * 60)
    print("EYE TRACKING - OpenCV + MediaPipe + Manual EAR")
    print("=" * 60)
    print("\nOptional: Enter User ID to save results to database")
    print("(Leave empty to skip database saving)")
    
    user_id_input = input("User ID: ").strip()
    user_id = None
    
    if user_id_input:
        try:
            user_id = int(user_id_input)
            print(f"✓ Will save results for User ID: {user_id}")
        except ValueError:
            print("⚠️  Invalid User ID. Results will not be saved to database.")
    else:
        print("⚠️  No User ID provided. Results will not be saved to database.")
    
        
        if "error" not in stats:
            print(f"\n✓ Tracking completed!")
            print(f"  Blinks: {stats['total_blinks']}")
            print(f"  Blink Rate: {stats['blink_rate_per_minute']:.1f}/min")
            print(f"  Avg EAR: {stats['ear_statistics']['average']['mean']:.3f}")
        
    except ValueError:
        print("Invalid input! Please enter a number.")
    except Exception as e:
        print(f"Error: user_id)
        elif choice == "2":
            continuous_tracking(user_id)
        elif choice == "3":
            custom_duration_tracking(user_id
    while True:
        print("\n" + "=" * 60)
        print("EYE TRACKING - OpenCV + MediaPipe + Manual EAR")
        print("=" * 60)
        print("\nSelect an option:")
        print("  1. Quick Demo (10 seconds)")
        print("  2. Continuous Tracking (press Q to stop)")
        print("  3. Custom Duration")
        print("  4. Exit")
        print()
        
        choice = input("Enter choice (1-4): ").strip()
        
        if choice == "1":
            quick_demo()
        elif choice == "2":
            continuous_tracking()
        elif choice == "3":
            custom_duration_tracking()
        elif choice == "4":
            print("\nExiting...")
            break
        else:
            print("\nInvalid choice! Please enter 1-4.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nProgram terminated by user.")
        sys.exit(0)
