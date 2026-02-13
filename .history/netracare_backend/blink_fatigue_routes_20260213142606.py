"""
API Routes for Blink and Eye Fatigue Detection
CNN-based drowsiness detection from eye images with microsaccade and eye redness analysis
"""

from flask import request
from flask_restx import Namespace, Resource, fields
from db_model import db, BlinkFatigueTest, User
from auth_utils import token_required
from blink_fatigue_model import get_model_singleton
from werkzeug.datastructures import FileStorage
import os
from datetime import datetime
import cv2
import numpy as np
from io import BytesIO
from PIL import Image

# Create namespace
blink_fatigue_ns = Namespace('blink-fatigue', description='Blink and eye fatigue detection operations')

# File upload parser
upload_parser = blink_fatigue_ns.parser()
upload_parser.add_argument('image', location='files', type=FileStorage, required=True,
                          help='Eye image for drowsiness detection')
upload_parser.add_argument('test_duration', location='form', type=float, required=False,
                          help='Test duration in seconds (optional)')
upload_parser.add_argument('blink_count', location='form', type=int, required=False,
                          help='Total blinks detected during test')

# API Models for documentation
prediction_response_model = blink_fatigue_ns.model('BlinkFatiguePrediction', {
    'prediction': fields.String(description='Predicted class: drowsy or notdrowsy'),
    'confidence': fields.Float(description='Prediction confidence (0-1)'),
    'probabilities': fields.Raw(description='Probabilities for each class'),
    'fatigue_level': fields.String(description='Fatigue level classification'),
    'alert': fields.Boolean(description='Whether alert should be triggered'),
    'timestamp': fields.String(description='Prediction timestamp')
})

test_result_model = blink_fatigue_ns.model('BlinkFatigueTestResult', {
    'id': fields.Integer(description='Test ID'),
    'user_id': fields.Integer(description='User ID'),
    'prediction': fields.String(description='Predicted class'),
    'confidence': fields.Float(description='Confidence score'),
    'probabilities': fields.Raw(description='Class probabilities'),
    'fatigue_level': fields.String(description='Fatigue level'),
    'alert_triggered': fields.Boolean(description='Alert status'),
    'test_duration': fields.Float(description='Test duration in seconds'),
    'created_at': fields.String(description='Test timestamp')
})

test_history_model = blink_fatigue_ns.model('BlinkFatigueHistory', {
    'tests': fields.List(fields.Nested(test_result_model)),
    'total_tests': fields.Integer(description='Total number of tests'),
    'drowsy_count': fields.Integer(description='Number of drowsy detections'),
    'alert_count': fields.Integer(description='Number of alerts triggered')
})


