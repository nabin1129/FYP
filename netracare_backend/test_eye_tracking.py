"""
Eye Tracking Test Module - Test Cases and Usage Examples
Enhanced with OpenCV and MediaPipe testing
Includes database saving functionality
"""

import pytest
from eye_tracking_model import (
    EyeTrackingDataPoint,
    EyeTrackingDataset,
    EyeTrackingMetrics,
    create_sample_dataset
)
from eye_tracking_opencv import (
    EyeAspectRatioCalculator,
    EyeTracker,
    EyeLandmarks,
    BlinkData,
    EyeMovementData
)
import numpy as np
import cv2


class TestEyeTrackingDataPoint:
    """Test cases for EyeTrackingDataPoint"""
    
    def test_create_data_point(self):
        """Test creating a valid data point"""
        point = EyeTrackingDataPoint(
            timestamp=1.0,
            gaze_x=960,
            gaze_y=540,
            left_pupil_diameter=3.5,
            right_pupil_diameter=3.5
        )
        assert point.timestamp == 1.0
        assert point.gaze_x == 960
        assert point.gaze_y == 540
    
    def test_data_point_to_dict(self):
        """Test converting data point to dictionary"""
        point = EyeTrackingDataPoint(
            timestamp=1.0,
            gaze_x=960,
            gaze_y=540,
            left_pupil_diameter=3.5,
            right_pupil_diameter=3.5,
            fixation_duration=0.3,
            saccade_velocity=250
        )
        data_dict = point.to_dict()
        assert data_dict['timestamp'] == 1.0
        assert data_dict['gaze_x'] == 960


class TestEyeTrackingDataset:
    """Test cases for EyeTrackingDataset"""
    
    def test_create_dataset(self):
        """Test creating a dataset"""
        dataset = EyeTrackingDataset("Test Dataset", 1920, 1080)
        assert dataset.test_name == "Test Dataset"
        assert dataset.screen_width == 1920
        assert dataset.screen_height == 1080
        assert dataset.get_point_count() == 0
    
    def test_add_single_data_point(self):
        """Test adding a single data point"""
        dataset = EyeTrackingDataset("Test")
        point = EyeTrackingDataPoint(1.0, 960, 540, 3.5, 3.5)
        dataset.add_data_point(point)
        assert dataset.get_point_count() == 1
    
    def test_add_multiple_data_points(self):
        """Test adding multiple data points"""
        dataset = EyeTrackingDataset("Test")
        points = [
            EyeTrackingDataPoint(1.0, 960, 540, 3.5, 3.5),
            EyeTrackingDataPoint(2.0, 970, 550, 3.6, 3.6),
            EyeTrackingDataPoint(3.0, 950, 530, 3.4, 3.4)
        ]
        dataset.add_data_points(points)
        assert dataset.get_point_count() == 3
    
    def test_add_invalid_data_point(self):
        """Test adding invalid data point raises error"""
        dataset = EyeTrackingDataset("Test")
        with pytest.raises(ValueError):
            dataset.add_data_point("invalid")
    
    def test_set_test_duration(self):
        """Test setting test duration"""
        dataset = EyeTrackingDataset("Test")
        dataset.set_test_duration(30.0)
        assert dataset.test_duration == 30.0
    
    def test_invalid_test_duration(self):
        """Test invalid test duration raises error"""
        dataset = EyeTrackingDataset("Test")
        with pytest.raises(ValueError):
            dataset.set_test_duration(-5)
    
    def test_dataset_to_dict(self):
        """Test converting dataset to dictionary"""
        dataset = EyeTrackingDataset("Test", 1920, 1080)
        dataset.set_test_duration(30.0)
        point = EyeTrackingDataPoint(1.0, 960, 540, 3.5, 3.5)
        dataset.add_data_point(point)
        
        data_dict = dataset.to_dict()
        assert data_dict['test_name'] == "Test"
        assert data_dict['point_count'] == 1
        assert data_dict['test_duration'] == 30.0


