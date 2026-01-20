# Eye Tracking with Database - Quick Start Guide

## 🎯 What's New

Eye tracking results are now automatically saved to the database!

## 📊 Features Added

1. **Database Model**: `CameraEyeTrackingSession` table
2. **API Endpoints**: Full CRUD operations for sessions
3. **Helper Functions**: Easy database integration
4. **Complete Examples**: Ready-to-run scripts

## 🚀 Quick Start

### Option 1: Run Complete Workflow (Recommended)

```bash
cd "d:\3rd Year\FYP\netracare_backend"
python run_tracking_with_db.py
```

**Menu Options:**
- Quick Test (5s, no database)
- Run & Save (10s or 20s)
- Custom Duration
- Complete Demo
- View Saved Sessions

### Option 2: Run Camera Tests

```bash
python run_camera_tests.py
```

Interactive tests with visual feedback.

### Option 3: Run Pytest

```bash
pytest test_eye_tracking.py -v -s
```

## 📁 Files Created/Modified

### New Files:
1. `camera_eye_tracking_routes.py` - API endpoints
2. `eye_tracking_db_helper.py` - Database helpers
3. `run_tracking_with_db.py` - Complete workflow example
4. `DATABASE_INTEGRATION.md` - Full documentation

### Modified Files:
1. `db_model.py` - Added `CameraEyeTrackingSession` model
2. `app.py` - Registered new routes
3. `test_eye_tracking.py` - Added camera tests

## 💾 Database Schema

```python
CameraEyeTrackingSession:
  - id, user_id, session_name
  - duration_seconds, start_time, end_time
  - total_blinks, blink_rate_per_minute
  - left_eye_ear_* (mean, std, min, max)
  - right_eye_ear_* (mean, std, min, max)
  - average_ear_* (mean, std, min, max)
  - gaze_distribution (JSON)
  - blink_events, gaze_events (JSON)
  - detection_metrics
  - camera_id, ear_threshold
  - status, notes
```

## 🔌 API Endpoints

```
POST   /camera-eye-tracking/sessions           Create session
GET    /camera-eye-tracking/sessions           List all sessions
GET    /camera-eye-tracking/sessions/<id>      Get specific session
DELETE /camera-eye-tracking/sessions/<id>      Delete session
PUT    /camera-eye-tracking/sessions/<id>/update  Update session
GET    /camera-eye-tracking/statistics         Get user statistics
POST   /camera-eye-tracking/compare            Compare sessions
```

## 📝 Usage Example

```python
from eye_tracking_opencv import EyeTracker
from eye_tracking_db_helper import save_eye_tracking_session
from app import app

# Run tracking
tracker = EyeTracker(camera_id=0)
tracker.run_live_tracking(duration=15)

# Get stats
stats = tracker.get_statistics()

# Save to database
with app.app_context():
    session_id = save_eye_tracking_session(
        user_id=1,
        stats=stats,
        session_name="My Session",
        notes="Test run"
    )
```

## 🧪 Testing

### 1. Unit Tests (No Camera)
```bash
pytest test_eye_tracking.py -k "not Real" -v
```

### 2. Camera Integration Tests
```bash
pytest test_eye_tracking.py::TestRealCameraIntegration -v -s
```

### 3. Specific Test
```bash
pytest test_eye_tracking.py::TestEyeTracker::test_real_blink_detection -v -s
```

## 📊 What Gets Saved

For each tracking session:

✅ **Blink Metrics**
- Total blinks
- Blink rate per minute

✅ **EAR Statistics** (both eyes)
- Mean, std deviation, min, max
- For left eye, right eye, and average

✅ **Gaze Distribution**
- Percentage time looking: center, left, right, up, down

✅ **Detection Metrics**
- Total frames processed
- Frames with face detected
- Detection rate percentage

✅ **Optional Events**
- Detailed blink timestamps
- Gaze movement history

## 🔍 Viewing Results

### In Python:
```python
from eye_tracking_db_helper import get_user_sessions
from app import app

with app.app_context():
    sessions = get_user_sessions(user_id=1)
    for session in sessions:
        print(session['session_name'])
```

### Via API:
```bash
curl http://localhost:5000/camera-eye-tracking/sessions \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Via Script:
```bash
python run_tracking_with_db.py
# Select option 6: View Saved Sessions
```

## 🎮 Interactive Demo

```bash
python run_tracking_with_db.py
```

Then select **Option 5: Complete Workflow Demo**

This will:
1. Initialize database
2. Create test user
3. Run 10s tracking session
4. Save results to database
5. Display saved sessions

## 📈 API Documentation

View full API documentation:
```bash
python app.py
# Then visit: http://localhost:5000/docs
```

## ⚙️ Configuration

### Default Settings:
- Camera ID: 0 (default webcam)
- EAR Threshold: 0.21
- Detection confidence: 0.5

### Customization in code:
```python
tracker = EyeTracker(camera_id=0)
tracker.EAR_THRESHOLD = 0.25  # More sensitive
tracker.EAR_CONSEC_FRAMES = 3  # More confirmation frames
```

## 🔄 Complete Workflow

```
┌─────────────────────┐
│  Run Eye Tracking   │
│   (OpenCV +         │
│    MediaPipe)       │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  Get Statistics     │
│  (EAR, Blinks,      │
│   Gaze Direction)   │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  Save to Database   │
│  (SQLite via        │
│   Flask-SQLAlchemy) │
└──────────┬──────────┘
           │
           ↓
┌─────────────────────┐
│  Access via API     │
│  (REST endpoints    │
│   for Flutter app)  │
└─────────────────────┘
```

## 🐛 Troubleshooting

### Camera not working?
```bash
python -c "import cv2; cap=cv2.VideoCapture(0); print('OK' if cap.isOpened() else 'FAIL')"
```

### Database not initializing?
```python
from app import app
from db_model import db

with app.app_context():
    db.create_all()
```

### MediaPipe errors?
```bash
pip install mediapipe==0.10.9
```

## 📚 Documentation Files

- `README_EYE_TRACKING.md` - Main eye tracking docs
- `DATABASE_INTEGRATION.md` - Database integration details
- `TESTING_GUIDE.md` - Testing instructions
- `QUICK_START.md` - This file

## 🎯 Next Steps

1. ✅ Run complete workflow demo
2. ✅ Test API endpoints
3. ✅ Integrate with Flutter app
4. ✅ Add data visualization
5. ✅ Implement user authentication

## 💡 Tips

- **Good lighting** improves detection
- **Face camera directly** for best results
- **Blink naturally** during tests
- **Normal range**: 15-20 blinks/minute
- **Open eye EAR**: 0.25-0.35
- **Closed eye EAR**: <0.21

## 📞 Support

- Check `DATABASE_INTEGRATION.md` for detailed API docs
- Run `python run_tracking_with_db.py` for interactive demo
- View API docs at `http://localhost:5000/docs`

---

**Status**: ✅ Fully Implemented and Ready to Use

**Last Updated**: January 18, 2026
