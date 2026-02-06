# Eye Tracking Test Integration Guide

This guide explains how to integrate the Eye Tracking Test module with your Netracare application (Flutter frontend and Flask backend).

## 📁 File Structure

### Backend (Python/Flask)
```
netracare_backend/
├── eye_tracking_model.py          # Core eye tracking logic
├── eye_tracking_routes.py         # Flask API endpoints
├── db_model.py                    # Database models (updated)
└── app.py                         # Main Flask app
```

### Frontend (Flutter)
```
netracare/lib/
├── pages/
│   ├── eye_tracking_page.dart       # Intro/Setup/Calibration screens
│   └── eye_tracking_test_page.dart  # Main test execution
└── services/
    └── eye_tracking_service.dart    # API communication
```

---

## 🔧 Backend Setup

### 1. Update Flask App (`app.py`)

Add the eye tracking blueprint to your Flask application:

```python
from flask import Flask
from flask_cors import CORS
from db_model import db
from eye_tracking_routes import eye_tracking_bp

app = Flask(__name__)
CORS(app)

# Initialize database
db.init_app(app)

# Register blueprints
app.register_blueprint(eye_tracking_bp)

if __name__ == '__main__':
    app.run(debug=True)
```

### 2. Database Migration

Run migrations to create the `eye_tracking_tests` table:

```bash
cd netracare_backend
flask db upgrade
```

Or if using raw SQL:

```sql
CREATE TABLE eye_tracking_tests (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    test_name VARCHAR(255) NOT NULL,
    test_duration FLOAT NOT NULL,
    gaze_accuracy FLOAT,
    fixation_stability_score FLOAT,
    saccade_consistency_score FLOAT,
    overall_performance_score FLOAT,
    performance_classification VARCHAR(50),
    left_pupil_metrics TEXT,
    right_pupil_metrics TEXT,
    raw_data TEXT,
    screen_width INTEGER,
    screen_height INTEGER,
    status VARCHAR(50) DEFAULT 'completed',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user(id)
);
```

### 3. Install Required Packages

```bash
pip install numpy
```

---

## 📱 Frontend Setup

### 1. Update Main App Routes

In your main Flutter routing file, add the eye tracking routes:

```dart
// In your main route configuration
Route(
  path: "/eye-tracking",
  element: (
    <ProtectedRoute>
      <Layout>
        <EyeTrackingTest />
      </Layout>
    </ProtectedRoute>
  )
)
```

Or in Flutter (pubspec.yaml), add navigation:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  flutter_secure_storage: ^9.0.0
```

### 2. Update Home/Dashboard Page

Add the Eye Tracking Test card to your home/dashboard:

```dart
import 'pages/eye_tracking_page.dart';