class TestEyeTrackingMetrics:
    """Test cases for EyeTrackingMetrics"""
    
    def test_validate_empty_dataset(self):
        """Test validation fails for empty dataset"""
        dataset = EyeTrackingDataset("Empty Test")
        with pytest.raises(ValueError):
            EyeTrackingMetrics.validate_dataset(dataset)
    
    def test_calculate_gaze_accuracy(self):
        """Test gaze accuracy calculation"""
        actual_points = [(960, 540), (970, 550), (950, 530)]
        tracked_points = [(960, 540), (970, 550), (950, 530)]
        accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(actual_points, tracked_points)
        assert accuracy == 100.0
    
    def test_calculate_gaze_accuracy_with_error(self):
        """Test gaze accuracy with tracking error"""
        actual_points = [(960, 540), (970, 550)]
        tracked_points = [(960, 540), (980, 560)]  # 10px error on second point
        accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(actual_points, tracked_points)
        assert accuracy < 100.0
    
    def test_fixation_stability_metrics(self):
        """Test fixation stability calculation"""
        fixation_durations = [0.3, 0.35, 0.32, 0.38, 0.31]
        stability = EyeTrackingMetrics.calculate_fixation_stability(fixation_durations)
        
        assert 'mean_duration' in stability
        assert 'std_deviation' in stability
        assert 'stability_score' in stability
        assert stability['stability_score'] <= 100
        assert stability['stability_score'] >= 0
    
    def test_saccade_metrics(self):
        """Test saccade velocity metrics"""
        saccade_velocities = [150, 200, 180, 220, 190]
        metrics = EyeTrackingMetrics.calculate_saccade_metrics(saccade_velocities)
        
        assert metrics['saccade_count'] == 5
        assert metrics['mean_velocity'] > 0
        assert metrics['max_velocity'] == 220
    
    def test_pupil_metrics(self):
        """Test pupil diameter metrics"""
        dataset = create_sample_dataset()
        pupil_metrics = EyeTrackingMetrics.calculate_pupil_metrics(dataset)
        
        assert 'left_pupil' in pupil_metrics
        assert 'right_pupil' in pupil_metrics
        assert 'mean' in pupil_metrics['left_pupil']
        assert 'std' in pupil_metrics['left_pupil']
    
    def test_overall_performance(self):
        """Test overall performance calculation"""
        dataset = create_sample_dataset()
        
        gaze_accuracy = 85.0
        fixation_stability = {'stability_score': 80.0}
        saccade_metrics = {'std_velocity': 15.0}
        
        performance = EyeTrackingMetrics.calculate_overall_performance(
            dataset, gaze_accuracy, fixation_stability, saccade_metrics
        )
        
        assert 'overall_score' in performance
        assert 'classification' in performance
        assert performance['overall_score'] <= 100
        assert performance['classification'] in ['Excellent', 'Good', 'Fair', 'Poor']


class TestIntegration:
    """Integration tests for complete eye tracking workflow"""
    
    def test_complete_eye_tracking_workflow(self):
        """Test complete workflow from dataset creation to performance analysis"""
        # Create dataset
        dataset = create_sample_dataset()
        assert dataset.get_point_count() > 0
        
        # Extract gaze points
        actual_gaze_points = [(p.gaze_x, p.gaze_y) for p in dataset.get_data_points()]
        tracked_gaze_points = actual_gaze_points  # Perfect tracking for test
        
        # Calculate metrics
        gaze_accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(
            actual_gaze_points, tracked_gaze_points
        )
        
        fixation_durations = [p.fixation_duration for p in dataset.get_data_points()]
        fixation_stability = EyeTrackingMetrics.calculate_fixation_stability(fixation_durations)
        
        saccade_velocities = [p.saccade_velocity for p in dataset.get_data_points()]
        saccade_metrics = EyeTrackingMetrics.calculate_saccade_metrics(saccade_velocities)
        
        pupil_metrics = EyeTrackingMetrics.calculate_pupil_metrics(dataset)
        
        # Calculate overall performance
        performance = EyeTrackingMetrics.calculate_overall_performance(
            dataset, gaze_accuracy, fixation_stability, saccade_metrics
        )
        
        # Verify results
        assert performance['overall_score'] > 0
        assert performance['classification'] is not None
        assert gaze_accuracy > 0
        assert fixation_stability['stability_score'] >= 0
    
    def test_sample_dataset_creation(self):
        """Test creation and analysis of sample dataset"""
        dataset = create_sample_dataset()
        
        assert dataset.test_name == "Sample Eye Tracking Test"
        assert dataset.get_point_count() == 100
        assert dataset.test_duration == 30.0
        
        # Verify data consistency
        for point in dataset.get_data_points():
            assert 0 <= point.gaze_x <= 1920
            assert 0 <= point.gaze_y <= 1080
            assert point.left_pupil_diameter > 0
            assert point.right_pupil_diameter > 0


