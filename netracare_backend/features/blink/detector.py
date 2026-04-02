"""
Eye Blink Detection using Eye Aspect Ratio (EAR)
Based on Soukupová and Čech's research paper
"""
import cv2
import numpy as np
from scipy.spatial import distance as dist

class BlinkDetector:
    """Detects eye blinks using facial landmarks"""
    
    # Facial landmark indices for eyes (dlib 68-point model)
    LEFT_EYE = list(range(36, 42))
    RIGHT_EYE = list(range(42, 48))
    
    # EAR threshold and consecutive frames
    EAR_THRESHOLD = 0.25
    CONSEC_FRAMES = 2
    
    def __init__(self):
        self.blink_counter = 0
        self.frame_counter = 0
        self.total_blinks = 0
        
    @staticmethod
    def eye_aspect_ratio(eye_landmarks):
        """
        Calculate Eye Aspect Ratio (EAR)
        EAR = (||p2-p6|| + ||p3-p5||) / (2 * ||p1-p4||)
        
        Args:
            eye_landmarks: Array of 6 (x, y) coordinates for eye
            
        Returns:
            float: EAR value
        """
        # Vertical eye landmarks
        A = dist.euclidean(eye_landmarks[1], eye_landmarks[5])
        B = dist.euclidean(eye_landmarks[2], eye_landmarks[4])
        
        # Horizontal eye landmark
        C = dist.euclidean(eye_landmarks[0], eye_landmarks[3])
        
        # EAR calculation
        ear = (A + B) / (2.0 * C)
        return ear
    
    def detect_blink(self, left_eye, right_eye):
        """
        Detect blink based on EAR of both eyes
        
        Args:
            left_eye: Left eye landmarks
            right_eye: Right eye landmarks
            
        Returns:
            tuple: (is_blinking, blink_detected)
        """
        # Calculate EAR for both eyes
        left_ear = self.eye_aspect_ratio(left_eye)
        right_ear = self.eye_aspect_ratio(right_eye)
        
        # Average EAR
        avg_ear = (left_ear + right_ear) / 2.0
        
        # Check if EAR is below threshold (eyes closed)
        if avg_ear < self.EAR_THRESHOLD:
            self.frame_counter += 1
            is_blinking = True
            return is_blinking, False
        else:
            # If eyes were closed for sufficient frames, count as blink
            if self.frame_counter >= self.CONSEC_FRAMES:
                self.total_blinks += 1
                blink_detected = True
                self.frame_counter = 0
                return False, blink_detected
            
            self.frame_counter = 0
            is_blinking = False
            return is_blinking, False
    
    def get_blink_count(self):
        """Get total blinks detected"""
        return self.total_blinks
    
    def reset(self):
        """Reset blink counter"""
        self.blink_counter = 0
        self.frame_counter = 0
        self.total_blinks = 0
