from datetime import datetime
from flask_sqlalchemy import SQLAlchemy
import json

db = SQLAlchemy()

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(120))
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    age = db.Column(db.Integer)
    sex = db.Column(db.String(20))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)


class EyeTrackingTest(db.Model):
    """Database model for eye tracking test records"""
    __tablename__ = 'eye_tracking_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    test_name = db.Column(db.String(255), nullable=False)
    test_duration = db.Column(db.Float, nullable=False)  # in seconds
    
    # Metrics
    gaze_accuracy = db.Column(db.Float)  # percentage
    fixation_stability_score = db.Column(db.Float)  # 0-100
    saccade_consistency_score = db.Column(db.Float)  # 0-100
    overall_performance_score = db.Column(db.Float)  # 0-100
    performance_classification = db.Column(db.String(50))  # Excellent, Good, Fair, Poor
    
    # Pupil metrics (stored as JSON)
    left_pupil_metrics = db.Column(db.Text)  # JSON string
    right_pupil_metrics = db.Column(db.Text)  # JSON string
    
    # Raw data (stored as JSON for detailed analysis)
    raw_data = db.Column(db.Text)  # JSON string containing all data points
    
    # Screen resolution
    screen_width = db.Column(db.Integer)
    screen_height = db.Column(db.Integer)
    
    # Status and timestamps
    status = db.Column(db.String(50), default='completed')  # pending, completed, failed
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('eye_tracking_tests', lazy=True))
    
    def set_pupil_metrics(self, left_metrics: dict, right_metrics: dict) -> None:
        """Store pupil metrics as JSON"""
        self.left_pupil_metrics = json.dumps(left_metrics)
        self.right_pupil_metrics = json.dumps(right_metrics)
    
    def get_pupil_metrics(self) -> dict:
        """Retrieve pupil metrics from JSON"""
        return {
            'left_pupil': json.loads(self.left_pupil_metrics) if self.left_pupil_metrics else None,
            'right_pupil': json.loads(self.right_pupil_metrics) if self.right_pupil_metrics else None
        }
    
    def set_raw_data(self, data_points: list) -> None:
        """Store raw eye tracking data as JSON"""
        self.raw_data = json.dumps(data_points)
    
    def get_raw_data(self) -> list:
        """Retrieve raw eye tracking data from JSON"""
        return json.loads(self.raw_data) if self.raw_data else []
    
    def to_dict(self) -> dict:
        """Convert test record to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'test_name': self.test_name,
            'test_duration': self.test_duration,
            'gaze_accuracy': self.gaze_accuracy,
            'fixation_stability_score': self.fixation_stability_score,
            'saccade_consistency_score': self.saccade_consistency_score,
            'overall_performance_score': self.overall_performance_score,
            'performance_classification': self.performance_classification,
            'pupil_metrics': self.get_pupil_metrics(),
            'screen_width': self.screen_width,
            'screen_height': self.screen_height,
            'status': self.status,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }


class VisualAcuityTest(db.Model):
    """Database model for visual acuity test results"""
    __tablename__ = 'visual_acuity_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Test results
    correct_answers = db.Column(db.Integer, nullable=False)
    total_questions = db.Column(db.Integer, nullable=False)
    logmar_value = db.Column(db.Float, nullable=False)
    snellen_value = db.Column(db.String(50), nullable=False)
    severity = db.Column(db.String(50), nullable=False)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('visual_acuity_tests', lazy=True))
    
    def to_dict(self) -> dict:
        """Convert test to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'correct_answers': self.correct_answers,
            'total_questions': self.total_questions,
            'logmar_value': self.logmar_value,
            'snellen_value': self.snellen_value,
            'severity': self.severity,
            'created_at': self.created_at.isoformat()
        }


