# Eye Tracking Database Integration

## Overview

The eye tracking system now includes complete database integration to save and retrieve tracking sessions.

## Database Schema

### CameraEyeTrackingSession Table

Stores camera-based eye tracking session data:

```python
{
    'id': Integer (Primary Key),
    'user_id': Integer (Foreign Key to User),
    'session_name': String,
    'duration_seconds': Float,
    'start_time': DateTime,
    'end_time': DateTime,
    
    # Blink Metrics
    'total_blinks': Integer,
    'blink_rate_per_minute': Float,
    
    # EAR Statistics (for each eye)
    'left_eye_ear_*': Float (mean, std, min, max),
    'right_eye_ear_*': Float (mean, std, min, max),
    'average_ear_*': Float (mean, std, min, max),
    
    # Gaze Distribution
    'gaze_distribution': JSON,
    
    # Detection Metrics
    'total_frames': Integer,
    'frames_with_face': Integer,
    'detection_rate': Float,
    
    # Detailed Events
    'blink_events': JSON (array),
    'gaze_events': JSON (array),
    
    # Settings
    'camera_id': Integer,
    'ear_threshold': Float,
    
    'status': String,
    'notes': Text,
    'created_at': DateTime,
    'updated_at': DateTime
}
```

## API Endpoints

### 1. Create Session

**POST** `/camera-eye-tracking/sessions`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
    "session_name": "Morning Eye Tracking",
    "duration_seconds": 15.5,
    "total_blinks": 5,
    "blink_rate_per_minute": 19.4,
    "ear_statistics": {
        "left_eye": {
            "mean": 0.287,
            "std": 0.045,
            "min": 0.156,
            "max": 0.342
        },
        "right_eye": {
            "mean": 0.291,
            "std": 0.042,
            "min": 0.162,
            "max": 0.338
        },
        "average": {
            "mean": 0.289,
            "std": 0.043,
            "min": 0.159,
            "max": 0.340
        }
    },
    "gaze_distribution": {
        "center": 145,
        "left": 23,
        "right": 18,
        "up": 8,
        "down": 6
    },
    "total_frames": 200,
    "frames_with_face": 195,
    "camera_id": 0,
    "ear_threshold": 0.21,
    "notes": "Test session with good lighting"
}
```

**Response:**
```json
{
    "message": "Eye tracking session saved successfully",
    "session_id": 1,
    "session": { /* session data */ }
}
```

### 2. Get All Sessions

**GET** `/camera-eye-tracking/sessions`

**Query Parameters:**
- `limit`: Maximum number of sessions (default: 50)
- `offset`: Offset for pagination (default: 0)
- `include_events`: Include detailed events (true/false, default: false)

**Response:**
```json
{
    "sessions": [
        {
            "id": 1,
            "session_name": "Morning Eye Tracking",
            "duration_seconds": 15.5,
            "blink_metrics": { /* blink data */ },
            "ear_statistics": { /* EAR data */ },
            "gaze_distribution": { /* gaze data */ }
        }
    ],
    "total": 10,
    "limit": 50,
    "offset": 0
}
```

### 3. Get Specific Session

**GET** `/camera-eye-tracking/sessions/<session_id>`

**Query Parameters:**
- `include_events`: Include detailed events (true/false)

**Response:**
```json
{
    "id": 1,
    "session_name": "Morning Eye Tracking",
    "duration_seconds": 15.5,
    "blink_metrics": {
        "total_blinks": 5,
        "blink_rate_per_minute": 19.4
    },
    "ear_statistics": { /* detailed EAR stats */ },
    "gaze_distribution": {
        "center": 145,
        "left": 23,
        "right": 18
    },
    "detection_metrics": {
        "total_frames": 200,
        "frames_with_face": 195,
        "detection_rate": 97.5
    },
    "created_at": "2026-01-18T10:30:00"
}
```

### 4. Delete Session

**DELETE** `/camera-eye-tracking/sessions/<session_id>`

**Response:**
```json
{
    "message": "Session deleted successfully"
}
```

### 5. Update Session

**PUT** `/camera-eye-tracking/sessions/<session_id>/update`

**Request Body:**
```json
{
    "session_name": "Updated Name",
    "notes": "Added some notes",
    "status": "completed"
}
```

### 6. Get Statistics

**GET** `/camera-eye-tracking/statistics`

**Response:**
```json
{
    "total_sessions": 15,
    "total_blinks": 78,
    "average_blink_rate_per_minute": 18.5,
    "average_detection_rate": 95.2,
    "total_duration_seconds": 245.8,
    "average_ear_values": {
        "left_eye": 0.287,
        "right_eye": 0.291,
        "overall": 0.289
    },
    "recent_sessions": [ /* last 5 sessions */ ]
}
```

### 7. Compare Sessions

**POST** `/camera-eye-tracking/compare`

**Request Body:**
```json
{
    "session_ids": [1, 2, 3]
}
```

**Response:**
```json
{
    "sessions": [ /* full session data for each */ ],
    "comparison_metrics": {
        "blink_rates": [19.4, 16.2, 21.5],
        "detection_rates": [97.5, 95.3, 98.1],
        "average_ears": [0.289, 0.295, 0.283],
        "durations": [15.5, 18.2, 12.8]
    }
}
```

## Python Usage

### Saving Results After Tracking

```python
from eye_tracking_opencv import EyeTracker
from eye_tracking_db_helper import save_eye_tracking_session
from app import app

