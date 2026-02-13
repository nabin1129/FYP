"""
Pupil Reflex Test Routes with Nystagmus Detection
Handles flash stimulation tests and AI-powered nystagmus classification
"""
from flask import request, jsonify
from flask_restx import Namespace, Resource, fields
from werkzeug.utils import secure_filename
from datetime import datetime
import os
import uuid
import cv2
import numpy as np
from auth_utils import token_required
from db_model import db, User, PupilReflexTest

# Create namespace
pupil_reflex_ns = Namespace('pupil-reflex', description='Pupil Reflex and Nystagmus Detection Tests')

# API Models
start_test_model = pupil_reflex_ns.model('StartPupilReflexTest', {
    'test_type': fields.String(required=True, description='Type of test: pupil_reflex or nystagmus'),
    'eye_tested': fields.String(required=True, description='Eye being tested: left, right, or both')
})

analyze_video_model = pupil_reflex_ns.model('AnalyzeVideo', {
    'test_id': fields.String(required=True, description='Test session ID'),
    'flash_timestamps': fields.List(fields.Float, description='Timestamps when flash was triggered (in seconds)')
})

test_result_model = pupil_reflex_ns.model('PupilReflexResult', {
    'id': fields.String(description='Test ID'),
    'user_id': fields.Integer(description='User ID'),
    'test_date': fields.DateTime(description='Test date'),
    'eye_tested': fields.String(description='Eye tested'),
    'pupil_response_time_ms': fields.Float(description='Pupil response time in milliseconds'),
    'pupil_constriction_percent': fields.Float(description='Pupil constriction percentage'),
    'nystagmus_detected': fields.Boolean(description='Whether nystagmus was detected'),
    'nystagmus_type': fields.String(description='Type of nystagmus: horizontal, vertical, rotary, or mixed'),
    'nystagmus_severity': fields.String(description='Severity: mild, moderate, severe'),
    'nystagmus_confidence': fields.Float(description='AI confidence score'),
    'diagnosis': fields.String(description='Overall diagnosis'),
    'recommendations': fields.String(description='Medical recommendations')
})

# Configuration
UPLOAD_FOLDER = 'uploads/pupil_reflex'
ALLOWED_EXTENSIONS = {'mp4', 'avi', 'mov', 'webm'}
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def extract_pupil_features(frame):
    """
    Extract pupil features from a frame using OpenCV
    Returns: pupil_radius, pupil_center (x, y), or None if not detected
    """
    try:
        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Apply Gaussian blur to reduce noise
        blurred = cv2.GaussianBlur(gray, (7, 7), 0)
        
        # Use Hough Circle Transform to detect circular pupils
        circles = cv2.HoughCircles(
            blurred,
            cv2.HOUGH_GRADIENT,
            dp=1,
            minDist=50,
            param1=50,
            param2=30,
            minRadius=10,
            maxRadius=100
        )
        
        if circles is not None:
            circles = np.uint16(np.around(circles))
            # Return the first detected circle (largest pupil)
            x, y, radius = circles[0][0]
            return radius, (x, y)
        
        return None, None
    except Exception as e:
        print(f"Error extracting pupil features: {str(e)}")
        return None, None

def calculate_pupil_response(video_path, flash_timestamps):
    """
    Analyze pupil constriction response to flash stimulation
    Returns: response_time_ms, constriction_percent
    """
    try:
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        if not flash_timestamps or len(flash_timestamps) == 0:
            cap.release()
            return None, None
        
        # Analyze first flash event
        flash_time = flash_timestamps[0]
        flash_frame = int(flash_time * fps)
        
        # Get baseline pupil size (3 frames before flash)
        baseline_radii = []
        for i in range(max(0, flash_frame - 3), flash_frame):
            cap.set(cv2.CAP_PROP_POS_FRAMES, i)
            ret, frame = cap.read()
            if ret:
                radius, _ = extract_pupil_features(frame)
                if radius:
                    baseline_radii.append(radius)
        
        if not baseline_radii:
            cap.release()
            return None, None
        
        baseline_radius = np.mean(baseline_radii)
        
        # Find minimum pupil size after flash (within 1 second)
        min_radius = baseline_radius
        min_frame = flash_frame
        
        for i in range(flash_frame, min(flash_frame + int(fps), int(cap.get(cv2.CAP_PROP_FRAME_COUNT)))):
            cap.set(cv2.CAP_PROP_POS_FRAMES, i)
            ret, frame = cap.read()
            if ret:
                radius, _ = extract_pupil_features(frame)
                if radius and radius < min_radius:
                    min_radius = radius
                    min_frame = i
        
        cap.release()
        
        # Calculate response time and constriction
        response_time_ms = ((min_frame - flash_frame) / fps) * 1000
        constriction_percent = ((baseline_radius - min_radius) / baseline_radius) * 100
        
        return response_time_ms, constriction_percent
    
    except Exception as e:
        print(f"Error calculating pupil response: {str(e)}")
        return None, None

