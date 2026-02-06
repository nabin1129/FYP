# Running Eye Tracking Tests

## Overview

The eye tracking system now includes **real camera-based tests** that use your laptop camera to verify functionality.

## Test Types

### 1. Unit Tests (Mock Data)
Tests using simulated data - no camera required.

### 2. Integration Tests (Real Camera)
Tests using your actual laptop camera - interactive and visual.

## Running Tests

### Option 1: Interactive Camera Tests (Recommended)

Run the interactive test suite:

```bash
python run_camera_tests.py
```

**Available Tests:**
1. **Basic Camera Capture** - Verify camera is working
2. **Face Detection Test** - Test MediaPipe face mesh detection
3. **Blink Detection Test** (15s) - Count blinks in real-time
4. **Eye Movement Test** (20s) - Track gaze direction
5. **Complete Session Test** (20s) - Full statistics generation
6. **Run All Tests** - Execute all tests sequentially

### Option 2: PyTest Suite

Run unit tests and camera integration tests:

```bash
# Run all tests (verbose)
pytest test_eye_tracking.py -v

# Run only unit tests (no camera)
pytest test_eye_tracking.py -v -k "not Real"

# Run only camera tests
pytest test_eye_tracking.py -v -k "Real"

# Run specific test class
pytest test_eye_tracking.py::TestRealCameraIntegration -v
```

### Option 3: Quick Demo

Run the demonstration script:

```bash
python test_eye_tracking.py
```

This runs quick demonstrations of:
- Manual EAR calculation
- Eye tracking workflow
- Statistics generation

## Camera Test Requirements

### Hardware
- Working webcam (laptop camera or external)
- Camera ID 0 (default) or specify different ID

### Software
- OpenCV installed: `pip install opencv-python`
- MediaPipe installed: `pip install mediapipe`
- NumPy installed: `pip install numpy`

### Environment
- Good lighting conditions
- Clear view of your face
- No other applications using the camera

## Test Descriptions

### Real Camera Tests (in pytest)

#### `test_camera_availability`
Checks if camera can be opened and accessed.

#### `test_real_camera_capture`
Captures a single frame and verifies dimensions.

#### `test_real_face_detection` (3 seconds)
Detects face in real-time. Prints detection rate.

**Instructions:** Look at camera for 3 seconds.

#### `test_real_blink_detection` (10 seconds)
Detects blinks in real-time. Counts total blinks.

**Instructions:** Blink 3-5 times naturally.

#### `test_real_eye_movement_tracking` (10 seconds)
Tracks gaze direction (center, left, right, up, down).

**Instructions:** Look in different directions.

#### `test_real_ear_values` (5 seconds)
Collects real EAR values and validates range.

**Instructions:** Keep eyes open, look at camera.

#### `test_real_tracking_statistics` (8 seconds)
Generates complete statistics from real session.

**Instructions:** Act naturally (blink, move eyes).

### Quick Camera Tests (TestRealCameraIntegration)

#### `test_quick_camera_test` (3 seconds)
Quick functionality check with frame processing.

#### `test_full_tracking_session` (10 seconds)
Complete tracking with detailed statistics output.

**Output includes:**
- Blink count and rate
- EAR statistics
- Gaze direction distribution
- Detailed progress information

## Interactive Tests (run_camera_tests.py)

### Test 1: Basic Camera Capture
- **Duration:** Until 'q' pressed
- **Purpose:** Verify camera feed
- **Action:** Press 'Q' to continue

### Test 2: Face Detection
- **Duration:** Until 'q' pressed  
- **Purpose:** Test face landmark detection
- **Visual:** Green dots on eyes, EAR values displayed
- **Action:** Look at camera, press 'Q' to continue

### Test 3: Blink Detection
- **Duration:** 15 seconds
- **Purpose:** Count blinks accurately
- **Output:** Real-time blink notifications
- **Expected:** Blink naturally, see count

### Test 4: Eye Movement
- **Duration:** 20 seconds (4s per direction)
- **Purpose:** Track gaze direction
- **Instructions:** Follow on-screen prompts
  - Center → Left → Right → Up → Down