@blink_fatigue_ns.route('/predict')
class BlinkFatiguePrediction(Resource):
    """Predict drowsiness from eye image"""
    
    @blink_fatigue_ns.expect(upload_parser)
    @blink_fatigue_ns.marshal_with(prediction_response_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Analyze eye image for drowsiness detection
        Upload an eye image to get real-time drowsiness prediction
        """
        # Validate file upload
        if 'image' not in request.files:
            blink_fatigue_ns.abort(400, 'No image file provided')
        
        file = request.files['image']
        
        if file.filename == '':
            blink_fatigue_ns.abort(400, 'Empty filename')
        
        # Validate file extension
        allowed_extensions = {'jpg', 'jpeg', 'png'}
        file_ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else ''
        
        if file_ext not in allowed_extensions:
            blink_fatigue_ns.abort(400, f'Invalid file type. Allowed: {allowed_extensions}')
        
        try:
            # Read image bytes
            image_bytes = file.read()
            
            # Get model and make prediction
            model = get_model_singleton()
            prediction_result = model.predict(image_bytes)
            
            return prediction_result
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Prediction failed: {str(e)}')


@blink_fatigue_ns.route('/test/submit')
class BlinkFatigueTestSubmission(Resource):
    """Submit and save blink fatigue test results"""
    
    @blink_fatigue_ns.expect(upload_parser)
    @blink_fatigue_ns.marshal_with(test_result_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Submit blink fatigue test and save results
        Processes image, makes prediction, and stores result in database
        """
        # Validate file upload
        if 'image' not in request.files:
            blink_fatigue_ns.abort(400, 'No image file provided')
        
        file = request.files['image']
        
        if file.filename == '':
            blink_fatigue_ns.abort(400, 'Empty filename')
        
        # Get optional test duration
        test_duration = request.form.get('test_duration', type=float)
        blink_count = request.form.get('blink_count', type=int, default=0)
        
        # Calculate blink rate
        avg_blinks_per_minute = 0
        if test_duration and test_duration > 0:
            avg_blinks_per_minute = round((blink_count / test_duration) * 60, 1)
        
        try:
            # Read image bytes
            image_bytes = file.read()
            
            # Get model and make prediction
            model = get_model_singleton()
            prediction_result = model.predict(image_bytes)
            
            # Create database record
            test_record = BlinkFatigueTest(
                user_id=current_user.id,
                prediction=prediction_result['prediction'],
                confidence=prediction_result['confidence'],
                drowsy_probability=prediction_result['probabilities']['drowsy'],
                notdrowsy_probability=prediction_result['probabilities']['notdrowsy'],
                fatigue_level=prediction_result['fatigue_level'],
                alert_triggered=prediction_result['alert'],
                test_duration=test_duration,
                total_blinks=blink_count,
                avg_blinks_per_minute=avg_blinks_per_minute
            )
            
            db.session.add(test_record)
            db.session.commit()
            
            return test_record.to_dict()
            
        except Exception as e:
            db.session.rollback()
            blink_fatigue_ns.abort(500, f'Test submission failed: {str(e)}')


@blink_fatigue_ns.route('/history')
class BlinkFatigueHistory(Resource):
    """Get user's blink fatigue test history"""
    
    @blink_fatigue_ns.marshal_with(test_history_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """
        Retrieve user's blink fatigue test history
        Returns all past tests with statistics
        """
        try:
            # Fetch all tests for current user
            tests = BlinkFatigueTest.query.filter_by(user_id=current_user.id).order_by(
                BlinkFatigueTest.created_at.desc()
            ).all()
            
            # Calculate statistics
            drowsy_count = sum(1 for t in tests if t.prediction == 'drowsy')
            alert_count = sum(1 for t in tests if t.alert_triggered)
            
            return {
                'tests': [test.to_dict() for test in tests],
                'total_tests': len(tests),
                'drowsy_count': drowsy_count,
                'alert_count': alert_count
            }
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Failed to retrieve history: {str(e)}')


@blink_fatigue_ns.route('/history/<int:test_id>')
class BlinkFatigueTestDetail(Resource):
    """Get specific test details"""
    
    @blink_fatigue_ns.marshal_with(test_result_model)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user, test_id):
        """
        Retrieve specific blink fatigue test by ID
        Returns detailed test results
        """
        try:
            test = BlinkFatigueTest.query.filter_by(
                id=test_id, 
                user_id=current_user.id
            ).first()
            
            if not test:
                blink_fatigue_ns.abort(404, 'Test not found')
            
            return test.to_dict()
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Failed to retrieve test: {str(e)}')


@blink_fatigue_ns.route('/stats')
class BlinkFatigueStats(Resource):
    """Get user's fatigue statistics"""
    
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def get(self, current_user):
        """
        Get aggregated fatigue statistics for user
        Returns trends and patterns in fatigue detection
        """
        try:
            tests = BlinkFatigueTest.query.filter_by(user_id=current_user.id).all()
            
            if not tests:
                return {
                    'total_tests': 0,
                    'average_confidence': 0,
                    'drowsy_percentage': 0,
                    'alert_percentage': 0,
                    'fatigue_distribution': {},
                    'recent_trend': 'No data'
                }
            
            # Calculate statistics
            total_tests = len(tests)
            avg_confidence = sum(t.confidence for t in tests) / total_tests
            drowsy_count = sum(1 for t in tests if t.prediction == 'drowsy')
            alert_count = sum(1 for t in tests if t.alert_triggered)
            
            # Fatigue level distribution
            fatigue_distribution = {}
            for test in tests:
                level = test.fatigue_level
                fatigue_distribution[level] = fatigue_distribution.get(level, 0) + 1
            
            # Recent trend (last 5 tests)
            recent_tests = sorted(tests, key=lambda x: x.created_at, reverse=True)[:5]
            recent_drowsy = sum(1 for t in recent_tests if t.prediction == 'drowsy')
            
            if recent_drowsy >= 4:
                trend = 'High fatigue pattern detected'
            elif recent_drowsy >= 2:
                trend = 'Moderate fatigue detected'
            else:
                trend = 'Alert and well-rested'
            
            return {
                'total_tests': total_tests,
                'average_confidence': round(avg_confidence, 4),
                'drowsy_percentage': round((drowsy_count / total_tests) * 100, 2),
                'alert_percentage': round((alert_count / total_tests) * 100, 2),
                'fatigue_distribution': fatigue_distribution,
                'recent_trend': trend,
                'last_test_date': tests[-1].created_at.isoformat() if tests else None
            }
            
        except Exception as e:
            blink_fatigue_ns.abort(500, f'Failed to retrieve stats: {str(e)}')


# =============================================
# Advanced Fatigue Detection Features
# =============================================

def detect_eye_redness(image_bytes):
    """
    Detect eye redness using color analysis in HSV space
    Returns: redness_score (0-100), is_red (bool), redness_level
    """
    try:
        # Convert bytes to image
        image = Image.open(BytesIO(image_bytes))
        img_array = np.array(image)
        
        # Convert to BGR for OpenCV
        if len(img_array.shape) == 2:  # Grayscale
            img_bgr = cv2.cvtColor(img_array, cv2.COLOR_GRAY2BGR)
        elif img_array.shape[2] == 4:  # RGBA
            img_bgr = cv2.cvtColor(img_array, cv2.COLOR_RGBA2BGR)
        else:  # RGB
            img_bgr = cv2.cvtColor(img_array, cv2.COLOR_RGB2BGR)
        
        # Convert to HSV color space
        hsv = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2HSV)
        
        # Define red color ranges in HSV
        # Red wraps around in HSV, so we need two ranges
        lower_red1 = np.array([0, 50, 50])
        upper_red1 = np.array([10, 255, 255])
        lower_red2 = np.array([170, 50, 50])
        upper_red2 = np.array([180, 255, 255])
        
        # Create masks for red regions
        mask1 = cv2.inRange(hsv, lower_red1, upper_red1)
        mask2 = cv2.inRange(hsv, lower_red2, upper_red2)
        red_mask = cv2.bitwise_or(mask1, mask2)
        
        # Calculate percentage of red pixels
        total_pixels = img_bgr.shape[0] * img_bgr.shape[1]
        red_pixels = np.count_nonzero(red_mask)
        redness_percent = (red_pixels / total_pixels) * 100
        
        # Calculate redness score (0-100)
        # Also consider color intensity in red regions
        if red_pixels > 0:
            red_regions = cv2.bitwise_and(img_bgr, img_bgr, mask=red_mask)
            avg_red_intensity = np.mean(red_regions[red_regions > 0])
            redness_score = min((redness_percent * 10 + avg_red_intensity / 5), 100)
        else:
            redness_score = 0
        
        # Classify redness level
        if redness_score < 20:
            redness_level = "normal"
            is_red = False
        elif redness_score < 40:
            redness_level = "mild"
            is_red = True
        elif redness_score < 60:
            redness_level = "moderate"
            is_red = True
        else:
            redness_level = "severe"
            is_red = True
        
        return round(redness_score, 2), is_red, redness_level
    
    except Exception as e:
        print(f"Error detecting eye redness: {str(e)}")
        return 0, False, "error"


