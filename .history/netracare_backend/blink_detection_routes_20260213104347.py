"""
Routes for real-time blink detection with EAR calculation
"""
from flask import request
from flask_restx import Namespace, Resource, fields
from db_model import db, BlinkFatigueTest
from auth_utils import token_required
import base64
import cv2
import numpy as np
import io
from PIL import Image

# Create namespace
blink_detection_ns = Namespace('blink-detection', description='Real-time blink detection operations')

# API Models
frame_analysis_model = blink_detection_ns.model('FrameAnalysis', {
    'success': fields.Boolean(description='Analysis successful'),
    'ear': fields.Float(description='Eye Aspect Ratio'),
    'is_blink': fields.Boolean(description='Whether blink detected'),
    'left_ear': fields.Float(description='Left eye EAR'),
    'right_ear': fields.Float(description='Right eye EAR'),
    'message': fields.String(description='Status message')
})

test_submission_model = blink_detection_ns.model('BlinkTestSubmission', {
    'blink_count': fields.Integer(required=True, description='Total blinks counted'),
    'duration_seconds': fields.Integer(required=True, description='Test duration'),
    'drowsiness_probability': fields.Float(required=True, description='Drowsiness probability (0-1)'),
    'confidence_score': fields.Float(required=True, description='Confidence score (0-1)'),
    'fatigue_level': fields.String(description='Fatigue classification'),
})

test_response_model = blink_detection_ns.model('BlinkTestResponse', {
    'message': fields.String(description='Response message'),
    'test_id': fields.Integer(description='Created test ID'),
    'blink_count': fields.Integer(description='Total blinks'),
    'avg_bpm': fields.Float(description='Average blinks per minute'),
    'classification': fields.String(description='Fatigue classification')
})


# Try to import MediaPipe for face landmark detection (preferred method)
try:
    import mediapipe as mp
    from mediapipe.tasks import python
    from mediapipe.tasks.python import vision
    
    # Initialize FaceLandmarker
    base_options = python.BaseOptions(model_asset_path='face_landmarker.task')
    options = vision.FaceLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.IMAGE,
        num_faces=1,
        min_face_detection_confidence=0.5,
        min_face_presence_confidence=0.5,
        min_tracking_confidence=0.5
    )
    face_landmarker = vision.FaceLandmarker.create_from_options(options)
    MEDIAPIPE_AVAILABLE = True
    print("✓ MediaPipe FaceLandmarker loaded successfully for blink detection")
except FileNotFoundError:
    print("⚠️  MediaPipe model file 'face_landmarker.task' not found")
    print("   Download it from: https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task")
    MEDIAPIPE_AVAILABLE = False
    face_landmarker = None
except Exception as e:
    print(f"⚠️  MediaPipe not available: {e}")
    MEDIAPIPE_AVAILABLE = False
    face_landmarker = None

# Try to import dlib as fallback if available
try:
    import dlib
    detector = dlib.get_frontal_face_detector()
    predictor = dlib.shape_predictor("shape_predictor_68_face_landmarks.dat")
    DLIB_AVAILABLE = True
    print("✓ dlib loaded successfully")
except Exception as e:
    if not MEDIAPIPE_AVAILABLE:
        print(f"⚠️  dlib not available: {e}")
        print("   Blink detection will use basic fallback method")
    DLIB_AVAILABLE = False
    detector = None
    predictor = None

from blink_detector import BlinkDetector

# MediaPipe FaceLandmarker eye landmark indices (468 landmarks)
# Left eye: 362, 385, 387, 263, 373, 380 
# Right eye: 33, 160, 158, 133, 153, 144
LEFT_EYE_INDICES = [362, 385, 387, 263, 373, 380]
RIGHT_EYE_INDICES = [33, 160, 158, 133, 153, 144]

def calculate_ear_mediapipe(eye_landmarks):
    """Calculate Eye Aspect Ratio from MediaPipe landmarks
    Args:
        eye_landmarks: Array of 6 (x, y) points representing eye contour
    Returns:
        EAR value (float)
    """
    # Vertical distances
    v1 = np.linalg.norm(eye_landmarks[1] - eye_landmarks[5])
    v2 = np.linalg.norm(eye_landmarks[2] - eye_landmarks[4])
    # Horizontal distance
    h = np.linalg.norm(eye_landmarks[0] - eye_landmarks[3])
    # EAR formula
    if h == 0:
        return 0.0
    ear = (v1 + v2) / (2.0 * h)
    return ear