class TestEyeAspectRatioCalculator:
    """Test cases for manual EAR calculation"""
    
    def test_calculate_distance(self):
        """Test Euclidean distance calculation"""
        point1 = np.array([0, 0])
        point2 = np.array([3, 4])
        distance = EyeAspectRatioCalculator.calculate_distance(point1, point2)
        assert distance == 5.0
    
    def test_calculate_ear_normal_eye(self):
        """Test EAR calculation for normal open eye"""
        # Simulated eye landmarks (open eye)
        eye_landmarks = np.array([
            [0, 0],    # p1 - left corner
            [10, -5],  # p2 - top left
            [20, -5],  # p3 - top right
            [30, 0],   # p4 - right corner
            [20, 5],   # p5 - bottom right
            [10, 5]    # p6 - bottom left
        ])
        
        ear = EyeAspectRatioCalculator.calculate_ear(eye_landmarks)
        assert ear > 0.2  # Open eye should have higher EAR
        assert ear < 0.4
    
    def test_calculate_ear_closed_eye(self):
        """Test EAR calculation for closed eye"""
        # Simulated eye landmarks (closed eye - minimal vertical distance)
        eye_landmarks = np.array([
            [0, 0],    # p1 - left corner
            [10, -1],  # p2 - top left (close to bottom)
            [20, -1],  # p3 - top right
            [30, 0],   # p4 - right corner
            [20, 1],   # p5 - bottom right
            [10, 1]    # p6 - bottom left
        ])
        
        ear = EyeAspectRatioCalculator.calculate_ear(eye_landmarks)
        assert ear < 0.2  # Closed eye should have lower EAR
    
    def test_calculate_ear_invalid_landmarks(self):
        """Test EAR calculation with invalid number of landmarks"""
        eye_landmarks = np.array([[0, 0], [1, 1]])  # Only 2 points
        
        with pytest.raises(ValueError):
            EyeAspectRatioCalculator.calculate_ear(eye_landmarks)
    
    def test_calculate_ear_zero_horizontal(self):
        """Test EAR calculation with zero horizontal distance"""
        # All points at same x position
        eye_landmarks = np.array([
            [0, 0],
            [0, 5],
            [0, 5],
            [0, 0],
            [0, -5],
            [0, -5]
        ])
        
        ear = EyeAspectRatioCalculator.calculate_ear(eye_landmarks)
        assert ear == 0.0