def analyze_microsaccades(video_path, duration=10):
    """
    Analyze microsaccade frequency from eye tracking video
    Microsaccades are tiny involuntary eye movements that decrease with fatigue
    Returns: microsaccade_count, frequency_per_second, fatigue_indicator
    """
    try:
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        if fps == 0:
            return None, None, "error"
        
        # Read first frame for initialization
        ret, prev_frame = cap.read()
        if not ret:
            cap.release()
            return None, None, "error"
        
        prev_gray = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
        
        # Track eye movements (focus on center region where pupil is)
        h, w = prev_gray.shape
        roi = (int(w * 0.3), int(h * 0.3), int(w * 0.4), int(h * 0.4))
        
        movements = []
        frame_count = 0
        max_frames = int(min(duration * fps, cap.get(cv2.CAP_PROP_FRAME_COUNT)))
        
        # Parameters for Lucas-Kanade optical flow
        lk_params = dict(
            winSize=(15, 15),
            maxLevel=2,
            criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 10, 0.03)
        )
        
        # Detect features to track in ROI
        feature_params = dict(maxCorners=100, qualityLevel=0.3, minDistance=7, blockSize=7)
        roi_mask = np.zeros_like(prev_gray)
        roi_mask[roi[1]:roi[1]+roi[3], roi[0]:roi[0]+roi[2]] = 255
        
        p0 = cv2.goodFeaturesToTrack(prev_gray, mask=roi_mask, **feature_params)
        
        if p0 is None:
            cap.release()
            return 0, 0, "insufficient_data"
        
        microsaccade_count = 0
        prev_movement = np.array([0, 0])
        
        while frame_count < max_frames:
            ret, frame = cap.read()
            if not ret:
                break
            
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # Calculate optical flow
            if p0 is not None and len(p0) > 0:
                p1, st, err = cv2.calcOpticalFlowPyrLK(prev_gray, gray, p0, None, **lk_params)
                
                if p1 is not None and st is not None:
                    # Select good points
                    good_new = p1[st == 1]
                    good_old = p0[st == 1]
                    
                    if len(good_new) > 0:
                        # Calculate average movement
                        movement = np.mean(good_new - good_old, axis=0)
                        movement_magnitude = np.linalg.norm(movement)
                        
                        # Detect microsaccade: sudden small movement (0.5-2 pixels)
                        # followed by stabilization
                        if 0.5 < movement_magnitude < 2.0:
                            # Check if direction changed significantly
                            if len(movements) > 0:
                                direction_change = np.dot(movement, prev_movement) / (
                                    np.linalg.norm(movement) * np.linalg.norm(prev_movement) + 1e-5
                                )
                                if direction_change < 0.5:  # Direction change > 60 degrees
                                    microsaccade_count += 1
                        
                        movements.append(movement_magnitude)
                        prev_movement = movement
                        
                        # Update tracking points
                        p0 = good_new.reshape(-1, 1, 2)
            
            prev_gray = gray
            frame_count += 1
        
        cap.release()
        
        # Calculate frequency
        actual_duration = frame_count / fps
        frequency = microsaccade_count / actual_duration if actual_duration > 0 else 0
        
        # Normal microsaccade frequency: 1-3 per second
        # Fatigue reduces frequency
        if frequency >= 1.0:
            fatigue_indicator = "alert"
        elif frequency >= 0.5:
            fatigue_indicator = "mild_fatigue"
        elif frequency >= 0.2:
            fatigue_indicator = "moderate_fatigue"
        else:
            fatigue_indicator = "severe_fatigue"
        
        return microsaccade_count, round(frequency, 2), fatigue_indicator
    
    except Exception as e:
        print(f"Error analyzing microsaccades: {str(e)}")
        return None, None, "error"