// In your home page, add navigation button:
ListTile(
  leading: const Icon(Icons.track_changes, color: Colors.blue),
  title: const Text('Eye Tracking Test'),
  subtitle: const Text('Track your eye movements'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EyeTrackingPage(),
      ),
    );
  },
)
```

### 3. Configure API Endpoint

Update `lib/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'http://localhost:5000/api';
  // ... other configs
}
```

---

## 🔄 API Endpoints

### POST `/api/eye-tracking/save`
Save eye tracking test results
```json
{
  "test_name": "Eye Tracking Test",
  "gaze_accuracy": 85.5,
  "data_points_collected": 150,
  "successful_tracking": 140,
  "test_duration": 30,
  "classification": "Good",
  "screen_width": 1920,
  "screen_height": 1080
}
```

### POST `/api/eye-tracking/upload-data`
Upload and process raw eye tracking data
```json
{
  "test_name": "Eye Tracking Test",
  "test_duration": 30,
  "screen_width": 1920,
  "screen_height": 1080,
  "data_points": [
    {
      "timestamp": 0.0,
      "gaze_x": 960,
      "gaze_y": 540,
      "left_pupil_diameter": 3.5,
      "right_pupil_diameter": 3.5,
      "fixation_duration": 0.3,
      "saccade_velocity": 250
    }
    // ... more data points
  ]
}
```

### GET `/api/eye-tracking/history`
Retrieve test history
- Query params: `limit`, `offset`

### GET `/api/eye-tracking/latest`
Get the most recent test result

### GET `/api/eye-tracking/statistics`
Get user's eye tracking statistics

### DELETE `/api/eye-tracking/<test_id>`
Delete a specific test result

### POST `/api/eye-tracking/<test_id>/generate-report`
Generate PDF report

### POST `/api/eye-tracking/calibrate`
Calibrate the eye tracker

---

## 📊 Test Flow

### 1. User navigates to Eye Tracking Test
- Shows introduction screen
- Explains test requirements
- Lists prerequisites

### 2. Setup Screen
- Displays setup checklist
- Ensures proper conditions
- Requests camera permission

### 3. Calibration
- Guides user through calibration
- 9-point calibration pattern
- Checks accuracy

### 4. Test Execution
- 4 phases of eye tracking:
  - Calibration (center focus)
  - Horizontal movement
  - Vertical movement
  - Circular movement

### 5. Results
- Displays gaze accuracy percentage
- Shows performance classification
- Provides detailed metrics
- Options to save, retry, or return home

---

## 📈 Metrics Calculated

### Gaze Accuracy
- Measures how well eyes are tracked
- Compares actual vs tracked gaze points
- Expressed as percentage (0-100%)

### Fixation Stability
- Measures steadiness of eye fixations
- Lower standard deviation = higher stability
- Score: 0-100

### Saccade Consistency
- Measures consistency of rapid eye movements
- Based on velocity variance
- Score: 0-100

### Overall Performance
- Weighted combination of all metrics
- Classification: Excellent (90+), Good (75-89), Fair (60-74), Poor (<60)

---

## 🔐 Authentication

All API endpoints require authentication:

```dart
// The service automatically adds the token to requests
final result = await EyeTrackingService.saveTestResults(result);
```

Token is stored securely in Flutter Secure Storage.

---

## 🐛 Troubleshooting

### Backend Issues

**Database Connection Error**
- Ensure Flask-SQLAlchemy is configured
- Check database URL in `config.py`

**Missing Modules**
```bash
pip install flask numpy scipy
```

**CORS Issues**
- Ensure Flask-CORS is installed and enabled
- Frontend URL should be in CORS allowed origins

### Frontend Issues

**API Connection Failed**
- Check backend is running on correct port
- Verify `api_config.dart` has correct URL
- Check network connectivity

**Navigation Issues**
- Ensure all imports are correct
- Verify page names match exactly

---

## 🚀 Example Usage

### Python (Backend Testing)
```python
from eye_tracking_model import (
    EyeTrackingDataPoint,
    EyeTrackingDataset,
    EyeTrackingMetrics,
    create_sample_dataset
)

# Create sample dataset
dataset = create_sample_dataset()

# Extract metrics
actual_gaze = [(p.gaze_x, p.gaze_y) for p in dataset.get_data_points()]
gaze_accuracy = EyeTrackingMetrics.calculate_gaze_accuracy(actual_gaze, actual_gaze)

print(f"Gaze Accuracy: {gaze_accuracy}%")
```

### Dart (Frontend Usage)
```dart
import 'services/eye_tracking_service.dart';

// Save results
final result = EyeTrackingResult(
  gazeAccuracy: 85.5,
  dataPointsCollected: 150,
  successfulTracking: 140,
  testDuration: 30,
  classification: 'Good',
  rawData: {},
);

try {
  final response = await EyeTrackingService.saveTestResults(result);
  print('Results saved: ${response['test_id']}');
} catch (e) {
  print('Error: $e');
}
```

---

## 📝 Notes

- All timestamps are stored in UTC
- Test results are permanently stored in database
- Raw data can be up to several MB in size
- Consider implementing data compression for large datasets
- PDF report generation requires additional library (reportlab)

---

## 🔗 Related Files

- [eye_tracking_model.py](eye_tracking_model.py) - Core logic
- [eye_tracking_routes.py](eye_tracking_routes.py) - API routes
- [test_eye_tracking.py](test_eye_tracking.py) - Unit tests
- [eye_tracking_examples.py](eye_tracking_examples.py) - Usage examples

---

For more information about the eye tracking implementation, see the model documentation.
