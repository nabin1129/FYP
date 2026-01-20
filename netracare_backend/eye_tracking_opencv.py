"""
Eye Tracking Module using OpenCV and MediaPipe
- Facial landmark detection using MediaPipe Face Mesh
- Manual Eye Aspect Ratio (EAR) calculation for blink detection
- Eye movement tracking and gaze estimation
"""

import cv2
import numpy as np
from typing import Tuple, List, Dict, Optional
from dataclasses import dataclass
from datetime import datetime
import math

# Import MediaPipe
import mediapipe as mp


@dataclass
class EyeLandmarks:
    """Store eye landmark indices for MediaPipe Face Mesh"""
    # Left eye landmarks (6 points)
    LEFT_EYE = [33, 160, 158, 133, 153, 144]
    # Right eye landmarks (6 points)
    RIGHT_EYE = [362, 385, 387, 263, 373, 380]
    
    # Iris landmarks for gaze estimation
    LEFT_IRIS = [468, 469, 470, 471, 472]
    RIGHT_IRIS = [473, 474, 475, 476, 477]
    
    # Eye corners for movement tracking
    LEFT_EYE_CORNERS = [33, 133]  # outer, inner corner
    RIGHT_EYE_CORNERS = [362, 263]  # outer, inner corner


@dataclass
class BlinkData:
    """Store blink detection data"""
    timestamp: float
    left_ear: float
    right_ear: float
    avg_ear: float
    is_blinking: bool
    blink_count: int


@dataclass
class EyeMovementData:
    """Store eye movement data"""
    timestamp: float
    left_gaze_x: float
    left_gaze_y: float
    right_gaze_x: float
    right_gaze_y: float
    gaze_direction: str  # 'center', 'left', 'right', 'up', 'down'


class EyeAspectRatioCalculator:
    """Calculate Eye Aspect Ratio (EAR) manually"""
    
    @staticmethod
    def calculate_distance(point1: np.ndarray, point2: np.ndarray) -> float:
        """Calculate Euclidean distance between two points"""
        return np.linalg.norm(point1 - point2)
    
    @staticmethod
    def calculate_ear(eye_landmarks: np.ndarray) -> float:
        """
        Calculate Eye Aspect Ratio (EAR)
        
        EAR Formula:
        EAR = (||p2 - p6|| + ||p3 - p5||) / (2 * ||p1 - p4||)
        
        Where:
        - p1, p4 are horizontal eye corners (left and right)
        - p2, p3, p5, p6 are vertical eye landmarks (top and bottom pairs)
        
        Args:
            eye_landmarks: Array of 6 eye landmark points [(x, y), ...]
            
        Returns:
            float: Eye Aspect Ratio value
        """
        if len(eye_landmarks) != 6:
            raise ValueError("Eye landmarks must contain exactly 6 points")
        
        # Vertical distances (2 pairs)
        vertical_1 = EyeAspectRatioCalculator.calculate_distance(
            eye_landmarks[1], eye_landmarks[5]
        )
        vertical_2 = EyeAspectRatioCalculator.calculate_distance(
            eye_landmarks[2], eye_landmarks[4]
        )
        
        # Horizontal distance
        horizontal = EyeAspectRatioCalculator.calculate_distance(
            eye_landmarks[0], eye_landmarks[3]
        )
        
        # Calculate EAR
        if horizontal == 0:
            return 0.0
        
        ear = (vertical_1 + vertical_2) / (2.0 * horizontal)
        return ear


