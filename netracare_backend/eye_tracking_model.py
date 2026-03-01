import math
import numpy as np
from datetime import datetime
from typing import List, Tuple, Dict
import json

class EyeTrackingDataPoint:
    """Represents a single eye tracking data point"""
    def __init__(self, timestamp: float, gaze_x: float, gaze_y: float, 
                 left_pupil_diameter: float, right_pupil_diameter: float,
                 fixation_duration: float = None, saccade_velocity: float = None,
                 target_x: float = None, target_y: float = None,
                 left_ear: float = None, right_ear: float = None,
                 is_blink: bool = False,
                 head_euler_x: float = None, head_euler_y: float = None,
                 head_euler_z: float = None,
                 left_eye_open_prob: float = None, right_eye_open_prob: float = None,
                 phase: str = None):
        self.timestamp = timestamp
        self.gaze_x = gaze_x
        self.gaze_y = gaze_y
        self.left_pupil_diameter = left_pupil_diameter
        self.right_pupil_diameter = right_pupil_diameter
        self.fixation_duration = fixation_duration
        self.saccade_velocity = saccade_velocity
        # New real camera fields
        self.target_x = target_x
        self.target_y = target_y
        self.left_ear = left_ear
        self.right_ear = right_ear
        self.is_blink = is_blink
        self.head_euler_x = head_euler_x
        self.head_euler_y = head_euler_y
        self.head_euler_z = head_euler_z
        self.left_eye_open_prob = left_eye_open_prob
        self.right_eye_open_prob = right_eye_open_prob
        self.phase = phase
    
    @property
    def average_ear(self) -> float:
        """Average Eye Aspect Ratio"""
        if self.left_ear is not None and self.right_ear is not None:
            return (self.left_ear + self.right_ear) / 2.0
        return 0.0

    @property
    def has_target(self) -> bool:
        return self.target_x is not None and self.target_y is not None

    def to_dict(self) -> Dict:
        result = {
            'timestamp': self.timestamp,
            'gaze_x': self.gaze_x,
            'gaze_y': self.gaze_y,
            'left_pupil_diameter': self.left_pupil_diameter,
            'right_pupil_diameter': self.right_pupil_diameter,
            'fixation_duration': self.fixation_duration,
            'saccade_velocity': self.saccade_velocity,
        }
        if self.target_x is not None:
            result['target_x'] = self.target_x
            result['target_y'] = self.target_y
        if self.left_ear is not None:
            result['left_ear'] = self.left_ear
            result['right_ear'] = self.right_ear
        if self.is_blink:
            result['is_blink'] = self.is_blink
        if self.head_euler_x is not None:
            result['head_euler_x'] = self.head_euler_x
            result['head_euler_y'] = self.head_euler_y
            result['head_euler_z'] = self.head_euler_z
        if self.phase is not None:
            result['phase'] = self.phase
        return result


class EyeTrackingDataset:
    """Manages eye tracking test datasets"""
    def __init__(self, test_name: str, screen_width: int = 1920, screen_height: int = 1080):
        self.test_name = test_name
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.data_points: List[EyeTrackingDataPoint] = []
        self.created_at = datetime.utcnow()
        self.test_duration = 0  # in seconds
    
    def add_data_point(self, data_point: EyeTrackingDataPoint) -> None:
        """Add a single data point to the dataset"""
        if not isinstance(data_point, EyeTrackingDataPoint):
            raise ValueError("data_point must be an EyeTrackingDataPoint instance")
        self.data_points.append(data_point)
    
    def add_data_points(self, data_points: List[EyeTrackingDataPoint]) -> None:
        """Add multiple data points to the dataset"""
        for point in data_points:
            self.add_data_point(point)
    
    def get_data_points(self) -> List[EyeTrackingDataPoint]:
        """Retrieve all data points"""
        return self.data_points
    
    def get_point_count(self) -> int:
        """Get total number of data points"""
        return len(self.data_points)
    
    def set_test_duration(self, duration: float) -> None:
        """Set total test duration in seconds"""
        if duration <= 0:
            raise ValueError("Test duration must be greater than zero")
        self.test_duration = duration
    
    def to_dict(self) -> Dict:
        """Convert dataset to dictionary"""
        return {
            'test_name': self.test_name,
            'screen_width': self.screen_width,
            'screen_height': self.screen_height,
            'created_at': self.created_at.isoformat(),
            'test_duration': self.test_duration,
            'point_count': self.get_point_count(),
            'data_points': [p.to_dict() for p in self.data_points]
        }


