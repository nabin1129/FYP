"""
Eye Tracking Test Module - Test Cases and Usage Examples
"""

import pytest
from eye_tracking_model import (
    EyeTrackingDataPoint,
    EyeTrackingDataset,
    EyeTrackingMetrics,
    create_sample_dataset
)
import numpy as np


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


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
