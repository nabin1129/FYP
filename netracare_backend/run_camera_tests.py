"""
Run Real Camera Tests for Eye Tracking
This script runs interactive tests using your laptop camera
"""

import sys
import cv2
from eye_tracking_opencv import EyeTracker
from eye_tracking_db_helper import save_eye_tracking_session
import numpy as np
import time


def check_camera_availability():
    """Check if camera is available"""
    print("="*60)
    print("CHECKING CAMERA AVAILABILITY")
    print("="*60)
    
    cap = cv2.VideoCapture(0)
    
    if cap.isOpened():
        ret, frame = cap.read()
        if ret:
            print(f"✓ Camera is available")
            print(f"  Resolution: {frame.shape[1]}x{frame.shape[0]}")
            print(f"  Channels: {frame.shape[2]}")
            cap.release()
            return True
        else:
            print("✗ Camera opened but cannot read frames")
            cap.release()
            return False
    else:
        print("✗ Cannot open camera")
        print("\nTroubleshooting:")
        print("  1. Check if camera is connected")
        print("  2. Close other apps using the camera")
        print("  3. Try a different camera_id")
        return False


def test_basic_capture():
    """Test basic camera capture and display"""
    print("\n" + "="*60)
    print("TEST 1: BASIC CAMERA CAPTURE")
    print("="*60)
    print("Press 'q' to continue to next test")
    
    cap = cv2.VideoCapture(0)
    
    if not cap.isOpened():
        print("✗ Failed to open camera")
        return False
    
    frame_count = 0
    
    while True:
        ret, frame = cap.read()
        
        if not ret:
            print("✗ Failed to read frame")
            break
        
        frame_count += 1
        
        # Add text
        cv2.putText(frame, f"Frame: {frame_count}", (10, 30),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(frame, "Press 'Q' to continue", (10, 60),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
        
        cv2.imshow('Basic Capture Test', frame)
        
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break
    
    cap.release()
    cv2.destroyAllWindows()
    
    print(f"✓ Captured {frame_count} frames successfully")
    return True


def test_face_detection():
    """Test face detection with MediaPipe"""
    print("\n" + "="*60)
    print("TEST 2: FACE DETECTION")
    print("="*60)
    print("Look at the camera. Face landmarks will be drawn.")
    print("Press 'q' to continue to next test")
    
    tracker = EyeTracker(camera_id=0)
    
    if not tracker.start_camera():
        print("✗ Failed to start camera")
        return False
    
    frames_total = 0
    frames_with_face = 0
    
    try:
        while True:
            ret, frame = tracker.cap.read()
            
            if not ret:
                break
            
            frames_total += 1
            
            # Process frame
            processed_frame, blink_data, movement_data = tracker.process_frame(frame)
            
            if blink_data:
                frames_with_face += 1
                detection_rate = (frames_with_face / frames_total) * 100
                
                # Add detection info
                cv2.putText(processed_frame, f"Detection Rate: {detection_rate:.1f}%", 
                           (10, 210), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
                cv2.putText(processed_frame, "Press 'Q' to continue", 
                           (10, 240), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            else:
                cv2.putText(processed_frame, "NO FACE DETECTED", (10, 210),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)
                cv2.putText(processed_frame, "Look at the camera!", (10, 240),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 2)
            
            cv2.imshow('Face Detection Test', processed_frame)
            
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
        
        detection_rate = (frames_with_face / frames_total) * 100 if frames_total > 0 else 0
        print(f"\n✓ Face detected in {frames_with_face}/{frames_total} frames ({detection_rate:.1f}%)")
        
        if detection_rate < 50:
            print("⚠️  Low detection rate. Make sure:")
            print("   - Your face is clearly visible")
            print("   - Room has good lighting")
            print("   - You're facing the camera")
        else:
            print("✓ Face detection working well!")
        
        return True
        
    finally:
        tracker.stop_camera()


def test_blink_detection():
    """Test blink detection"""
    print("\n" + "="*60)
    print("TEST 3: BLINK DETECTION")
    print("="*60)
    print("Duration: 15 seconds")
    print("Please blink naturally while looking at the camera")
    print()
    
    input("Press Enter to start...")
    
    tracker = EyeTracker(camera_id=0)
    
    if not tracker.start_camera():
        print("✗ Failed to start camera")
        return False
    
    start_time = time.time()
    duration = 15
    last_blink_count = 0
    
    try:
        while time.time() - start_time < duration:
            ret, frame = tracker.cap.read()
            
            if not ret:
                continue
            
            processed_frame, blink_data, movement_data = tracker.process_frame(frame)
            
            # Check for new blinks
            if blink_data and blink_data.blink_count > last_blink_count:
                print(f"  🔵 BLINK #{blink_data.blink_count} detected at {time.time()-start_time:.1f}s")
                last_blink_count = blink_data.blink_count
            
            # Add timer
            elapsed = time.time() - start_time
            remaining = duration - elapsed
            cv2.putText(processed_frame, f"Time remaining: {remaining:.1f}s", 
                       (10, 210), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            
            cv2.imshow('Blink Detection Test', processed_frame)
            cv2.waitKey(1)
        
        print(f"\n✓ Test completed!")
        print(f"  Total blinks detected: {tracker.total_blinks}")
        print(f"  Blink rate: {(tracker.total_blinks / duration) * 60:.1f} blinks/minute")
        print(f"  Normal range: 15-20 blinks/minute")
        
        if tracker.total_blinks == 0:
            print("\n⚠️  No blinks detected. This could mean:")
            print("   - You didn't blink during the test")
            print("   - Face wasn't detected consistently")
            print("   - EAR threshold needs adjustment")
        
        return True
        
    finally:
        tracker.stop_camera()


def test_eye_movement():
    """Test eye movement tracking"""
    print("\n" + "="*60)
    print("TEST 4: EYE MOVEMENT TRACKING")
    print("="*60)
    print("Duration: 20 seconds")
    print("Instructions:")
    print("  - Look CENTER for 4 seconds")
    print("  - Look LEFT for 4 seconds")
    print("  - Look RIGHT for 4 seconds")
    print("  - Look UP for 4 seconds")
    print("  - Look DOWN for 4 seconds")
    print()
    
    input("Press Enter to start...")
    
    tracker = EyeTracker(camera_id=0)
    
    if not tracker.start_camera():
        print("✗ Failed to start camera")
        return False
    
    start_time = time.time()
    duration = 20
    directions_detected = {}
    
    try:
        while time.time() - start_time < duration:
            ret, frame = tracker.cap.read()
            
            if not ret:
                continue
            
            processed_frame, blink_data, movement_data = tracker.process_frame(frame)
            
            if movement_data:
                direction = movement_data.gaze_direction
                directions_detected[direction] = directions_detected.get(direction, 0) + 1
            
            # Add instructions based on elapsed time
            elapsed = time.time() - start_time
            if elapsed < 4:
                instruction = "Look CENTER"
            elif elapsed < 8:
                instruction = "Look LEFT"
            elif elapsed < 12:
                instruction = "Look RIGHT"
            elif elapsed < 16:
                instruction = "Look UP"
            else:
                instruction = "Look DOWN"
            
            cv2.putText(processed_frame, instruction, (10, 210),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
            cv2.putText(processed_frame, f"Time: {elapsed:.1f}s / {duration}s", 
                       (10, 240), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            
            cv2.imshow('Eye Movement Test', processed_frame)
            cv2.waitKey(1)
        
        print(f"\n✓ Test completed!")
        print(f"\nGaze Direction Distribution:")
        
        total_frames = sum(directions_detected.values())
        
        for direction in ['center', 'left', 'right', 'up', 'down']:
            if direction in directions_detected:
                count = directions_detected[direction]
                percent = (count / total_frames) * 100
                bar = "█" * int(percent / 2)
                print(f"  {direction.capitalize():8s}: {bar} {percent:5.1f}% ({count} frames)")
        
        # Check if all directions were detected
        expected_directions = {'center', 'left', 'right', 'up', 'down'}
        detected_set = set(directions_detected.keys())
        
        if expected_directions.issubset(detected_set):
            print("\n✓ All directions detected successfully!")
        else:
            missing = expected_directions - detected_set
            print(f"\n⚠️  Missing directions: {', '.join(missing)}")
        
        return True
        
    finally:
        tracker.stop_camera()


def test_full_session(user_id=None):
    """Test complete tracking session"""
    print("\n" + "="*60)
    print("TEST 5: COMPLETE TRACKING SESSION")
    print("="*60)
    print("Duration: 20 seconds")
    print("Act naturally - blink, move eyes, etc.")
    print()
    
    input("Press Enter to start...")
    
    tracker = EyeTracker(camera_id=0)
    
    if not tracker.start_camera():
        print("✗ Failed to start camera")
        return False
    
    start_time = time.time()
    duration = 20
    
    try:
        print("\n📹 Recording...")
        
        while time.time() - start_time < duration:
            ret, frame = tracker.cap.read()
            
            if not ret:
                continue
            
            processed_frame, blink_data, movement_data = tracker.process_frame(frame)
            
            elapsed = time.time() - start_time
            remaining = duration - elapsed
            
            cv2.putText(processed_frame, f"Recording: {remaining:.1f}s remaining", 
                       (10, 210), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
            
            cv2.imshow('Full Session Test', processed_frame)
            cv2.waitKey(1)
        
        print("\n📊 Generating statistics...")
        
        stats = tracker.get_statistics()
        
        if "error" not in stats:
            print("\n" + "="*60)
            print("COMPLETE TRACKING RESULTS")
            print("="*60)
            
            print(f"\n⏱️  Duration: {stats['duration_seconds']:.2f} seconds")
            print(f"👁️  Total blinks: {stats['total_blinks']}")
            print(f"💫 Blink rate: {stats['blink_rate_per_minute']:.1f} blinks/min")
            
            print(f"\n📈 Eye Aspect Ratio (EAR) Statistics:")
            for eye_name in ['left_eye', 'right_eye', 'average']:
                ear = stats['ear_statistics'][eye_name]
                label = eye_name.replace('_', ' ').title()
                print(f"  {label:12s}: {ear['mean']:.3f} ± {ear['std']:.3f} "
                      f"[{ear['min']:.3f} - {ear['max']:.3f}]")
            
            print(f"\n👀 Gaze Direction Distribution:")
            gaze = stats['gaze_distribution']
            total = sum(gaze.values())
            
            for direction in ['center', 'left', 'right', 'up', 'down']:
                if direction in gaze:
                    count = gaze[direction]
                    percent = (count / total) * 100
                    bar = "█" * int(percent / 3)
                    print(f"  {direction.capitalize():8s}: {bar} {percent:5.1f}%")
            
            print(f"\n📊 Data Points: {stats['data_points']}")
            
            # Save to database if user_id provided
            if user_id:
                try:
                    session_id = save_eye_tracking_session(
                        user_id=user_id,
                        stats=stats,
                        session_name="Complete Camera Test - 20s",
                        notes="Full session test with natural behavior"
                    )
                    print(f"\n✓ Session saved to database (ID: {session_id})")
                except Exception as e:
                    print(f"\n⚠️  Could not save to database: {e}")
            else:
                print("\n⚠️  No user ID provided. Results not saved to database.")
            
            print("\n✓ All tests completed successfully!")
            
        else:
            print("\n⚠️  No tracking data collected")
        
        return True
        
    finally:
        tracker.stop_camera()


def main():
    """Run all camera tests"""
    print("\n")
    print("╔" + "="*58 + "╗")
    print("║" + " "*58 + "║")
    print("║" + "  EYE TRACKING CAMERA TESTS".center(58) + "║")
    print("║" + "  Using OpenCV + MediaPipe + Manual EAR".center(58) + "║")
    print("║" + " "*58 + "║")
    print("╚" + "="*58 + "╝")
    print()
    
    # Ask for user ID
    print("Optional: Enter User ID to save test results to database")
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
    
    # Check camera first
    if not check_camera_availability():
        print("\n❌ Camera not available. Cannot run tests.")
        print("\nExiting...")
        return
    
    print("\n" + "="*60)
    print("AVAILABLE TESTS")
    print("="*60)
    print("1. Basic Camera Capture")
    print("2. Face Detection Test")
    print("3. Blink Detection Test (15s)")
    print("4. Eye Movement Test (20s)")
    print("5. Complete Session Test (20s)")
    print("6. Run All Tests")
    print("7. Exit")
    print("="*60)
    
    while True:
        choice = input("\nSelect test (1-7): ").strip()
        
        if choice == "1":
            test_basic_capture()
        elif choice == "2":
            test_face_detection()
        elif choice == "3":
            test_blink_detection()
        elif choice == "4":
            test_eye_movement()
        elif choice == "5":
            test_full_session(user_id)
        elif choice == "6":
            print("\nRunning all tests...\n")
            test_basic_capture()
            test_face_detection()
            test_blink_detection()
            test_eye_movement()
            test_full_session(user_id)
            print("\n✓ All tests completed!")
            break
        elif choice == "7":
            print("\nExiting...")
            break
        else:
            print("Invalid choice. Please enter 1-7.")
    
    print("\n" + "="*60)
    print("Tests completed. Thank you!")
    print("="*60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠️  Tests interrupted by user")
        cv2.destroyAllWindows()
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Error: {e}")
        cv2.destroyAllWindows()
        sys.exit(1)