class EyeTrackingMetrics:
    """Calculates metrics from eye tracking data"""
    
    @staticmethod
    def validate_dataset(dataset: EyeTrackingDataset) -> bool:
        """Validate dataset integrity"""
        if not dataset or dataset.get_point_count() == 0:
            raise ValueError("Dataset is empty or invalid")
        return True
    
    @staticmethod
    def calculate_gaze_accuracy(actual_points: List[Tuple[float, float]], 
                               tracked_points: List[Tuple[float, float]],
                               screen_diagonal: float = None) -> float:
        """Calculate gaze accuracy as percentage match between actual and tracked gaze points.
        If screen_diagonal is provided, normalize error relative to screen size."""
        if len(actual_points) != len(tracked_points):
            raise ValueError("Actual and tracked points must have same length")
        
        if len(actual_points) == 0:
            raise ValueError("Points list cannot be empty")
        
        euclidean_distances = []
        for actual, tracked in zip(actual_points, tracked_points):
            distance = math.sqrt((actual[0] - tracked[0])**2 + (actual[1] - tracked[1])**2)
            euclidean_distances.append(distance)
        
        mean_distance = sum(euclidean_distances) / len(euclidean_distances)
        
        # Normalize by screen diagonal if available, otherwise by 10
        divisor = screen_diagonal * 0.1 if screen_diagonal else 10
        accuracy = max(0, 100 - (mean_distance / divisor))
        return round(min(100, accuracy), 2)

    @staticmethod
    def calculate_blink_metrics(data_points: List['EyeTrackingDataPoint'],
                                test_duration: float) -> Dict:
        """Calculate blink frequency and EAR statistics from data points."""
        blink_count = sum(1 for p in data_points if p.is_blink)
        ear_values = [p.average_ear for p in data_points
                      if p.left_ear is not None and p.right_ear is not None and not p.is_blink]
        
        blink_rate = (blink_count / test_duration * 60) if test_duration > 0 else 0
        
        result = {
            'blink_count': blink_count,
            'blink_rate_per_min': round(blink_rate, 2),
        }
        if ear_values:
            result['ear_mean'] = round(float(np.mean(ear_values)), 4)
            result['ear_std'] = round(float(np.std(ear_values)), 4)
            result['ear_min'] = round(float(min(ear_values)), 4)
            result['ear_max'] = round(float(max(ear_values)), 4)
        return result
    
    @staticmethod
    def calculate_fixation_stability(fixation_durations: List[float]) -> Dict:
        """Calculate fixation stability metrics"""
        if not fixation_durations or len(fixation_durations) == 0:
            raise ValueError("Fixation durations list cannot be empty")
        
        mean_fixation = np.mean(fixation_durations)
        std_fixation = np.std(fixation_durations)
        min_fixation = min(fixation_durations)
        max_fixation = max(fixation_durations)
        
        # Stability score: lower std deviation = higher stability
        stability_score = max(0, 100 - (std_fixation / mean_fixation * 100)) if mean_fixation > 0 else 0
        
        return {
            'mean_duration': round(mean_fixation, 3),
            'std_deviation': round(std_fixation, 3),
            'min_duration': round(min_fixation, 3),
            'max_duration': round(max_fixation, 3),
            'stability_score': round(min(100, stability_score), 2)
        }
    
    @staticmethod
    def calculate_saccade_metrics(saccade_velocities: List[float]) -> Dict:
        """Calculate saccade velocity metrics"""
        if not saccade_velocities or len(saccade_velocities) == 0:
            raise ValueError("Saccade velocities list cannot be empty")
        
        mean_velocity = np.mean(saccade_velocities)
        std_velocity = np.std(saccade_velocities)
        max_velocity = max(saccade_velocities)
        
        return {
            'mean_velocity': round(mean_velocity, 2),
            'std_velocity': round(std_velocity, 2),
            'max_velocity': round(max_velocity, 2),
            'saccade_count': len(saccade_velocities)
        }
    
    @staticmethod
    def calculate_pupil_metrics(dataset: EyeTrackingDataset) -> Dict:
        """Calculate pupil diameter metrics"""
        EyeTrackingMetrics.validate_dataset(dataset)
        
        left_pupils = [p.left_pupil_diameter for p in dataset.get_data_points()]
        right_pupils = [p.right_pupil_diameter for p in dataset.get_data_points()]
        
        if not left_pupils or not right_pupils:
            raise ValueError("Pupil data not available")
        
        return {
            'left_pupil': {
                'mean': round(np.mean(left_pupils), 2),
                'std': round(np.std(left_pupils), 2),
                'min': round(min(left_pupils), 2),
                'max': round(max(left_pupils), 2)
            },
            'right_pupil': {
                'mean': round(np.mean(right_pupils), 2),
                'std': round(np.std(right_pupils), 2),
                'min': round(min(right_pupils), 2),
                'max': round(max(right_pupils), 2)
            }
        }
    
    @staticmethod
    def calculate_overall_performance(dataset: EyeTrackingDataset, 
                                    gaze_accuracy: float,
                                    fixation_stability: Dict,
                                    saccade_metrics: Dict) -> Dict:
        """Calculate overall eye tracking performance score"""
        EyeTrackingMetrics.validate_dataset(dataset)
        
        # Weighted scoring
        accuracy_weight = 0.4
        stability_weight = 0.3
        saccade_weight = 0.3
        
        # Normalize saccade consistency (lower std = higher consistency)
        saccade_consistency = max(0, 100 - (saccade_metrics['std_velocity'] / 10 * 100)) if saccade_metrics['std_velocity'] > 0 else 100
        
        overall_score = (
            gaze_accuracy * accuracy_weight +
            fixation_stability['stability_score'] * stability_weight +
            min(100, saccade_consistency) * saccade_weight
        )
        
        # Classify performance
        if overall_score >= 90:
            classification = "Excellent"
        elif overall_score >= 75:
            classification = "Good"
        elif overall_score >= 60:
            classification = "Fair"
        else:
            classification = "Poor"
        
        return {
            'overall_score': round(overall_score, 2),
            'classification': classification,
            'gaze_accuracy': gaze_accuracy,
            'fixation_stability': fixation_stability['stability_score'],
            'saccade_consistency': round(min(100, saccade_consistency), 2)
        }


def create_sample_dataset() -> EyeTrackingDataset:
    """Create a sample eye tracking dataset for testing"""
    dataset = EyeTrackingDataset("Sample Eye Tracking Test", 1920, 1080)
    dataset.set_test_duration(30.0)
    
    # Generate sample data points
    for i in range(100):
        timestamp = i * 0.3  # 300ms between samples
        gaze_x = 960 + np.random.normal(0, 50)
        gaze_y = 540 + np.random.normal(0, 50)
        left_pupil = 3.5 + np.random.normal(0, 0.2)
        right_pupil = 3.5 + np.random.normal(0, 0.2)
        fixation_duration = np.random.uniform(0.1, 0.5)
        saccade_velocity = np.random.uniform(100, 400)
        
        data_point = EyeTrackingDataPoint(
            timestamp=timestamp,
            gaze_x=gaze_x,
            gaze_y=gaze_y,
            left_pupil_diameter=left_pupil,
            right_pupil_diameter=right_pupil,
            fixation_duration=fixation_duration,
            saccade_velocity=saccade_velocity
        )
        dataset.add_data_point(data_point)
    
    return dataset
