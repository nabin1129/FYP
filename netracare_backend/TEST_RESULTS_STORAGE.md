# NetraCare Backend - Test Results Storage

## Overview
All test results are now properly saved to the database. This document outlines what data is being stored for each type of test.

## Database Models

### 1. **Visual Acuity Tests** (`VisualAcuityTest`)
**API Endpoint:** `/visual-acuity/tests`

**Stored Data:**
- `id` - Unique test identifier
- `user_id` - User who took the test
- `correct_answers` - Number of correct answers
- `total_questions` - Total number of questions
- `logmar_value` - Calculated LogMAR value
- `snellen_value` - Snellen notation (e.g., "20/20")
- `severity` - Severity classification (Normal, Mild, Moderate, Severe)
- `created_at` - Timestamp when test was taken

**API Operations:**
- `POST /visual-acuity/tests` - Submit new test result
- `GET /visual-acuity/tests` - Get all user's tests (with pagination)
- `GET /visual-acuity/tests/<id>` - Get specific test
- `DELETE /visual-acuity/tests/<id>` - Delete test
- `GET /visual-acuity/tests/statistics` - Get test statistics

---

### 2. **Eye Tracking Tests** (`EyeTrackingTest`)
**API Endpoint:** `/eye-tracking/tests`

**Stored Data:**
- `id` - Unique test identifier
- `user_id` - User who took the test
- `test_name` - Name of the test
- `test_duration` - Duration in seconds
- `gaze_accuracy` - Gaze accuracy percentage
- `fixation_stability_score` - Fixation stability (0-100)
- `saccade_consistency_score` - Saccade consistency (0-100)
- `overall_performance_score` - Overall score (0-100)
- `performance_classification` - Classification (Excellent, Good, Fair, Poor)
- `left_pupil_metrics` - Left pupil metrics (JSON)
- `right_pupil_metrics` - Right pupil metrics (JSON)
- `raw_data` - Raw eye tracking data points (JSON)
- `screen_width` - Screen width used
- `screen_height` - Screen height used
- `status` - Test status (completed, pending, failed)
- `created_at` - Timestamp when test was taken
- `updated_at` - Last update timestamp

**API Operations:**
- `POST /eye-tracking/tests` - Submit new test result
- `POST /eye-tracking/upload-data` - Upload raw data and auto-calculate metrics
- `GET /eye-tracking/tests` - Get all user's tests (with pagination)
- `GET /eye-tracking/tests/<id>` - Get specific test
- `DELETE /eye-tracking/tests/<id>` - Delete test
- `GET /eye-tracking/tests/latest` - Get most recent test
- `GET /eye-tracking/tests/statistics` - Get test statistics

---

### 3. **Camera Eye Tracking Sessions** (`CameraEyeTrackingSession`)
**API Endpoint:** `/camera-eye-tracking/sessions`

**Stored Data:**
- `id` - Unique session identifier
- `user_id` - User who took the test
- `session_name` - Name of the session
- `duration_seconds` - Duration in seconds
- `start_time` - Session start time
- `end_time` - Session end time
- **Blink Metrics:**
  - `total_blinks` - Total blinks detected
  - `blink_rate_per_minute` - Blink rate per minute
- **Eye Aspect Ratio (EAR) Statistics:**
  - `left_eye_ear_mean`, `left_eye_ear_std`, `left_eye_ear_min`, `left_eye_ear_max`
  - `right_eye_ear_mean`, `right_eye_ear_std`, `right_eye_ear_min`, `right_eye_ear_max`
  - `average_ear_mean`, `average_ear_std`, `average_ear_min`, `average_ear_max`
- **Gaze Tracking:**
  - `gaze_distribution` - Gaze direction distribution (JSON)
  - `gaze_events` - Detailed gaze events (JSON, optional)
- **Detection Metrics:**
  - `total_frames` - Total frames processed
  - `frames_with_face` - Frames with face detected
  - `detection_rate` - Detection rate percentage
- **Blink Events:**
  - `blink_events` - Detailed blink events with timestamps (JSON, optional)
- **Settings:**
  - `camera_id` - Camera device ID used
  - `ear_threshold` - EAR threshold used
- `status` - Session status
- `notes` - Additional notes
- `created_at` - Timestamp when session was created
- `updated_at` - Last update timestamp

**API Operations:**
- `POST /camera-eye-tracking/sessions` - Create new session
- `GET /camera-eye-tracking/sessions` - Get all user's sessions (with pagination)
- `GET /camera-eye-tracking/sessions/<id>` - Get specific session
- `DELETE /camera-eye-tracking/sessions/<id>` - Delete session
- `PUT /camera-eye-tracking/sessions/<id>/update` - Update session notes/name
- `GET /camera-eye-tracking/sessions/latest` - Get most recent session
- `GET /camera-eye-tracking/sessions/statistics` - Get session statistics

---

## Authentication
All endpoints require authentication using the `Authorization` header with a Bearer token:
```
Authorization: Bearer <token>
```

## Data Retention
- All test results are permanently stored in the SQLite database (`db.sqlite3`)
- Users can delete their own test results through the API
- No automatic data expiration or cleanup

## API Documentation
Full API documentation is available at:
```
http://127.0.0.1:5000/docs
```

## Summary
✅ Visual Acuity Tests - **SAVED**
✅ Eye Tracking Tests (Dataset-based) - **SAVED**
✅ Camera Eye Tracking Sessions (OpenCV/MediaPipe) - **SAVED**
✅ All test metrics and raw data - **SAVED**
✅ User profile information - **SAVED**

All test results are being properly saved to the database with comprehensive metrics and raw data storage.