# Run tracking
tracker = EyeTracker(camera_id=0)
tracker.run_live_tracking(duration=15)

# Get statistics
stats = tracker.get_statistics()

# Save to database
with app.app_context():
    session_id = save_eye_tracking_session(
        user_id=1,
        stats=stats,
        session_name="My Tracking Session",
        notes="Performed in good lighting"
    )
    
    print(f"Session saved with ID: {session_id}")
```

### Retrieving Sessions

```python
from eye_tracking_db_helper import get_user_sessions, get_session_by_id
from app import app

# Get all sessions for a user
with app.app_context():
    sessions = get_user_sessions(user_id=1, limit=10)
    
    for session in sessions:
        print(f"Session: {session['session_name']}")
        print(f"Blinks: {session['blink_metrics']['total_blinks']}")
```

### Getting User Statistics

```python
from eye_tracking_db_helper import get_user_statistics
from app import app

with app.app_context():
    stats = get_user_statistics(user_id=1)
    
    print(f"Total Sessions: {stats['total_sessions']}")
    print(f"Average Blink Rate: {stats['average_blink_rate_per_minute']}")
    print(f"Average EAR: {stats['average_ear_values']['overall']}")
```

## Complete Workflow Example

```python
# run_tracking_with_db.py - Complete example script

from eye_tracking_opencv import EyeTracker
from eye_tracking_db_helper import save_eye_tracking_session
from app import app
from db_model import db

# 1. Initialize database
with app.app_context():
    db.create_all()

# 2. Run tracking session
tracker = EyeTracker(camera_id=0)
print("Starting 15-second tracking session...")
tracker.run_live_tracking(duration=15)

# 3. Get results
stats = tracker.get_statistics()

if "error" not in stats:
    # 4. Save to database
    with app.app_context():
        session_id = save_eye_tracking_session(
            user_id=1,  # Replace with actual user ID
            stats=stats,
            session_name="Eye Tracking Session",
            notes=f"Detected {stats['total_blinks']} blinks"
        )
        
        print(f"✓ Session saved! ID: {session_id}")
```

## Running Examples

### Complete Workflow Demo

```bash
python run_tracking_with_db.py
```

Options:
1. Quick Test (5s, no database)
2. Run 10s Session and Save
3. Run 20s Session and Save
4. Custom Duration
5. Complete Workflow Demo
6. View Saved Sessions
7. Exit

### Interactive Camera Tests

```bash
python run_camera_tests.py
```

### Pytest Tests with Database

```bash
pytest test_eye_tracking.py -v -s
```

## Database Migration

If updating an existing database:

```python
from app import app
from db_model import db

with app.app_context():
    # This will create new tables if they don't exist
    db.create_all()
```

## Data Export

Export session to JSON:

```python
from eye_tracking_db_helper import get_session_by_id
from app import app
import json

with app.app_context():
    session = get_session_by_id(session_id=1, user_id=1)
    
    with open('session_export.json', 'w') as f:
        json.dump(session, f, indent=2)
```

## Best Practices

1. **Always use app context** when working with database
2. **Provide meaningful session names** for easy identification
3. **Add notes** to track conditions (lighting, time of day, etc.)
4. **Regular cleanup** of old test sessions
5. **Backup database** before major changes

## Troubleshooting

### Database Locked Error
```python
# Close all connections before accessing
db.session.close()
```

### Session Not Saving
```python
# Check if stats contain errors
if "error" in stats:
    print("Cannot save: No tracking data")
```

### Missing Tables
```python
# Recreate tables
with app.app_context():
    db.drop_all()
    db.create_all()
```

## API Testing with curl

### Create Session
```bash
curl -X POST http://localhost:5000/camera-eye-tracking/sessions \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d @session_data.json
```

### Get Sessions
```bash
curl -X GET http://localhost:5000/camera-eye-tracking/sessions \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Get Statistics
```bash
curl -X GET http://localhost:5000/camera-eye-tracking/statistics \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Next Steps

1. **Flutter Integration**: Connect mobile app to API endpoints
2. **Data Visualization**: Add charts for trends over time
3. **Export Features**: PDF reports, CSV exports
4. **Analysis Tools**: Anomaly detection, health insights
5. **Notifications**: Alerts for unusual patterns

---

**Last Updated**: January 18, 2026
