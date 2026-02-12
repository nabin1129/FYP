# Blink Detection - Python Dependencies Installation Guide

## Required Python Packages

```bash
pip install dlib scipy opencv-python
```

## Download Required Model File

The blink detection system requires dlib's 68-point facial landmark detector model.

### Method 1: Direct Download
1. Download `shape_predictor_68_face_landmarks.dat` from:
   https://github.com/italojs/facial-landmarks-recognition/raw/master/shape_predictor_68_face_landmarks.dat

2. Place the file in: `d:\3rd_Year\FYP\netracare_backend\`

### Method 2: Using dlib_models
```bash
pip install dlib-models
```

Then in Python:
```python
import dlib_models
# This will download the model automatically
```

## Installation Steps

1. **Install Python packages:**
```bash
cd d:\3rd_Year\FYP\netracare_backend
pip install dlib scipy opencv-python
```

2. **Download the landmark model:**
   - Download from the link above
   - Or use: `wget https://github.com/italojs/facial-landmarks-recognition/raw/master/shape_predictor_68_face_landmarks.dat`

3. **Verify installation:**
```bash
python -c "import dlib, scipy, cv2; print('✓ All packages installed')"
```

4. **Restart Flask server:**
```bash
python app.py
```

## Fallback Mode

If dlib installation fails (common on some systems), the system will automatically use a **fallback detection method** based on brightness analysis. This is less accurate but will allow the system to function.

## Troubleshooting

### dlib installation fails
- **Windows:** Install Visual Studio Build Tools
- **Linux:** `sudo apt-get install build-essential cmake`
- **Mac:** `brew install cmake`

Then retry: `pip install dlib`

### Model file not found
The system will show: `⚠️ dlib not available` but will continue with fallback mode.

## System Status

After starting the Flask server, you should see:
- ✓ `Blink detection routes registered`
- ✓ `BlinkDetector initialized`

Or if dlib is unavailable:
- ⚠️ `dlib not available: [error message]`
- ⚠️ `Blink detection will use fallback method`

The system will work in both cases, but real EAR-based detection provides better accuracy.