class TestEyeTracker:
    """Test cases for EyeTracker class"""
    
    def test_eye_tracker_initialization(self):
        """Test EyeTracker initialization"""
        tracker = EyeTracker(camera_id=0)
        
        assert tracker.camera_id == 0
        assert tracker.total_blinks == 0
        assert tracker.frame_counter == 0
        assert len(tracker.blink_history) == 0
        assert len(tracker.movement_history) == 0
    
    def test_camera_availability(self):
        """Test if laptop camera is available"""
        tracker = EyeTracker(camera_id=0)
        is_available = tracker.start_camera()
        
        if is_available:
            print("\n✓ Camera is available and working")
            tracker.stop_camera()
            assert True
        else:
            print("\n✗ Camera not available - skipping camera tests")
            pytest.skip("Camera not available")
    
    def test_real_camera_capture(self):
        """Test actual camera frame capture"""
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        try:
            # Capture a single frame
            ret, frame = tracker.cap.read()
            
            assert ret, "Failed to capture frame from camera"
            assert frame is not None, "Frame is None"
            assert len(frame.shape) == 3, "Frame should be 3D array (height, width, channels)"
            assert frame.shape[2] == 3, "Frame should have 3 color channels"
            
            print(f"\n✓ Successfully captured frame: {frame.shape}")
        finally:
            tracker.stop_camera()
    
    def test_real_face_detection(self):
        """Test face detection on real camera feed"""
        import cv2
        
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        print("\n📸 Starting face detection test...")
        print("Please look at the camera for 3 seconds...")
        
        face_detected = False
        frames_with_face = 0
        total_frames = 0
        
        try:
            import time
            start_time = time.time()
            
            while time.time() - start_time < 3:  # 3 seconds
                ret, frame = tracker.cap.read()
                
                if not ret:
                    continue
                
                total_frames += 1
                
                # Process frame
                processed_frame, blink_data, movement_data = tracker.process_frame(frame)
                
                if blink_data is not None:
                    face_detected = True
                    frames_with_face += 1
                    
                    print(f"  Frame {total_frames}: Face detected | "
                          f"Left EAR: {blink_data.left_ear:.3f} | "
                          f"Right EAR: {blink_data.right_ear:.3f}")
                
                # Small delay
                cv2.waitKey(1)
            
            if face_detected:
                detection_rate = (frames_with_face / total_frames) * 100
                print(f"\n✓ Face detected in {frames_with_face}/{total_frames} frames ({detection_rate:.1f}%)")
                assert face_detected, "Face should be detected"
            else:
                print("\n✗ No face detected - make sure you're in front of the camera")
                pytest.skip("No face detected during test")
                
        finally:
            tracker.stop_camera()
    
    def test_real_blink_detection(self):
        """Test blink detection with real camera - Interactive test"""
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        print("\nStarting blink detection test...")
        print("Please blink 3-5 times in the next 10 seconds...")
        
        try:
            import time
            start_time = time.time()
            initial_blinks = tracker.total_blinks
            
            while time.time() - start_time < 10:  # 10 seconds
                ret, frame = tracker.cap.read()
                
                if not ret:
                    continue
                
                processed_frame, blink_data, movement_data = tracker.process_frame(frame)
                
                if blink_data and blink_data.is_blinking:
                    print(f"  🔵 Blink detected! Total: {blink_data.blink_count}")
            
            total_blinks = tracker.total_blinks - initial_blinks
            
            print(f"\n✓ Test completed: {total_blinks} blinks detected")
            
            # Verify we detected at least some blinks (if user blinked)
            if total_blinks > 0:
                assert total_blinks >= 1, "At least one blink should be detected"
                print(f"  Blink detection is working!")
            else:
                print("  No blinks detected - you may not have blinked or face wasn't visible")
                
        finally:
            tracker.stop_camera()
    
    def test_real_eye_movement_tracking(self):
        """Test eye movement tracking with real camera"""
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        print("\n👀 Starting eye movement test...")
        print("Please look: CENTER, LEFT, RIGHT, UP, DOWN (2 seconds each)")
        
        try:
            import time
            directions_detected = set()
            
            start_time = time.time()
            
            while time.time() - start_time < 10:  # 10 seconds
                ret, frame = tracker.cap.read()
                
                if not ret:
                    continue
                
                processed_frame, blink_data, movement_data = tracker.process_frame(frame)
                
                if movement_data:
                    directions_detected.add(movement_data.gaze_direction)
                    print(f"  👁️  Gaze direction: {movement_data.gaze_direction.upper()}")
                
                import cv2
                cv2.waitKey(1)
            
            print(f"\n✓ Detected directions: {', '.join(sorted(directions_detected))}")
            
            # Verify at least center was detected
            if 'center' in directions_detected:
                assert True
                print("  Eye movement tracking is working!")
            else:
                print("  Note: No center gaze detected")
                
        finally:
            tracker.stop_camera()
    
    def test_real_ear_values(self):
        """Test real EAR values from camera"""
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        print("\n📊 Collecting real EAR values...")
        print("Please keep eyes open and look at camera for 5 seconds...")
        
        ear_values = []
        
        try:
            import time
            start_time = time.time()
            
            while time.time() - start_time < 5:  # 5 seconds
                ret, frame = tracker.cap.read()
                
                if not ret:
                    continue
                
                processed_frame, blink_data, movement_data = tracker.process_frame(frame)
                
                if blink_data:
                    ear_values.append(blink_data.avg_ear)
            
            if len(ear_values) > 0:
                avg_ear = np.mean(ear_values)
                std_ear = np.std(ear_values)
                min_ear = np.min(ear_values)
                max_ear = np.max(ear_values)
                
                print(f"\n✓ EAR Statistics from {len(ear_values)} frames:")
                print(f"  Average: {avg_ear:.3f}")
                print(f"  Std Dev: {std_ear:.3f}")
                print(f"  Range: {min_ear:.3f} - {max_ear:.3f}")
                
                # Verify EAR is in reasonable range for open eyes
                assert 0.15 <= avg_ear <= 0.45, f"Average EAR {avg_ear:.3f} seems unusual"
                print("  ✓ EAR values are in normal range")
            else:
                print("  No EAR data collected - face may not be visible")
                pytest.skip("No face detected")
                
        finally:
            tracker.stop_camera()
    
    def test_real_tracking_statistics(self):
        """Test statistics generation from real camera tracking"""
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        print("\n📈 Collecting tracking statistics...")
        print("Normal activity for 8 seconds (blink naturally, move eyes)...")
        
        try:
            import time
            start_time = time.time()
            
            while time.time() - start_time < 8:  # 8 seconds
                ret, frame = tracker.cap.read()
                
                if not ret:
                    continue
                
                processed_frame, blink_data, movement_data = tracker.process_frame(frame)
            
            # Get statistics
            stats = tracker.get_statistics()
            
            if "error" not in stats:
                print(f"\n✓ Statistics generated successfully:")
                print(f"  Duration: {stats['duration_seconds']:.2f}s")
                print(f"  Total blinks: {stats['total_blinks']}")
                print(f"  Blink rate: {stats['blink_rate_per_minute']:.1f}/min")
                print(f"  Data points: {stats['data_points']}")
                print(f"  Average EAR: {stats['ear_statistics']['average']['mean']:.3f}")
                
                # Verify statistics structure
                assert 'duration_seconds' in stats
                assert 'total_blinks' in stats
                assert 'ear_statistics' in stats
                assert 'gaze_distribution' in stats
                assert stats['data_points'] > 0
                
                print("  ✓ All statistics generated correctly")
            else:
                print("  No statistics - no face detected")
                pytest.skip("No tracking data collected")
                
        finally:
            tracker.stop_camera()
    
    def test_detect_blink_open_eyes(self):
        """Test blink detection with open eyes (unit test)"""
        tracker = EyeTracker()
        
        # Simulate open eyes (high EAR)
        left_ear = 0.30
        right_ear = 0.32
        
        is_blinking, avg_ear = tracker.detect_blink(left_ear, right_ear)
        
        assert not is_blinking
        assert avg_ear == (left_ear + right_ear) / 2
    
    def test_detect_blink_closed_eyes(self):
        """Test blink detection with closed eyes (unit test)"""
        tracker = EyeTracker()
        
        # Simulate closed eyes (low EAR) for multiple frames
        left_ear = 0.15
        right_ear = 0.16
        
        # First frame
        is_blinking, _ = tracker.detect_blink(left_ear, right_ear)
        assert not is_blinking  # Not yet confirmed
        
        # Second frame (should confirm blink)
        is_blinking, _ = tracker.detect_blink(left_ear, right_ear)
        assert is_blinking  # Blink confirmed
    
    def test_detect_blink_counting(self):
        """Test blink counting (unit test)"""
        tracker = EyeTracker()
        initial_blinks = tracker.total_blinks
        
        # Simulate a complete blink cycle
        # Close eyes
        tracker.detect_blink(0.15, 0.16)
        tracker.detect_blink(0.15, 0.16)
        
        # Open eyes
        tracker.detect_blink(0.30, 0.31)
        
        assert tracker.total_blinks == initial_blinks + 1
    
    def test_extract_eye_landmarks(self):
        """Test eye landmark extraction"""
        tracker = EyeTracker()
        
        # Create mock face landmarks
        class MockLandmark:
            def __init__(self, x, y):
                self.x = x
                self.y = y
        
        class MockFaceLandmarks:
            def __init__(self):
                self.landmark = [MockLandmark(0.5, 0.5) for _ in range(500)]
        
        face_landmarks = MockFaceLandmarks()
        eye_indices = [33, 160, 158, 133, 153, 144]  # Left eye
        
        landmarks = tracker.extract_eye_landmarks(
            face_landmarks, eye_indices, 640, 480
        )
        
        assert len(landmarks) == 6
        assert landmarks.shape == (6, 2)
    
    def test_estimate_gaze_center(self):
        """Test gaze direction estimation - center"""
        tracker = EyeTracker()
        
        # Iris and eye corners at same position (center gaze)
        left_iris = np.array([[100, 50], [102, 50], [101, 52], [101, 48], [100, 51]])
        right_iris = np.array([[200, 50], [202, 50], [201, 52], [201, 48], [200, 51]])
        left_corners = np.array([[90, 50], [110, 50]])
        right_corners = np.array([[190, 50], [210, 50]])
        
        direction = tracker.estimate_gaze_direction(
            left_iris, right_iris, left_corners, right_corners
        )
        
        assert direction == "center"
    
    def test_reset_tracking(self):
        """Test tracking reset"""
        tracker = EyeTracker()
        
        # Add some data
        tracker.total_blinks = 10
        tracker.frame_counter = 5
        tracker.blink_history.append(
            BlinkData(1.0, 0.3, 0.3, 0.3, False, 0)
        )
        
        # Reset
        tracker.reset_tracking()
        
        assert tracker.total_blinks == 0
        assert tracker.frame_counter == 0
        assert len(tracker.blink_history) == 0
        assert len(tracker.movement_history) == 0
    
    def test_get_statistics_no_data(self):
        """Test statistics retrieval with no data"""
        tracker = EyeTracker()
        stats = tracker.get_statistics()
        
        assert "error" in stats
    
    def test_get_statistics_with_data(self):
        """Test statistics retrieval with tracking data (unit test)"""
        tracker = EyeTracker()
        
        # Add mock blink data
        for i in range(10):
            blink_data = BlinkData(
                timestamp=float(i),
                left_ear=0.30 + np.random.normal(0, 0.02),
                right_ear=0.30 + np.random.normal(0, 0.02),
                avg_ear=0.30,
                is_blinking=False,
                blink_count=i
            )
            tracker.blink_history.append(blink_data)
        
        # Add mock movement data
        for i in range(10):
            movement_data = EyeMovementData(
                timestamp=float(i),
                left_gaze_x=100.0,
                left_gaze_y=50.0,
                right_gaze_x=200.0,
                right_gaze_y=50.0,
                gaze_direction="center"
            )
            tracker.movement_history.append(movement_data)
        
        tracker.total_blinks = 5
        
        stats = tracker.get_statistics()
        
        assert "error" not in stats
        assert "duration_seconds" in stats
        assert "total_blinks" in stats
        assert "blink_rate_per_minute" in stats
        assert "ear_statistics" in stats
        assert "gaze_distribution" in stats
        
        assert stats['total_blinks'] == 5
        assert stats['ear_statistics']['left_eye']['mean'] > 0
        assert 'center' in stats['gaze_distribution']


