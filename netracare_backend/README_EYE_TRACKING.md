# Eye Movement and Blink Tracking System

A comprehensive eye tracking system using **OpenCV** and **MediaPipe** for facial landmark detection with **manual Eye Aspect Ratio (EAR)** calculation for blink detection and eye movement tracking.

## Features

### ✨ Core Capabilities

- **Real-time Facial Landmark Detection** using MediaPipe Face Mesh
- **Manual Eye Aspect Ratio (EAR) Calculation** for accurate blink detection
- **Eye Movement Tracking** with gaze direction estimation
- **Blink Detection and Counting** with configurable thresholds
- **Comprehensive Statistics** including blink rate, EAR analysis, and gaze patterns
- **Live Video Visualization** with annotations

### 🔬 Technical Implementation

- **MediaPipe Face Mesh**: Detects 468 facial landmarks including eye and iris landmarks
- **Manual EAR Formula**: 
  ```
  EAR = (||p2 - p6|| + ||p3 - p5||) / (2 * ||p1 - p4||)
  ```
  Where p1-p6 are the 6 eye landmark points
- **OpenCV**: Video capture and image processing
- **NumPy**: Efficient numerical computations

## Installation

### Prerequisites

- Python 3.7+
- Webcam/Camera

### Dependencies

Install required packages:

```bash
pip install -r requirements.txt
```

Or manually:

```bash
pip install opencv-python mediapipe numpy Flask Flask-SQLAlchemy Flask-Cors Flask-RESTX bcrypt PyJWT pytest
```

## Project Structure

```
netracare_backend/
├── eye_tracking_opencv.py      # Main eye tracking implementation
├── eye_tracking_model.py       # Data models and metrics
├── test_eye_tracking.py        # Comprehensive test suite
├── demo_eye_tracking.py        # Usage examples and demos
├── requirements.txt            # Project dependencies
└── README_EYE_TRACKING.md     # This file
```

## Usage

### Quick Start

Run the interactive demo:

```bash
python demo_eye_tracking.py
```

### Run 30-Second Demo

```bash
python eye_tracking_opencv.py
```

### Programmatic Usage

```python
from eye_tracking_opencv import EyeTracker

# Create tracker instance
tracker = EyeTracker(camera_id=0)

# Run live tracking for 30 seconds
tracker.run_live_tracking(duration=30)

# Get statistics
stats = tracker.get_statistics()
print(f"Total Blinks: {stats['total_blinks']}")
print(f"Blink Rate: {stats['blink_rate_per_minute']:.2f} blinks/min")
print(f"Average EAR: {stats['ear_statistics']['average']['mean']:.3f}")
```

### Manual EAR Calculation Example

```python
from eye_tracking_opencv import EyeAspectRatioCalculator
import numpy as np

# Define eye landmarks (6 points)
eye_landmarks = np.array([
    [0, 0],    # Left corner (p1)
    [10, -5],  # Top left (p2)
    [20, -5],  # Top right (p3)
    [30, 0],   # Right corner (p4)
    [20, 5],   # Bottom right (p5)
    [10, 5]    # Bottom left (p6)
])

# Calculate EAR
calculator = EyeAspectRatioCalculator()
ear = calculator.calculate_ear(eye_landmarks)
print(f"Eye Aspect Ratio: {ear:.3f}")

# Interpret result
if ear > 0.21:
    print("Eye is OPEN")
else:
    print("Eye is CLOSED (Blink detected)")
```

## API Reference

### EyeTracker Class

Main class for eye tracking functionality.

#### Initialization

```python
tracker = EyeTracker(camera_id=0)
```

**Parameters:**
- `camera_id` (int): Camera device ID (default: 0)

#### Methods

##### `start_camera() -> bool`
Initialize and start camera capture.

##### `stop_camera()`
Stop camera capture and release resources.

##### `process_frame(frame) -> Tuple[ndarray, BlinkData, EyeMovementData]`
Process a single frame for eye tracking.

**Returns:**
- Annotated frame
- Blink detection data
- Eye movement data

##### `run_live_tracking(duration: Optional[int] = None)`
Run live eye tracking session.

**Parameters:**
- `duration` (int, optional): Duration in seconds. None for continuous tracking.

##### `get_statistics() -> Dict`
Get comprehensive tracking statistics.

**Returns:**
- Dictionary containing:
  - `duration_seconds`: Total tracking duration
  - `total_blinks`: Number of blinks detected
  - `blink_rate_per_minute`: Blink frequency
  - `ear_statistics`: EAR analysis for both eyes
  - `gaze_distribution`: Gaze direction percentages
  - `data_points`: Number of frames processed

##### `reset_tracking()`
Reset all tracking counters and history.

### EyeAspectRatioCalculator Class

Manual EAR calculation utilities.

#### Static Methods

##### `calculate_distance(point1, point2) -> float`
Calculate Euclidean distance between two points.

##### `calculate_ear(eye_landmarks) -> float`
Calculate Eye Aspect Ratio using the manual formula.

**Parameters:**
- `eye_landmarks` (np.ndarray): Array of 6 eye landmark points

**Returns:**
- Eye Aspect Ratio value (float)

### Configuration Constants

```python
EyeTracker.EAR_THRESHOLD = 0.21        # Blink detection threshold
EyeTracker.EAR_CONSEC_FRAMES = 2      # Frames needed to confirm blink
```

## Understanding Eye Aspect Ratio (EAR)

### What is EAR?

The Eye Aspect Ratio (EAR) is a metric that represents the openness of an eye. It's calculated using the ratio of vertical to horizontal distances between eye landmarks.