# Enhanced prediction parser with video support
enhanced_parser = blink_fatigue_ns.parser()
enhanced_parser.add_argument('image', location='files', type=FileStorage, required=True)
enhanced_parser.add_argument('video', location='files', type=FileStorage, required=False)
enhanced_parser.add_argument('analyze_redness', location='form', type=bool, default=False)
enhanced_parser.add_argument('analyze_microsaccades', location='form', type=bool, default=False)


@blink_fatigue_ns.route('/advanced-analysis')
class AdvancedFatigueAnalysis(Resource):
    """Advanced fatigue analysis with eye redness and microsaccade detection"""
    
    @blink_fatigue_ns.expect(enhanced_parser)
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """
        Comprehensive fatigue analysis including:
        - CNN drowsiness detection
        - Eye redness analysis
        - Microsaccade frequency analysis (requires video)
        """
        try:
            # Validate image upload
            if 'image' not in request.files:
                return {'message': 'Eye image is required'}, 400
            
            image_file = request.files['image']
            if image_file.filename == '':
                return {'message': 'Empty image filename'}, 400
            
            # Read image
            image_bytes = image_file.read()
            
            # Get CNN drowsiness prediction
            model = get_model_singleton()
            prediction_result = model.predict(image_bytes)
            
            # Eye redness analysis (if requested)
            redness_score = None
            is_red = False
            redness_level = None
            
            if request.form.get('analyze_redness', 'false').lower() == 'true':
                redness_score, is_red, redness_level = detect_eye_redness(image_bytes)
            
            # Microsaccade analysis (if video provided and requested)
            microsaccade_count = None
            microsaccade_frequency = None
            microsaccade_fatigue = None
            
            if request.form.get('analyze_microsaccades', 'false').lower() == 'true':
                if 'video' in request.files:
                    video_file = request.files['video']
                    if video_file.filename != '':
                        # Save video temporarily
                        video_path = f"uploads/temp_{current_user.id}_{datetime.now().timestamp()}.mp4"
                        os.makedirs('uploads', exist_ok=True)
                        video_file.save(video_path)
                        
                        # Analyze microsaccades
                        microsaccade_count, microsaccade_frequency, microsaccade_fatigue = analyze_microsaccades(video_path)
                        
                        # Clean up temp file
                        try:
                            os.remove(video_path)
                        except:
                            pass
            
            # Combine results for comprehensive fatigue score
            fatigue_indicators = []
            
            if prediction_result['prediction'] == 'drowsy':
                fatigue_indicators.append('drowsy_eyes')
            
            if is_red and redness_level in ['moderate', 'severe']:
                fatigue_indicators.append('eye_redness')
            
            if microsaccade_fatigue in ['moderate_fatigue', 'severe_fatigue']:
                fatigue_indicators.append('reduced_microsaccades')
            
            # Overall fatigue assessment
            if len(fatigue_indicators) >= 2:
                overall_fatigue = "high"
                recommendation = "Immediate rest recommended. Avoid driving or operating machinery."
            elif len(fatigue_indicators) == 1:
                overall_fatigue = "moderate"
                recommendation = "Take a break. Consider short rest period."
            else:
                overall_fatigue = "low"
                recommendation = "Eye health appears normal. Continue regular breaks."
            
            return {
                'message': 'Advanced fatigue analysis completed',
                'cnn_prediction': {
                    'prediction': prediction_result['prediction'],
                    'confidence': prediction_result['confidence'],
                    'fatigue_level': prediction_result['fatigue_level']
                },
                'eye_redness': {
                    'score': redness_score,
                    'is_red': is_red,
                    'level': redness_level
                } if redness_score is not None else None,
                'microsaccades': {
                    'count': microsaccade_count,
                    'frequency_per_second': microsaccade_frequency,
                    'fatigue_indicator': microsaccade_fatigue
                } if microsaccade_count is not None else None,
                'overall_assessment': {
                    'fatigue_level': overall_fatigue,
                    'indicators': fatigue_indicators,
                    'recommendation': recommendation
                },
                'timestamp': datetime.utcnow().isoformat()
            }, 200
        
        except Exception as e:
            return {'message': f'Advanced analysis failed: {str(e)}'}, 500