class CameraEyeTrackingSession(db.Model):
    """Database model for camera-based eye tracking sessions (OpenCV + MediaPipe)"""
    __tablename__ = 'camera_eye_tracking_sessions'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    session_name = db.Column(db.String(255), default='Camera Eye Tracking Session')
    
    # Session details
    duration_seconds = db.Column(db.Float, nullable=False)
    start_time = db.Column(db.DateTime, nullable=False)
    end_time = db.Column(db.DateTime, nullable=False)
    
    # Blink metrics
    total_blinks = db.Column(db.Integer, default=0)
    blink_rate_per_minute = db.Column(db.Float)
    
    # Eye Aspect Ratio (EAR) statistics
    left_eye_ear_mean = db.Column(db.Float)
    left_eye_ear_std = db.Column(db.Float)
    left_eye_ear_min = db.Column(db.Float)
    left_eye_ear_max = db.Column(db.Float)
    
    right_eye_ear_mean = db.Column(db.Float)
    right_eye_ear_std = db.Column(db.Float)
    right_eye_ear_min = db.Column(db.Float)
    right_eye_ear_max = db.Column(db.Float)
    
    average_ear_mean = db.Column(db.Float)
    average_ear_std = db.Column(db.Float)
    average_ear_min = db.Column(db.Float)
    average_ear_max = db.Column(db.Float)
    
    # Gaze direction distribution (stored as JSON)
    gaze_distribution = db.Column(db.Text)  # JSON: {'center': count, 'left': count, ...}
    
    # Raw session data
    total_frames = db.Column(db.Integer, default=0)
    frames_with_face = db.Column(db.Integer, default=0)
    detection_rate = db.Column(db.Float)  # percentage
    
    # Detailed data (optional, can be large)
    blink_events = db.Column(db.Text)  # JSON array of blink events with timestamps
    gaze_events = db.Column(db.Text)  # JSON array of gaze movements with timestamps
    
    # Device and settings
    camera_id = db.Column(db.Integer, default=0)
    ear_threshold = db.Column(db.Float, default=0.21)
    
    # Status
    status = db.Column(db.String(50), default='completed')  # pending, in_progress, completed, failed
    notes = db.Column(db.Text)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('camera_eye_tracking_sessions', lazy=True))
    
    def set_gaze_distribution(self, distribution: dict) -> None:
        """Store gaze distribution as JSON"""
        self.gaze_distribution = json.dumps(distribution)
    
    def get_gaze_distribution(self) -> dict:
        """Retrieve gaze distribution from JSON"""
        return json.loads(self.gaze_distribution) if self.gaze_distribution else {}
    
    def set_blink_events(self, events: list) -> None:
        """Store blink events as JSON"""
        self.blink_events = json.dumps(events)
    
    def get_blink_events(self) -> list:
        """Retrieve blink events from JSON"""
        return json.loads(self.blink_events) if self.blink_events else []
    
    def set_gaze_events(self, events: list) -> None:
        """Store gaze events as JSON"""
        self.gaze_events = json.dumps(events)
    
    def get_gaze_events(self) -> list:
        """Retrieve gaze events from JSON"""
        return json.loads(self.gaze_events) if self.gaze_events else []
    
    def to_dict(self, include_events: bool = False) -> dict:
        """Convert session to dictionary"""
        result = {
            'id': self.id,
            'user_id': self.user_id,
            'session_name': self.session_name,
            'duration_seconds': self.duration_seconds,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'blink_metrics': {
                'total_blinks': self.total_blinks,
                'blink_rate_per_minute': self.blink_rate_per_minute
            },
            'ear_statistics': {
                'left_eye': {
                    'mean': self.left_eye_ear_mean,
                    'std': self.left_eye_ear_std,
                    'min': self.left_eye_ear_min,
                    'max': self.left_eye_ear_max
                },
                'right_eye': {
                    'mean': self.right_eye_ear_mean,
                    'std': self.right_eye_ear_std,
                    'min': self.right_eye_ear_min,
                    'max': self.right_eye_ear_max
                },
                'average': {
                    'mean': self.average_ear_mean,
                    'std': self.average_ear_std,
                    'min': self.average_ear_min,
                    'max': self.average_ear_max
                }
            },
            'gaze_distribution': self.get_gaze_distribution(),
            'detection_metrics': {
                'total_frames': self.total_frames,
                'frames_with_face': self.frames_with_face,
                'detection_rate': self.detection_rate
            },
            'settings': {
                'camera_id': self.camera_id,
                'ear_threshold': self.ear_threshold
            },
            'status': self.status,
            'notes': self.notes,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
        
        if include_events:
            result['blink_events'] = self.get_blink_events()
            result['gaze_events'] = self.get_gaze_events()
        
        return result


class ColourVisionTest(db.Model):
    """Database model for Ishihara color vision test results"""
    __tablename__ = 'colour_vision_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Test configuration
    total_plates = db.Column(db.Integer, nullable=False)
    plate_ids = db.Column(db.Text, nullable=False)  # JSON: [0, 3, 5, 7, 9]
    plate_images = db.Column(db.Text, nullable=False)  # JSON: ["0_Font1...", "3_Font2..."]
    
    # User responses
    user_answers = db.Column(db.Text, nullable=False)  # JSON: ["12", "8", "29", "5", "74"]
    correct_answers = db.Column(db.Text, nullable=False)  # JSON: ["12", "8", "29", "5", "74"]
    
    # Scoring
    correct_count = db.Column(db.Integer, nullable=False)
    score = db.Column(db.Integer, nullable=False)  # Percentage: 0-100
    severity = db.Column(db.String(50), nullable=False)  # Normal, Mild, Deficiency
    
    # Metadata
    test_duration = db.Column(db.Float)  # seconds
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('colour_vision_tests', lazy=True))
    
    def set_plate_data(self, plate_ids: list, plate_images: list):
        """Store plate data as JSON"""
        self.plate_ids = json.dumps(plate_ids)
        self.plate_images = json.dumps(plate_images)
    
    def set_answers(self, user_answers: list, correct_answers: list):
        """Store answer data as JSON"""
        self.user_answers = json.dumps(user_answers)
        self.correct_answers = json.dumps(correct_answers)
    
    def get_plate_ids(self) -> list:
        """Retrieve plate IDs as list"""
        return json.loads(self.plate_ids) if self.plate_ids else []
    
    def get_plate_images(self) -> list:
        """Retrieve plate images as list"""
        return json.loads(self.plate_images) if self.plate_images else []
    
    def get_user_answers(self) -> list:
        """Retrieve user answers as list"""
        return json.loads(self.user_answers) if self.user_answers else []
    
    def get_correct_answers(self) -> list:
        """Retrieve correct answers as list"""
        return json.loads(self.correct_answers) if self.correct_answers else []
    
    def to_dict(self) -> dict:
        """Convert test to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'total_plates': self.total_plates,
            'plate_ids': self.get_plate_ids(),
            'plate_images': self.get_plate_images(),
            'user_answers': self.get_user_answers(),
            'correct_answers': self.get_correct_answers(),
            'correct_count': self.correct_count,
            'score': self.score,
            'severity': self.severity,
            'test_duration': self.test_duration,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }


class BlinkFatigueTest(db.Model):
    """Database model for blink and eye fatigue detection results"""
    __tablename__ = 'blink_fatigue_tests'
    
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    
    # Prediction results
    prediction = db.Column(db.String(50), nullable=False)  # 'drowsy' or 'notdrowsy'
    confidence = db.Column(db.Float, nullable=False)  # 0-1
    drowsy_probability = db.Column(db.Float, nullable=False)  # 0-1
    notdrowsy_probability = db.Column(db.Float, nullable=False)  # 0-1
    
    # Fatigue classification
    fatigue_level = db.Column(db.String(100), nullable=False)  # Alert, Low Fatigue, etc.
    alert_triggered = db.Column(db.Boolean, default=False)  # True if drowsy_prob > 0.7
    
    # Test metadata
    test_duration = db.Column(db.Float)  # seconds (if applicable)
    image_filename = db.Column(db.String(255))  # stored image filename (optional)
    
    # Timestamps
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationship
    user = db.relationship('User', backref=db.backref('blink_fatigue_tests', lazy=True))
    
    def to_dict(self) -> dict:
        """Convert test to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'prediction': self.prediction,
            'confidence': self.confidence,
            'probabilities': {
                'drowsy': self.drowsy_probability,
                'notdrowsy': self.notdrowsy_probability
            },
            'fatigue_level': self.fatigue_level,
            'alert_triggered': self.alert_triggered,
            'test_duration': self.test_duration,
            'image_filename': self.image_filename,
            'created_at': self.created_at.isoformat(),
            'updated_at': self.updated_at.isoformat()
        }