### Formula Explanation

```
EAR = (||p2 - p6|| + ||p3 - p5||) / (2 * ||p1 - p4||)
```

- **Numerator**: Sum of two vertical distances (between top and bottom eyelid points)
- **Denominator**: 2 times the horizontal distance (between eye corners)

### Interpretation

- **EAR ≈ 0.3**: Eye is fully open
- **EAR ≈ 0.21**: Threshold for blink detection
- **EAR < 0.21**: Eye is closed (blink detected)
- **EAR ≈ 0.1**: Eye is fully closed

### Blink Detection Logic

1. Calculate EAR for both eyes
2. Average the EAR values
3. If average EAR < threshold for consecutive frames → Blink detected
4. Count confirmed blinks

## Landmark Indices

### MediaPipe Face Mesh Landmarks

The system uses specific landmark indices from MediaPipe Face Mesh:

```python
LEFT_EYE = [33, 160, 158, 133, 153, 144]      # 6 points
RIGHT_EYE = [362, 385, 387, 263, 373, 380]    # 6 points
LEFT_IRIS = [468, 469, 470, 471, 472]         # 5 points
RIGHT_IRIS = [473, 474, 475, 476, 477]        # 5 points
```

### Eye Landmark Layout

```
      p2 ------ p3
     /            \
   p1              p4
     \            /
      p6 ------ p5
```

## Testing

### Run All Tests

```bash
pytest test_eye_tracking.py -v
```

### Run Specific Test Class

```bash
pytest test_eye_tracking.py::TestEyeAspectRatioCalculator -v
```

### Run Demo Tests

```bash
python test_eye_tracking.py
```

This will run demonstrations showing:
- Manual EAR calculation examples
- Eye tracking workflow
- Statistics generation

## Performance Metrics

### Typical Blink Statistics

- **Normal Blink Rate**: 15-20 blinks per minute
- **Blink Duration**: 100-400 milliseconds
- **Average EAR (Open)**: 0.25-0.35
- **Average EAR (Closed)**: 0.05-0.15

### Processing Performance

- **Frame Rate**: ~20-30 FPS (depends on hardware)
- **Detection Latency**: <50ms per frame
- **Memory Usage**: ~200-300 MB

## Troubleshooting

### Camera Not Opening

```python
# Check available cameras
import cv2
for i in range(5):
    cap = cv2.VideoCapture(i)
    if cap.isOpened():
        print(f"Camera {i} is available")
        cap.release()
```

### Low Frame Rate

- Reduce frame resolution
- Close other applications using the camera
- Disable video annotations for better performance

### Inaccurate Blink Detection

- Adjust `EAR_THRESHOLD` (default: 0.21)
- Adjust `EAR_CONSEC_FRAMES` (default: 2)
- Ensure good lighting conditions
- Position face directly in front of camera

## Advanced Configuration

### Custom EAR Threshold

```python
tracker = EyeTracker()
tracker.EAR_THRESHOLD = 0.25  # Higher threshold (more sensitive)
```

### Custom Consecutive Frames

```python
tracker = EyeTracker()
tracker.EAR_CONSEC_FRAMES = 3  # More frames needed to confirm blink
```

### Process Single Image

```python
import cv2
from eye_tracking_opencv import EyeTracker

tracker = EyeTracker()
tracker.start_camera()

# Read single frame
ret, frame = tracker.cap.read()

# Process frame
processed_frame, blink_data, movement_data = tracker.process_frame(frame)

# Display results
if blink_data:
    print(f"Left EAR: {blink_data.left_ear:.3f}")
    print(f"Right EAR: {blink_data.right_ear:.3f}")
    print(f"Is Blinking: {blink_data.is_blinking}")

tracker.stop_camera()
```

## Data Structures

### BlinkData

```python
@dataclass
class BlinkData:
    timestamp: float          # Unix timestamp
    left_ear: float          # Left eye EAR
    right_ear: float         # Right eye EAR
    avg_ear: float           # Average EAR
    is_blinking: bool        # Blink status
    blink_count: int         # Total blinks
```

### EyeMovementData

```python
@dataclass
class EyeMovementData:
    timestamp: float         # Unix timestamp
    left_gaze_x: float      # Left iris X coordinate
    left_gaze_y: float      # Left iris Y coordinate
    right_gaze_x: float     # Right iris X coordinate
    right_gaze_y: float     # Right iris Y coordinate
    gaze_direction: str     # 'center', 'left', 'right', 'up', 'down'
```

## Integration with Backend

### Flask Route Example

```python
from flask import Flask, jsonify
from eye_tracking_opencv import EyeTracker

app = Flask(__name__)

@app.route('/api/eye-tracking/start', methods=['POST'])
def start_tracking():
    tracker = EyeTracker()
    tracker.run_live_tracking(duration=30)
    stats = tracker.get_statistics()
    return jsonify(stats)

@app.route('/api/eye-tracking/stats', methods=['GET'])
def get_stats():
    # Return cached statistics
    return jsonify(cached_stats)
```

## References

### Eye Aspect Ratio

- Soukupová, Tereza, and Jan Čech. "Real-time eye blink detection using facial landmarks." 21st computer vision winter workshop. 2016.

### MediaPipe

- Lugaresi, Camillo, et al. "MediaPipe: A framework for building perception pipelines." arXiv preprint arXiv:1906.08172 (2019).

## License

This project is part of the NetraCare application and follows the same license terms.

## Authors

- FYP Project Team
- Year 3 Development

## Support

For issues, questions, or contributions, please refer to the main project repository.

---

**Last Updated**: January 18, 2026