@blink_fatigue_ns.route('/redness-check')
class EyeRednessCheck(Resource):
    """Quick eye redness detection"""
    
    @blink_fatigue_ns.doc(security='Bearer')
    @token_required
    def post(self, current_user):
        """Analyze eye image for redness indicators"""
        try:
            if 'image' not in request.files:
                return {'message': 'Eye image is required'}, 400
            
            image_file = request.files['image']
            image_bytes = image_file.read()
            
            redness_score, is_red, redness_level = detect_eye_redness(image_bytes)
            
            # Generate recommendations based on redness
            if redness_level == "severe":
                recommendations = [
                    "Consult an ophthalmologist immediately",
                    "Avoid screen use until examined",
                    "Use prescribed eye drops if available"
                ]
            elif redness_level == "moderate":
                recommendations = [
                    "Schedule eye examination within a week",
                    "Use lubricating eye drops",
                    "Reduce screen time and take frequent breaks"
                ]
            elif redness_level == "mild":
                recommendations = [
                    "Monitor symptoms for 24-48 hours",
                    "Use artificial tears as needed",
                    "Ensure adequate sleep and hydration"
                ]
            else:
                recommendations = [
                    "Eyes appear healthy",
                    "Continue routine eye care practices"
                ]
            
            return {
                'redness_score': redness_score,
                'is_red': is_red,
                'redness_level': redness_level,
                'recommendations': recommendations,
                'timestamp': datetime.utcnow().isoformat()
            }, 200
        
        except Exception as e:
            return {'message': f'Redness check failed: {str(e)}'}, 500