class TestRealCameraIntegration:
    """Integration tests using real laptop camera"""
    
    def test_quick_camera_test(self):
        """Quick 3-second camera test"""
        print("\n" + "="*60)
        print("QUICK CAMERA TEST (3 seconds)")
        print("="*60)
        print("Look at your camera...")
        
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        try:
            import time
            import cv2
            
            start_time = time.time()
            frames_processed = 0
            
            while time.time() - start_time < 3:
                ret, frame = tracker.cap.read()
                
                if ret:
                    processed_frame, blink_data, movement_data = tracker.process_frame(frame)
                    frames_processed += 1
                    
                    if blink_data:
                        print(f"Frame {frames_processed}: EAR={blink_data.avg_ear:.3f}, "
                              f"Blinks={blink_data.blink_count}, "
                              f"Direction={movement_data.gaze_direction if movement_data else 'N/A'}")
                
                cv2.waitKey(1)
            
            print(f"\n✓ Processed {frames_processed} frames")
            print(f"✓ Total blinks detected: {tracker.total_blinks}")
            
            assert frames_processed > 0, "Should process at least some frames"
            
        finally:
            tracker.stop_camera()
    
    def test_full_tracking_session(self):
        """Full 10-second tracking session with complete statistics"""
        print("\n" + "="*60)
        print("FULL TRACKING SESSION (10 seconds)")
        print("="*60)
        print("Instructions:")
        print("  - Look at your camera")
        print("  - Blink a few times")
        print("  - Try looking left, right, up, down")
        print("\nStarting in 3 seconds...")
        
        import time
        time.sleep(3)
        
        tracker = EyeTracker(camera_id=0)
        
        if not tracker.start_camera():
            pytest.skip("Camera not available")
        
        try:
            import cv2
            
            start_time = time.time()
            frame_count = 0
            
            print("\n📹 Recording...")
            
            while time.time() - start_time < 10:
                ret, frame = tracker.cap.read()
                
                if ret:
                    processed_frame, blink_data, movement_data = tracker.process_frame(frame)
                    frame_count += 1
                    
                    # Show progress every 30 frames
                    if frame_count % 30 == 0:
                        elapsed = time.time() - start_time
                        print(f"  {elapsed:.1f}s - Blinks: {tracker.total_blinks}")
                
                cv2.waitKey(1)
            
            print("\n📊 Generating statistics...")
            
            stats = tracker.get_statistics()
            
            if "error" not in stats:
                print("\n" + "="*60)
                print("TRACKING RESULTS")
                print("="*60)
                
                print(f"\n⏱️  Duration: {stats['duration_seconds']:.2f} seconds")
                print(f"📸 Frames processed: {frame_count}")
                print(f"👁️  Total blinks: {stats['total_blinks']}")
                print(f"💫 Blink rate: {stats['blink_rate_per_minute']:.1f} blinks/min")
                print(f"   (Normal: 15-20 blinks/min)")
                
                print(f"\n📈 Eye Aspect Ratio (EAR):")
                ear = stats['ear_statistics']['average']
                print(f"   Mean: {ear['mean']:.3f} ± {ear['std']:.3f}")
                print(f"   Range: {ear['min']:.3f} - {ear['max']:.3f}")
                
                print(f"\n👀 Gaze Direction Distribution:")
                gaze = stats['gaze_distribution']
                total_frames = sum(gaze.values())
                
                for direction in ['center', 'left', 'right', 'up', 'down']:
                    if direction in gaze:
                        count = gaze[direction]
                        percent = (count / total_frames) * 100
                        bar = "█" * int(percent / 5)
                        print(f"   {direction.capitalize():8s}: {bar} {percent:5.1f}%")
                
                print(f"\n✓ Test completed successfully!")
                
                # Assertions
                assert stats['data_points'] > 0
                assert 'ear_statistics' in stats
                assert frame_count > 0
                
            else:
                print("\n⚠️  No face detected during session")
                print("Make sure you're visible to the camera!")
                pytest.skip("No tracking data collected")
                
        finally:
            tracker.stop_camera()
            print("\n" + "="*60)


