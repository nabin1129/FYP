"""
Eye Tracking Test Model - Usage Guide and Examples

This module demonstrates how to use the eye tracking test model for:
- Creating and managing eye tracking datasets
- Calculating eye tracking metrics
- Storing results in the database
"""

from eye_tracking_model import (
    EyeTrackingDataPoint,
    EyeTrackingDataset,
    EyeTrackingMetrics,
    create_sample_dataset
)
import numpy as np


# Example 1: Create a custom dataset from raw eye tracking data
def example_custom_dataset():
    """
    Example: Creating a custom eye tracking dataset from raw sensor data
    """
    print("=" * 60)
    print("Example 1: Creating a Custom Eye Tracking Dataset")
    print("=" * 60)
    
    # Initialize dataset
    dataset = EyeTrackingDataset(
        test_name="Custom Reading Test",
        screen_width=1920,
        screen_height=1080
    )
    dataset.set_test_duration(60.0)  # 60 second test
    
    # Simulate eye tracking data collection (e.g., from eye tracker device)
    # In real scenario, this would come from eye tracker hardware
    for i in range(200):
        timestamp = i * 0.3  # 300ms sampling rate
        
        # Simulate gaze movement (circular pattern)
        angle = (i / 200) * 2 * np.pi
        gaze_x = 960 + 200 * np.cos(angle) + np.random.normal(0, 5)
        gaze_y = 540 + 150 * np.sin(angle) + np.random.normal(0, 5)
        
        # Clamp values to screen bounds
        gaze_x = max(0, min(1920, gaze_x))
        gaze_y = max(0, min(1080, gaze_y))
        
        # Pupil diameter data
        left_pupil = 3.5 + 0.5 * np.sin(angle) + np.random.normal(0, 0.1)
        right_pupil = 3.5 + 0.5 * np.sin(angle) + np.random.normal(0, 0.1)
        
        # Create data point
        data_point = EyeTrackingDataPoint(
            timestamp=timestamp,
            gaze_x=gaze_x,
            gaze_y=gaze_y,
            left_pupil_diameter=left_pupil,
            right_pupil_diameter=right_pupil,
            fixation_duration=np.random.uniform(0.2, 0.6),
            saccade_velocity=np.random.uniform(100, 400)
        )
        
        dataset.add_data_point(data_point)
    
    print(f"✓ Created dataset: {dataset.test_name}")
    print(f"✓ Total data points: {dataset.get_point_count()}")
    print(f"✓ Test duration: {dataset.test_duration} seconds")
    print(f"✓ Screen resolution: {dataset.screen_width}x{dataset.screen_height}")
    return dataset


# Example 2: Calculate gaze accuracy
def example_gaze_accuracy(dataset):
    """
    Example: Calculating gaze accuracy against target points
    
    In a real scenario, the user would look at predefined target points,
    and we compare actual gaze positions with tracked positions.
    """
    print("\n" + "=" * 60)
    print("Example 2: Calculating Gaze Accuracy")
    print("=" * 60)
    
    # Define target points (where user should be looking)
    target_points = [
        (400, 300),    # Top-left
        (1500, 300),   # Top-right
        (400, 800),    # Bottom-left
        (1500, 800),   # Bottom-right
        (960, 540)     # Center
    ]
    
    # Simulate tracked gaze points (with some error)
    tracked_points = [
        (405, 305),    # Small error
        (1495, 310),   # Moderate error
        (395, 805),    # Small error
        (1510, 795),   # Larger error
        (960, 540)     # Perfect tracking
    ]
    
    # Calculate accuracy
    accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(target_points, tracked_points)
    
    print(f"✓ Gaze Accuracy: {accuracy}%")
    print(f"✓ Interpretation: {'Excellent' if accuracy > 90 else 'Good' if accuracy > 80 else 'Fair'} gaze tracking")
    return accuracy


# Example 3: Analyze fixation stability
def example_fixation_stability(dataset):
    """
    Example: Analyzing fixation stability
    
    Fixation stability measures how stable the user's gaze is on a fixed point.
    High stability = good eye tracking quality
    """
    print("\n" + "=" * 60)
    print("Example 3: Fixation Stability Analysis")
    print("=" * 60)
    
    # Extract fixation durations from dataset
    fixation_durations = [p.fixation_duration for p in dataset.get_data_points()]
    
    # Calculate stability metrics
    stability = EyeTrackingMetrics.calculate_fixation_stability(fixation_durations)
    
    print(f"✓ Mean fixation duration: {stability['mean_duration']} seconds")
    print(f"✓ Fixation duration std dev: {stability['std_deviation']} seconds")
    print(f"✓ Min fixation: {stability['min_duration']} seconds")
    print(f"✓ Max fixation: {stability['max_duration']} seconds")
    print(f"✓ Stability Score: {stability['stability_score']}/100")
    print(f"  → Higher score indicates more stable fixations")
    return stability