def detect_nystagmus_movements(video_path):
    """
    Detect nystagmus (involuntary eye movements) using optical flow
    Returns: nystagmus_detected (bool), movement_type (str), severity (str), confidence (float)
    """
    try:
        cap = cv2.VideoCapture(video_path)
        
        # Read first frame
        ret, prev_frame = cap.read()
        if not ret:
            cap.release()
            return False, None, None, 0.0
        
        prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
        
        # Track horizontal and vertical movements
        horizontal_movements = []
        vertical_movements = []
        rotary_movements = []
        
        frame_count = 0
        max_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        while cap.isOpened() and frame_count < max_frames:
            ret, frame = cap.read()
            if not ret:
                break
            
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # Calculate optical flow
            flow = cv2.calcOpticalFlowFarneback(
                prev_gray, gray, None,
                pyr_scale=0.5, levels=3, winsize=15,
                iterations=3, poly_n=5, poly_sigma=1.2, flags=0
            )
            
            # Analyze flow patterns in eye region (center 50% of frame)
            h, w = flow.shape[:2]
            roi = flow[int(h*0.25):int(h*0.75), int(w*0.25):int(w*0.75)]
            
            # Calculate average horizontal and vertical movements
            avg_horizontal = np.mean(roi[:, :, 0])
            avg_vertical = np.mean(roi[:, :, 1])
            
            horizontal_movements.append(avg_horizontal)
            vertical_movements.append(avg_vertical)
            
            prev_gray = gray
            frame_count += 1
        
        cap.release()
        
        if not horizontal_movements:
            return False, None, None, 0.0
        
        # Analyze movement patterns
        h_std = np.std(horizontal_movements)
        v_std = np.std(vertical_movements)
        h_range = np.max(horizontal_movements) - np.min(horizontal_movements)
        v_range = np.max(vertical_movements) - np.min(vertical_movements)
        
        # Detect rapid rhythmic movements (characteristic of nystagmus)
        # Using FFT to detect periodic movements
        h_fft = np.fft.fft(horizontal_movements)
        v_fft = np.fft.fft(vertical_movements)
        h_power = np.abs(h_fft[1:len(h_fft)//2])
        v_power = np.abs(v_fft[1:len(v_fft)//2])
        
        # Threshold for nystagmus detection
        nystagmus_threshold = 0.5
        h_has_nystagmus = h_std > nystagmus_threshold and np.max(h_power) > 10
        v_has_nystagmus = v_std > nystagmus_threshold and np.max(v_power) > 10
        
        nystagmus_detected = h_has_nystagmus or v_has_nystagmus
        
        if not nystagmus_detected:
            return False, None, None, 0.0
        
        # Classify nystagmus type
        if h_has_nystagmus and v_has_nystagmus:
            movement_type = "mixed"
            confidence = min(h_std / (h_std + v_std), v_std / (h_std + v_std)) * 0.8 + 0.2
        elif h_has_nystagmus:
            movement_type = "horizontal"
            confidence = min(h_std / 2.0, 1.0) * 0.9
        else:
            movement_type = "vertical"
            confidence = min(v_std / 2.0, 1.0) * 0.9
        
        # Determine severity based on movement amplitude
        max_movement = max(h_range, v_range)
        if max_movement < 2.0:
            severity = "mild"
        elif max_movement < 5.0:
            severity = "moderate"
        else:
            severity = "severe"
        
        return True, movement_type, severity, confidence
    
    except Exception as e:
        print(f"Error detecting nystagmus: {str(e)}")
        return False, None, None, 0.0

def generate_diagnosis(pupil_response_time, constriction_percent, nystagmus_detected, nystagmus_type, severity):
    """Generate diagnosis and recommendations based on test results"""
    issues = []
    recommendations = []
    
    # Analyze pupil reflex
    if pupil_response_time is not None and constriction_percent is not None:
        if pupil_response_time > 300:
            issues.append("Delayed pupil response (>300ms)")
            recommendations.append("Consult neurologist for potential nerve damage assessment")
        
        if constriction_percent < 20:
            issues.append("Weak pupil constriction (<20%)")
            recommendations.append("Consider ophthalmology consultation for pupil function evaluation")
        elif constriction_percent > 80:
            issues.append("Excessive pupil constriction (>80%)")
            recommendations.append("Monitor for photophobia or light sensitivity issues")
    
    # Analyze nystagmus
    if nystagmus_detected:
        issues.append(f"{severity.capitalize()} {nystagmus_type} nystagmus detected")
        
        if severity == "severe":
            recommendations.append("Immediate ophthalmology consultation recommended")
            recommendations.append("Consider neurological evaluation to rule out vestibular disorders")
        elif severity == "moderate":
            recommendations.append("Schedule ophthalmology appointment within 2 weeks")
            recommendations.append("Consider vestibular function testing")
        else:
            recommendations.append("Monitor symptoms and schedule routine eye examination")
    
    if not issues:
        diagnosis = "Normal pupil reflex and eye movement patterns"
        recommendations.append("Continue routine eye examinations annually")
    else:
        diagnosis = "; ".join(issues)
    
    return diagnosis, "; ".join(recommendations) if recommendations else "No specific recommendations"

@pupil_reflex_ns.route('/start-test')
class StartTest(Resource):
    """Start a new pupil reflex test session"""
    
    @pupil_reflex_ns.doc(security='Bearer')
    @pupil_reflex_ns.expect(start_test_model)
    @token_required
    def post(self, current_user):
        """Initialize a new pupil reflex test"""
        try:
            data = request.get_json()
            
            # Create new test record
            test = PupilReflexTest(
                user_id=current_user.id,
                test_date=datetime.utcnow(),
                eye_tested=data.get('eye_tested', 'both'),
                test_type=data.get('test_type', 'pupil_reflex')
            )
            
            db.session.add(test)
            db.session.commit()
            
            return {
                'message': 'Pupil reflex test started',
                'test_id': test.id,
                'instructions': {
                    'pupil_reflex': 'Record video while flash stimulation is applied to the eye',
                    'nystagmus': 'Record smooth eye tracking movements for 10-15 seconds',
                    'flash_timing': 'Trigger flash at regular intervals (2-3 seconds apart)',
                    'distance': 'Maintain 30-40cm distance from camera',
                    'lighting': 'Ensure dim ambient lighting for best pupil detection'
                }
            }, 201
        
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to start test: {str(e)}'}, 500

@pupil_reflex_ns.route('/analyze-video')
class AnalyzeVideo(Resource):
    """Analyze uploaded video for pupil reflex and nystagmus"""
    
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """Upload and analyze video for pupil reflex and nystagmus detection"""
        try:
            # Check if video file is in request
            if 'video' not in request.files:
                return {'message': 'No video file provided'}, 400
            
            video_file = request.files['video']
            
            if video_file.filename == '':
                return {'message': 'No video file selected'}, 400
            
            if not allowed_file(video_file.filename):
                return {'message': f'Invalid file type. Allowed: {", ".join(ALLOWED_EXTENSIONS)}'}, 400
            
            # Get test_id from form data
            test_id = request.form.get('test_id')
            if not test_id:
                return {'message': 'test_id is required'}, 400
            
            # Get flash timestamps (optional)
            flash_timestamps_str = request.form.get('flash_timestamps', '[]')
            try:
                import json
                flash_timestamps = json.loads(flash_timestamps_str)
            except:
                flash_timestamps = []
            
            # Find test record
            test = PupilReflexTest.query.filter_by(id=test_id, user_id=current_user.id).first()
            if not test:
                return {'message': 'Test not found'}, 404
            
            # Save video file
            filename = secure_filename(f"{test_id}_{uuid.uuid4().hex}.{video_file.filename.rsplit('.', 1)[1].lower()}")
            video_path = os.path.join(UPLOAD_FOLDER, filename)
            video_file.save(video_path)
            
            # Analyze pupil reflex (if flash timestamps provided)
            response_time, constriction = None, None
            if flash_timestamps and len(flash_timestamps) > 0:
                response_time, constriction = calculate_pupil_response(video_path, flash_timestamps)
            
            # Detect nystagmus
            nystagmus_detected, nystagmus_type, severity, confidence = detect_nystagmus_movements(video_path)
            
            # Generate diagnosis
            diagnosis, recommendations = generate_diagnosis(
                response_time, constriction, nystagmus_detected, nystagmus_type, severity
            )
            
            # Update test record
            test.pupil_response_time_ms = response_time
            test.pupil_constriction_percent = constriction
            test.nystagmus_detected = nystagmus_detected
            test.nystagmus_type = nystagmus_type
            test.nystagmus_severity = severity
            test.nystagmus_confidence = confidence
            test.diagnosis = diagnosis
            test.recommendations = recommendations
            test.video_path = video_path
            
            db.session.commit()
            
            return {
                'message': 'Video analyzed successfully',
                'results': {
                    'test_id': test.id,
                    'pupil_reflex': {
                        'response_time_ms': response_time,
                        'constriction_percent': constriction,
                        'status': 'normal' if response_time and response_time < 300 and constriction and constriction > 20 else 'abnormal'
                    } if response_time else None,
                    'nystagmus': {
                        'detected': nystagmus_detected,
                        'type': nystagmus_type,
                        'severity': severity,
                        'confidence': confidence
                    },
                    'diagnosis': diagnosis,
                    'recommendations': recommendations
                }
            }, 200
        
        except Exception as e:
            db.session.rollback()
            return {'message': f'Failed to analyze video: {str(e)}'}, 500

@pupil_reflex_ns.route('/results/<int:test_id>')
class GetResults(Resource):
    """Get pupil reflex test results"""
    
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, test_id):
        """Retrieve test results by test ID"""
        try:
            test = PupilReflexTest.query.filter_by(id=test_id, user_id=current_user.id).first()
            
            if not test:
                return {'message': 'Test not found'}, 404
            
            return {
                'test_id': test.id,
                'user_id': test.user_id,
                'test_date': test.test_date.isoformat() if test.test_date else None,
                'eye_tested': test.eye_tested,
                'pupil_reflex': {
                    'response_time_ms': test.pupil_response_time_ms,
                    'constriction_percent': test.pupil_constriction_percent
                },
                'nystagmus': {
                    'detected': test.nystagmus_detected,
                    'type': test.nystagmus_type,
                    'severity': test.nystagmus_severity,
                    'confidence': test.nystagmus_confidence
                },
                'diagnosis': test.diagnosis,
                'recommendations': test.recommendations
            }, 200
        
        except Exception as e:
            return {'message': f'Failed to get results: {str(e)}'}, 500

@pupil_reflex_ns.route('/history')
class TestHistory(Resource):
    """Get user's pupil reflex test history"""
    
    @pupil_reflex_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """Get all pupil reflex tests for current user"""
        try:
            tests = PupilReflexTest.query.filter_by(user_id=current_user.id).order_by(PupilReflexTest.test_date.desc()).all()
            
            results = []
            for test in tests:
                results.append({
                    'test_id': test.id,
                    'test_date': test.test_date.isoformat() if test.test_date else None,
                    'eye_tested': test.eye_tested,
                    'nystagmus_detected': test.nystagmus_detected,
                    'nystagmus_type': test.nystagmus_type,
                    'diagnosis': test.diagnosis
                })
            
            return {
                'total_tests': len(results),
                'tests': results
            }, 200
        
        except Exception as e:
            return {'message': f'Failed to get test history: {str(e)}'}, 500