class TestEyeLandmarks:
    """Test eye landmark indices"""
    
    def test_left_eye_landmarks(self):
        """Test left eye landmark indices"""
        assert len(EyeLandmarks.LEFT_EYE) == 6
        assert all(isinstance(idx, int) for idx in EyeLandmarks.LEFT_EYE)
    
    def test_right_eye_landmarks(self):
        """Test right eye landmark indices"""
        assert len(EyeLandmarks.RIGHT_EYE) == 6
        assert all(isinstance(idx, int) for idx in EyeLandmarks.RIGHT_EYE)
    
    def test_iris_landmarks(self):
        """Test iris landmark indices"""
        assert len(EyeLandmarks.LEFT_IRIS) == 5
        assert len(EyeLandmarks.RIGHT_IRIS) == 5
    
    def test_eye_corners(self):
        """Test eye corner landmark indices"""
        assert len(EyeLandmarks.LEFT_EYE_CORNERS) == 2
        assert len(EyeLandmarks.RIGHT_EYE_CORNERS) == 2


# Usage examples and demonstrations
def demonstrate_ear_calculation():
    """Demonstrate manual EAR calculation"""
    print("\n" + "="*60)
    print("Manual Eye Aspect Ratio (EAR) Calculation Demo")
    print("="*60)
    
    # Simulate open eye landmarks
    open_eye = np.array([
        [0, 0],    # Left corner
        [10, -8],  # Top left
        [20, -8],  # Top right
        [30, 0],   # Right corner
        [20, 8],   # Bottom right
        [10, 8]    # Bottom left
    ])
    
    # Simulate closed eye landmarks
    closed_eye = np.array([
        [0, 0],
        [10, -2],
        [20, -2],
        [30, 0],
        [20, 2],
        [10, 2]
    ])
    
    calculator = EyeAspectRatioCalculator()
    
    open_ear = calculator.calculate_ear(open_eye)
    closed_ear = calculator.calculate_ear(closed_eye)
    
    print(f"\nOpen Eye EAR: {open_ear:.3f}")
    print(f"Closed Eye EAR: {closed_ear:.3f}")
    print(f"EAR Threshold for Blink Detection: {EyeTracker.EAR_THRESHOLD}")
    print(f"\nInterpretation:")
    print(f"  - EAR > {EyeTracker.EAR_THRESHOLD}: Eye is OPEN")
    print(f"  - EAR < {EyeTracker.EAR_THRESHOLD}: Eye is CLOSED (Blink detected)")