class EyeTracker:
    """Main eye tracking class using OpenCV and MediaPipe"""
    
    # EAR threshold for blink detection
    EAR_THRESHOLD = 0.21
    
    # Consecutive frames for blink confirmation
    EAR_CONSEC_FRAMES = 2
    
    def __init__(self, camera_id: int = 0):
        """
        Initialize Eye Tracker
        
        Args:
            camera_id: Camera device ID (default: 0)
        """
        self.camera_id = camera_id
        self.cap = None
        
        # Initialize MediaPipe Face Mesh
        self.mp_face_mesh = mp.solutions.face_mesh
        self.face_mesh = self.mp_face_mesh.FaceMesh(
            max_num_faces=1,
            refine_landmarks=True,  # Enable iris landmarks
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # Drawing utilities
        self.mp_drawing = mp.solutions.drawing_utils
        self.mp_drawing_styles = mp.solutions.drawing_styles
        
        # Tracking variables
        self.blink_counter = 0
        self.total_blinks = 0
        self.frame_counter = 0
        
        # Data storage
        self.blink_history: List[BlinkData] = []
        self.movement_history: List[EyeMovementData] = []
        
        # EAR calculator
        self.ear_calculator = EyeAspectRatioCalculator()
        
    def start_camera(self) -> bool:
        """Start camera capture"""
        self.cap = cv2.VideoCapture(self.camera_id)
        if not self.cap.isOpened():
            print(f"Error: Could not open camera {self.camera_id}")
            return False
        return True
    
    def stop_camera(self):
        """Stop camera capture and release resources"""
        if self.cap:
            self.cap.release()
        cv2.destroyAllWindows()
        self.face_mesh.close()
    
    def extract_eye_landmarks(self, face_landmarks, eye_indices: List[int], 
                            image_width: int, image_height: int) -> np.ndarray:
        """
        Extract eye landmarks from face mesh
        
        Args:
            face_landmarks: MediaPipe face landmarks
            eye_indices: List of landmark indices for the eye
            image_width: Width of the image
            image_height: Height of the image
            
        Returns:
            np.ndarray: Array of eye landmark coordinates
        """
        landmarks = []
        for idx in eye_indices:
            landmark = face_landmarks.landmark[idx]
            x = int(landmark.x * image_width)
            y = int(landmark.y * image_height)
            landmarks.append(np.array([x, y]))
        
        return np.array(landmarks)
    
    def detect_blink(self, left_ear: float, right_ear: float) -> Tuple[bool, float]:
        """
        Detect blink based on EAR values
        
        Args:
            left_ear: Left eye EAR value
            right_ear: Right eye EAR value
            
        Returns:
            Tuple[bool, float]: (is_blinking, average_ear)
        """
        avg_ear = (left_ear + right_ear) / 2.0
        
        # Check if EAR is below threshold
        if avg_ear < self.EAR_THRESHOLD:
            self.frame_counter += 1
        else:
            # If eyes were closed for sufficient frames, register a blink
            if self.frame_counter >= self.EAR_CONSEC_FRAMES:
                self.total_blinks += 1
            self.frame_counter = 0
        
        is_blinking = self.frame_counter >= self.EAR_CONSEC_FRAMES
        
        return is_blinking, avg_ear
    
    def estimate_gaze_direction(self, left_iris: np.ndarray, right_iris: np.ndarray,
                               left_eye_corners: np.ndarray, 
                               right_eye_corners: np.ndarray) -> str:
        """
        Estimate gaze direction based on iris position
        
        Args:
            left_iris: Left iris center coordinates
            right_iris: Right iris center coordinates
            left_eye_corners: Left eye corner coordinates
            right_eye_corners: Right eye corner coordinates
            
        Returns:
            str: Gaze direction ('center', 'left', 'right', 'up', 'down')
        """
        # Calculate iris center
        left_iris_center = np.mean(left_iris, axis=0)
        right_iris_center = np.mean(right_iris, axis=0)
        
        # Calculate eye center
        left_eye_center = np.mean(left_eye_corners, axis=0)
        right_eye_center = np.mean(right_eye_corners, axis=0)
        
        # Calculate relative position
        left_offset_x = left_iris_center[0] - left_eye_center[0]
        left_offset_y = left_iris_center[1] - left_eye_center[1]
        
        right_offset_x = right_iris_center[0] - right_eye_center[0]
        right_offset_y = right_iris_center[1] - right_eye_center[1]
        
        # Average offsets
        avg_offset_x = (left_offset_x + right_offset_x) / 2
        avg_offset_y = (left_offset_y + right_offset_y) / 2
        
        # Thresholds for direction detection
        horizontal_threshold = 5
        vertical_threshold = 3
        
        # Determine direction
        if abs(avg_offset_x) < horizontal_threshold and abs(avg_offset_y) < vertical_threshold:
            return "center"
        elif avg_offset_x < -horizontal_threshold:
            return "left"
        elif avg_offset_x > horizontal_threshold:
            return "right"
        elif avg_offset_y < -vertical_threshold:
            return "up"
        elif avg_offset_y > vertical_threshold:
            return "down"
        else:
            return "center"
    
    def process_frame(self, frame: np.ndarray) -> Tuple[np.ndarray, Optional[BlinkData], 
                                                        Optional[EyeMovementData]]:
        """
        Process a single frame for eye tracking
        
        Args:
            frame: Input frame from camera
            
        Returns:
            Tuple[np.ndarray, Optional[BlinkData], Optional[EyeMovementData]]:
                Processed frame with annotations, blink data, eye movement data
        """
        # Convert to RGB for MediaPipe
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Process frame with Face Mesh
        results = self.face_mesh.process(rgb_frame)
        
        blink_data = None
        movement_data = None
        
        if results.multi_face_landmarks:
            face_landmarks = results.multi_face_landmarks[0]
            
            h, w, _ = frame.shape
            
            # Extract eye landmarks
            left_eye = self.extract_eye_landmarks(
                face_landmarks, EyeLandmarks.LEFT_EYE, w, h
            )
            right_eye = self.extract_eye_landmarks(
                face_landmarks, EyeLandmarks.RIGHT_EYE, w, h
            )
            
            # Calculate EAR for both eyes
            left_ear = self.ear_calculator.calculate_ear(left_eye)
            right_ear = self.ear_calculator.calculate_ear(right_eye)
            
            # Detect blinks
            is_blinking, avg_ear = self.detect_blink(left_ear, right_ear)
            
            # Store blink data
            timestamp = datetime.now().timestamp()
            blink_data = BlinkData(
                timestamp=timestamp,
                left_ear=left_ear,
                right_ear=right_ear,
                avg_ear=avg_ear,
                is_blinking=is_blinking,
                blink_count=self.total_blinks
            )
            
            # Extract iris landmarks for gaze estimation
            left_iris = self.extract_eye_landmarks(
                face_landmarks, EyeLandmarks.LEFT_IRIS, w, h
            )
            right_iris = self.extract_eye_landmarks(
                face_landmarks, EyeLandmarks.RIGHT_IRIS, w, h
            )
            
            # Extract eye corners
            left_corners = self.extract_eye_landmarks(
                face_landmarks, EyeLandmarks.LEFT_EYE_CORNERS, w, h
            )
            right_corners = self.extract_eye_landmarks(
                face_landmarks, EyeLandmarks.RIGHT_EYE_CORNERS, w, h
            )
            
            # Estimate gaze direction
            gaze_direction = self.estimate_gaze_direction(
                left_iris, right_iris, left_corners, right_corners
            )
            
            # Calculate gaze coordinates (iris centers)
            left_iris_center = np.mean(left_iris, axis=0)
            right_iris_center = np.mean(right_iris, axis=0)
            
            # Store movement data
            movement_data = EyeMovementData(
                timestamp=timestamp,
                left_gaze_x=float(left_iris_center[0]),
                left_gaze_y=float(left_iris_center[1]),
                right_gaze_x=float(right_iris_center[0]),
                right_gaze_y=float(right_iris_center[1]),
                gaze_direction=gaze_direction
            )
            
            # Draw eye landmarks on frame
            for landmark in left_eye:
                cv2.circle(frame, tuple(landmark), 2, (0, 255, 0), -1)
            
            for landmark in right_eye:
                cv2.circle(frame, tuple(landmark), 2, (0, 255, 0), -1)
            
            # Draw iris
            for landmark in left_iris:
                cv2.circle(frame, tuple(landmark), 1, (255, 0, 0), -1)
            
            for landmark in right_iris:
                cv2.circle(frame, tuple(landmark), 1, (255, 0, 0), -1)
            
            # Display EAR values
            cv2.putText(frame, f"Left EAR: {left_ear:.2f}", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            cv2.putText(frame, f"Right EAR: {right_ear:.2f}", (10, 60),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            cv2.putText(frame, f"Avg EAR: {avg_ear:.2f}", (10, 90),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
            
            # Display blink status
            blink_text = "BLINKING" if is_blinking else "Eyes Open"
            blink_color = (0, 0, 255) if is_blinking else (0, 255, 0)
            cv2.putText(frame, blink_text, (10, 120),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, blink_color, 2)
            
            # Display blink count
            cv2.putText(frame, f"Blinks: {self.total_blinks}", (10, 150),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 0), 2)
            
            # Display gaze direction
            cv2.putText(frame, f"Gaze: {gaze_direction.upper()}", (10, 180),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 255), 2)
        
        return frame, blink_data, movement_data
    
    def run_live_tracking(self, duration: Optional[int] = None):
        """
        Run live eye tracking
        
        Args:
            duration: Optional duration in seconds (None for continuous)
        """
        if not self.start_camera():
            return
        
        print("Eye Tracking Started. Press 'q' to quit.")
        
        start_time = datetime.now()
        
        try:
            while True:
                ret, frame = self.cap.read()
                if not ret:
                    print("Failed to grab frame")
                    break
                
                # Process frame
                processed_frame, blink_data, movement_data = self.process_frame(frame)
                
                # Store data
                if blink_data:
                    self.blink_history.append(blink_data)
                if movement_data:
                    self.movement_history.append(movement_data)
                
                # Display frame
                cv2.imshow('Eye Tracking - Press Q to quit', processed_frame)
                
                # Check duration
                if duration:
                    elapsed = (datetime.now() - start_time).total_seconds()
                    if elapsed >= duration:
                        break
                
                # Check for quit
                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
        
        finally:
            self.stop_camera()
    
    def get_statistics(self) -> Dict:
        """
        Get tracking statistics
        
        Returns:
            Dict: Statistics including blink rate, EAR averages, gaze patterns
        """
        if not self.blink_history:
            return {"error": "No tracking data available"}
        
        # Calculate time span
        start_time = self.blink_history[0].timestamp
        end_time = self.blink_history[-1].timestamp
        duration = end_time - start_time
        
        # Blink statistics
        blink_rate = (self.total_blinks / duration) * 60 if duration > 0 else 0
        
        # EAR statistics
        left_ears = [data.left_ear for data in self.blink_history]
        right_ears = [data.right_ear for data in self.blink_history]
        avg_ears = [data.avg_ear for data in self.blink_history]
        
        # Gaze direction statistics
        gaze_directions = [data.gaze_direction for data in self.movement_history]
        gaze_counts = {}
        for direction in gaze_directions:
            gaze_counts[direction] = gaze_counts.get(direction, 0) + 1
        
        return {
            "duration_seconds": round(duration, 2),
            "total_blinks": self.total_blinks,
            "blink_rate_per_minute": round(blink_rate, 2),
            "ear_statistics": {
                "left_eye": {
                    "mean": round(np.mean(left_ears), 3),
                    "std": round(np.std(left_ears), 3),
                    "min": round(np.min(left_ears), 3),
                    "max": round(np.max(left_ears), 3)
                },
                "right_eye": {
                    "mean": round(np.mean(right_ears), 3),
                    "std": round(np.std(right_ears), 3),
                    "min": round(np.min(right_ears), 3),
                    "max": round(np.max(right_ears), 3)
                },
                "average": {
                    "mean": round(np.mean(avg_ears), 3),
                    "std": round(np.std(avg_ears), 3),
                    "min": round(np.min(avg_ears), 3),
                    "max": round(np.max(avg_ears), 3)
                }
            },
            "gaze_distribution": gaze_counts,
            "data_points": len(self.blink_history)
        }
    
    def reset_tracking(self):
        """Reset all tracking counters and history"""
        self.blink_counter = 0
        self.total_blinks = 0
        self.frame_counter = 0
        self.blink_history.clear()
        self.movement_history.clear()


def main():
    """Main function to run eye tracking demo"""
    print("=" * 50)
    print("Eye Tracking with OpenCV and MediaPipe")
    print("Manual Eye Aspect Ratio (EAR) Calculation")
    print("=" * 50)
    print()
    
    # Create eye tracker instance
    tracker = EyeTracker(camera_id=0)
    
    # Run live tracking (30 seconds demo)
    print("Starting 30-second tracking session...")
    tracker.run_live_tracking(duration=30)
    
    # Get and display statistics
    print("\n" + "=" * 50)
    print("Tracking Statistics:")
    print("=" * 50)
    
    stats = tracker.get_statistics()
    
    if "error" not in stats:
        print(f"\nDuration: {stats['duration_seconds']} seconds")
        print(f"Total Blinks: {stats['total_blinks']}")
        print(f"Blink Rate: {stats['blink_rate_per_minute']:.2f} blinks/minute")
        
        print("\nEye Aspect Ratio (EAR) Statistics:")
        print(f"  Left Eye - Mean: {stats['ear_statistics']['left_eye']['mean']:.3f}, "
              f"Std: {stats['ear_statistics']['left_eye']['std']:.3f}")
        print(f"  Right Eye - Mean: {stats['ear_statistics']['right_eye']['mean']:.3f}, "
              f"Std: {stats['ear_statistics']['right_eye']['std']:.3f}")
        print(f"  Average - Mean: {stats['ear_statistics']['average']['mean']:.3f}, "
              f"Std: {stats['ear_statistics']['average']['std']:.3f}")
        
        print("\nGaze Direction Distribution:")
        for direction, count in stats['gaze_distribution'].items():
            percentage = (count / stats['data_points']) * 100
            print(f"  {direction.capitalize()}: {count} ({percentage:.1f}%)")
    else:
        print(stats['error'])


if __name__ == "__main__":
    main()