# Example 4: Analyze saccade metrics
def example_saccade_analysis(dataset):
    """
    Example: Analyzing saccadic eye movements
    
    Saccades are rapid eye movements. Metrics help assess eye movement quality.
    """
    print("\n" + "=" * 60)
    print("Example 4: Saccade Movement Analysis")
    print("=" * 60)
    
    # Extract saccade velocities from dataset
    saccade_velocities = [p.saccade_velocity for p in dataset.get_data_points()]
    
    # Calculate saccade metrics
    saccade_metrics = EyeTrackingMetrics.calculate_saccade_metrics(saccade_velocities)
    
    print(f"✓ Mean saccade velocity: {saccade_metrics['mean_velocity']} degrees/second")
    print(f"✓ Saccade velocity std dev: {saccade_metrics['std_velocity']} degrees/second")
    print(f"✓ Max saccade velocity: {saccade_metrics['max_velocity']} degrees/second")
    print(f"✓ Total saccades detected: {saccade_metrics['saccade_count']}")
    return saccade_metrics


# Example 5: Analyze pupil metrics
def example_pupil_analysis(dataset):
    """
    Example: Analyzing pupil diameter changes
    
    Pupil diameter changes indicate cognitive load and lighting conditions.
    """
    print("\n" + "=" * 60)
    print("Example 5: Pupil Diameter Analysis")
    print("=" * 60)
    
    # Calculate pupil metrics
    pupil_metrics = EyeTrackingMetrics.calculate_pupil_metrics(dataset)
    
    print("Left Pupil:")
    print(f"  Mean diameter: {pupil_metrics['left_pupil']['mean']} mm")
    print(f"  Std deviation: {pupil_metrics['left_pupil']['std']} mm")
    print(f"  Range: {pupil_metrics['left_pupil']['min']}-{pupil_metrics['left_pupil']['max']} mm")
    
    print("\nRight Pupil:")
    print(f"  Mean diameter: {pupil_metrics['right_pupil']['mean']} mm")
    print(f"  Std deviation: {pupil_metrics['right_pupil']['std']} mm")
    print(f"  Range: {pupil_metrics['right_pupil']['min']}-{pupil_metrics['right_pupil']['max']} mm")
    
    return pupil_metrics


# Example 6: Complete performance analysis
def example_complete_performance_analysis(dataset, gaze_accuracy, fixation_stability, saccade_metrics):
    """
    Example: Generating complete eye tracking test report
    """
    print("\n" + "=" * 60)
    print("Example 6: Complete Performance Analysis")
    print("=" * 60)
    
    # Calculate overall performance
    performance = EyeTrackingMetrics.calculate_overall_performance(
        dataset,
        gaze_accuracy,
        fixation_stability,
        saccade_metrics
    )
    
    print(f"\n{'OVERALL PERFORMANCE REPORT':^60}")
    print("-" * 60)
    print(f"Overall Score: {performance['overall_score']}/100")
    print(f"Classification: {performance['classification']}")
    print(f"\nDetailed Breakdown:")
    print(f"  • Gaze Accuracy: {performance['gaze_accuracy']}%")
    print(f"  • Fixation Stability: {performance['fixation_stability']}/100")
    print(f"  • Saccade Consistency: {performance['saccade_consistency']}/100")
    
    # Interpretation
    print(f"\nInterpretation:")
    if performance['overall_score'] >= 90:
        print("  ✓ Excellent eye tracking performance")
        print("  ✓ All metrics within optimal ranges")
        print("  ✓ Ready for advanced ophthalmic testing")
    elif performance['overall_score'] >= 75:
        print("  ✓ Good eye tracking performance")
        print("  ✓ Suitable for most clinical assessments")
    elif performance['overall_score'] >= 60:
        print("  ⚠ Fair eye tracking performance")
        print("  ⚠ May require recalibration or retry")
    else:
        print("  ✗ Poor eye tracking performance")
        print("  ✗ Requires device recalibration and retry")
    
    return performance


# Example 7: Using sample dataset
def example_sample_dataset():
    """
    Example: Using pre-generated sample dataset for quick testing
    """
    print("\n" + "=" * 60)
    print("Example 7: Using Pre-Generated Sample Dataset")
    print("=" * 60)
    
    # Create sample dataset
    dataset = create_sample_dataset()
    
    print(f"✓ Sample dataset created")
    print(f"✓ Data points: {dataset.get_point_count()}")
    print(f"✓ Duration: {dataset.test_duration} seconds")
    
    return dataset


# Main execution
if __name__ == "__main__":
    print("\n" + "█" * 60)
    print("█" + " " * 58 + "█")
    print("█" + " " * 15 + "EYE TRACKING TEST MODEL EXAMPLES" + " " * 11 + "█")
    print("█" + " " * 58 + "█")
    print("█" * 60)
    
    # Run all examples
    dataset = example_custom_dataset()
    gaze_accuracy = example_gaze_accuracy(dataset)
    fixation_stability = example_fixation_stability(dataset)
    saccade_metrics = example_saccade_analysis(dataset)
    pupil_metrics = example_pupil_analysis(dataset)
    performance = example_complete_performance_analysis(
        dataset, gaze_accuracy, fixation_stability, saccade_metrics
    )
    
    # Example with sample data
    sample_dataset = example_sample_dataset()
    
    print("\n" + "█" * 60)
    print("✓ All examples completed successfully!")
    print("█" * 60 + "\n")