- **Output:** Distribution chart

### Test 5: Complete Session
- **Duration:** 20 seconds
- **Purpose:** Full system test with statistics
- **Action:** Act naturally
- **Output:** Comprehensive statistics report

## Interpreting Results

### Blink Rate
- **Normal:** 15-20 blinks/minute
- **Low (<10):** May indicate concentration or dry eyes
- **High (>30):** May indicate stress or eye strain

### Eye Aspect Ratio (EAR)
- **Open eyes:** 0.25 - 0.35
- **Threshold:** 0.21 (configurable)
- **Closed eyes:** 0.05 - 0.15

### Detection Rate
- **Good:** >80% frames with face detected
- **Fair:** 50-80% frames
- **Poor:** <50% frames (check lighting, position)

## Troubleshooting

### Camera Not Opening
```bash
# Test camera manually
python -c "import cv2; cap = cv2.VideoCapture(0); print('OK' if cap.isOpened() else 'FAIL'); cap.release()"
```

**Solutions:**
- Close other applications (Zoom, Teams, etc.)
- Try camera_id 1 or 2
- Check camera permissions
- Restart computer

### No Face Detected
**Solutions:**
- Ensure face is clearly visible
- Improve lighting
- Move closer to camera
- Remove glasses if reflecting
- Check camera is not covered

### Low Detection Rate
**Solutions:**
- Better lighting (front lighting preferred)
- Face camera directly
- Remove obstacles
- Clean camera lens
- Adjust room lighting

### Inaccurate Blink Detection
**Solutions:**
- Adjust `EAR_THRESHOLD` in code
- Ensure stable lighting
- Position face at good distance
- Reduce head movement

## Running Specific Tests

### Run only camera availability check:
```bash
pytest test_eye_tracking.py::TestEyeTracker::test_camera_availability -v -s
```

### Run blink detection test:
```bash
pytest test_eye_tracking.py::TestEyeTracker::test_real_blink_detection -v -s
```

### Run full session test:
```bash
pytest test_eye_tracking.py::TestRealCameraIntegration::test_full_tracking_session -v -s
```

### Run all real camera tests:
```bash
pytest test_eye_tracking.py::TestRealCameraIntegration -v -s
```

The `-s` flag shows print statements in real-time.

## Sample Output

```
📹 Recording...
  3.2s - Blinks: 2

📊 Generating statistics...

============================================================
TRACKING RESULTS
============================================================

⏱️  Duration: 10.05 seconds
📸 Frames processed: 287
👁️  Total blinks: 5
💫 Blink rate: 29.9 blinks/min
   (Normal: 15-20 blinks/min)

📈 Eye Aspect Ratio (EAR):
   Mean: 0.287 ± 0.045
   Range: 0.156 - 0.342

👀 Gaze Direction Distribution:
   Center  : ████████████████████████ 73.2%
   Left    : ████ 12.5%
   Right   : ███ 8.9%
   Up      : ██ 3.2%
   Down    : █ 2.2%

✓ Test completed successfully!
```

## Tips for Best Results

1. **Lighting:** Front-facing light source (not behind you)
2. **Position:** 40-60cm from camera
3. **Angle:** Face camera directly
4. **Background:** Plain background helps
5. **Glasses:** May affect detection if reflective
6. **Movement:** Minimize head movement during tests

## Automated Testing

To run tests automatically without interaction:

```bash
# Run only unit tests (no camera interaction)
pytest test_eye_tracking.py -v -k "not Real and not Integration"
```

This runs tests that don't require camera interaction.

## Continuous Integration

For CI/CD pipelines where no camera is available:

```bash
# Skip camera tests
pytest test_eye_tracking.py -v -m "not camera"
```

## Next Steps

After successful camera tests:
1. Integrate with Flask backend
2. Add REST API endpoints
3. Connect to Flutter frontend
4. Implement data persistence
5. Add user authentication

---

**Need Help?**
- Check camera permissions in system settings
- Review main README: `README_EYE_TRACKING.md`
- Run diagnostic: `python run_camera_tests.py` → Option 1