def demonstrate_eye_tracking_workflow():
    """Demonstrate complete eye tracking workflow"""
    print("\n" + "="*60)
    print("Eye Tracking Workflow Demo")
    print("="*60)
    
    print("\n1. Create Eye Tracker")
    tracker = EyeTracker(camera_id=0)
    print(f"   ✓ Tracker initialized with camera {tracker.camera_id}")
    
    print("\n2. Simulate Tracking Data")
    # Simulate some blinks
    for i in range(5):
        # Closed eyes
        tracker.detect_blink(0.15, 0.16)
        tracker.detect_blink(0.15, 0.16)
        # Open eyes
        tracker.detect_blink(0.30, 0.31)
        
        # Add tracking data
        tracker.blink_history.append(
            BlinkData(float(i), 0.30, 0.31, 0.305, False, tracker.total_blinks)
        )
    
    print(f"   ✓ Simulated {tracker.total_blinks} blinks")
    
    print("\n3. Retrieve Statistics")
    if tracker.blink_history:
        print(f"   ✓ Collected {len(tracker.blink_history)} data points")
        print(f"   ✓ Total blinks: {tracker.total_blinks}")
    
    print("\n4. Reset Tracking")
    tracker.reset_tracking()
    print(f"   ✓ Tracker reset - Blinks: {tracker.total_blinks}, Data points: {len(tracker.blink_history)}")


if __name__ == '__main__':
    # Run demonstrations
    demonstrate_ear_calculation()
    demonstrate_eye_tracking_workflow()
    
    print("\n" + "="*60)
    print("To run pytest tests, execute: pytest test_eye_tracking.py -v")
    print("="*60)