@blink_detection_ns.route('/analyze-frame')
class FrameAnalysis(Resource):
    """Analyze single frame for blink detection using EAR"""
    
    @blink_detection_ns.doc(security='Bearer')
    @blink_detection_ns.marshal_with(frame_analysis_model)
    @token_required
    def post(self, current_user):
        """
        Analyze camera frame for eye blink detection
        Calculates Eye Aspect Ratio (EAR) to detect blinks
        """
        try:
            data = request.get_json()
            image_data = data.get('image')
            
            if not image_data:
                return {
                    'success': False,
                    'message': 'No image provided',
                    'ear': 0.0,
                    'is_blink': False
                }, 400
            
            # Decode base64 image
            if ',' in image_data:
                image_data = image_data.split(',')[1]
            
            image_bytes = base64.b64decode(image_data)
            nparr = np.frombuffer(image_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                return {
                    'success': False,
                    'message': 'Invalid image format',
                    'ear': 0.0,
                    'is_blink': False
                }, 400
            
            # Convert to grayscale (for dlib fallback)
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # Try MediaPipe first (preferred method)
            if MEDIAPIPE_AVAILABLE:
                # Convert BGR to RGB for MediaPipe
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                results = face_mesh.process(rgb_frame)
                
                if results.multi_face_landmarks:
                    face_landmarks = results.multi_face_landmarks[0]
                    h, w = frame.shape[:2]
                    
                    # Extract left eye landmarks
                    left_eye_points = np.array([
                        [face_landmarks.landmark[i].x * w, face_landmarks.landmark[i].y * h]
                        for i in LEFT_EYE_INDICES
                    ])
                    
                    # Extract right eye landmarks
                    right_eye_points = np.array([
                        [face_landmarks.landmark[i].x * w, face_landmarks.landmark[i].y * h]
                        for i in RIGHT_EYE_INDICES
                    ])
                    
                    # Calculate EAR for both eyes
                    left_ear = calculate_ear_mediapipe(left_eye_points)
                    right_ear = calculate_ear_mediapipe(right_eye_points)
                    avg_ear = (left_ear + right_ear) / 2.0
                    
                    return {
                        'success': True,
                        'ear': float(avg_ear),
                        'is_blink': avg_ear < BlinkDetector.EAR_THRESHOLD,
                        'left_ear': float(left_ear),
                        'right_ear': float(right_ear),
                        'message': 'Frame analyzed with MediaPipe'
                    }, 200
                else:
                    # No face detected with MediaPipe, try dlib if available
                    if not DLIB_AVAILABLE:
                        return {
                            'success': False,
                            'message': 'No face detected',
                            'ear': 0.0,
                            'is_blink': False
                        }, 200
            
            # Use dlib as fallback if MediaPipe failed/unavailable
            if DLIB_AVAILABLE:
                # Use dlib for face detection
                faces = detector(gray, 0)
                
                if len(faces) == 0:
                    return {
                        'success': False,
                        'message': 'No face detected',
                        'ear': 0.0,
                        'is_blink': False
                    }, 200
                
                # Get facial landmarks for first face
                face = faces[0]
                landmarks = predictor(gray, face)
                landmarks_points = np.array([[p.x, p.y] for p in landmarks.parts()])
                
                # Extract eye landmarks
                left_eye = landmarks_points[BlinkDetector.LEFT_EYE]
                right_eye = landmarks_points[BlinkDetector.RIGHT_EYE]
                
                # Calculate EAR
                left_ear = BlinkDetector.eye_aspect_ratio(left_eye)
                right_ear = BlinkDetector.eye_aspect_ratio(right_eye)
                avg_ear = (left_ear + right_ear) / 2.0
                
                return {
                    'success': True,
                    'ear': float(avg_ear),
                    'is_blink': avg_ear < BlinkDetector.EAR_THRESHOLD,
                    'left_ear': float(left_ear),
                    'right_ear': float(right_ear),
                    'message': 'Frame analyzed with dlib'
                }, 200
            
            # Last resort: basic fallback heuristic
            # Simple brightness-based heuristic
            avg_brightness = np.mean(gray)
            # Simulate EAR based on brightness changes (closed eyes = darker)
            simulated_ear = avg_brightness / 255.0
            is_blink = simulated_ear < 0.3
            
            return {
                'success': True,
                'ear': float(simulated_ear),
                'is_blink': is_blink,
                'left_ear': float(simulated_ear),
                'right_ear': float(simulated_ear),
                'message': 'Using basic fallback detection'
            }, 200
            
        except Exception as e:
            return {
                'success': False,
                'message': f'Analysis failed: {str(e)}',
                'ear': 0.0,
                'is_blink': False
            }, 500


@blink_detection_ns.route('/submit')
class BlinkTestSubmission(Resource):
    """Submit complete blink & fatigue test results"""
    
    @blink_detection_ns.expect(test_submission_model)
    @blink_detection_ns.marshal_with(test_response_model)
    @blink_detection_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Submit blink and fatigue test results to database
        Stores comprehensive test metrics including blink rate
        """
        try:
            data = request.get_json()
            
            # Extract data
            blink_count = data.get('blink_count', 0)
            duration = data.get('duration_seconds', 40)
            drowsiness_prob = data.get('drowsiness_probability', 0.0)
            confidence = data.get('confidence_score', 0.0)
            fatigue_level = data.get('fatigue_level')
            
            # Calculate metrics
            avg_bpm = (blink_count / duration) * 60 if duration > 0 else 0
            
            # Determine classification if not provided
            if not fatigue_level:
                if drowsiness_prob > 0.6:
                    fatigue_level = 'High Fatigue'
                elif drowsiness_prob > 0.4:
                    fatigue_level = 'Moderate Fatigue'
                else:
                    fatigue_level = 'Alert'
            
            # Determine prediction class
            prediction = 'drowsy' if drowsiness_prob > 0.5 else 'notdrowsy'
            alert_triggered = drowsiness_prob > 0.7
            
            # Create test record
            test = BlinkFatigueTest(
                user_id=current_user.id,
                prediction=prediction,
                confidence=confidence,
                drowsy_probability=drowsiness_prob,
                notdrowsy_probability=1.0 - drowsiness_prob,
                fatigue_level=fatigue_level,
                alert_triggered=alert_triggered,
                test_duration=float(duration),
                total_blinks=blink_count,
                avg_blinks_per_minute=round(avg_bpm, 2)
            )
            
            db.session.add(test)
            db.session.commit()
            
            return {
                'message': 'Test results saved successfully',
                'test_id': test.id,
                'blink_count': blink_count,
                'avg_bpm': round(avg_bpm, 2),
                'classification': fatigue_level
            }, 201
            
        except Exception as e:
            db.session.rollback()
            blink_detection_ns.abort(500, f'Failed to save test: {str(e)}')
