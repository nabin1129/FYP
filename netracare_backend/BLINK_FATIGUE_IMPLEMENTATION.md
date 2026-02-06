# Blink and Eye Fatigue Detection - Implementation Guide

## Overview
This module implements CNN-based drowsiness detection using eye images. The implementation follows a professional, modular architecture with backend model training, REST API endpoints, and Flutter frontend integration.

## Architecture

### Backend Components

1. **blink_fatigue_model.py**
   - CNN model architecture (4 convolutional blocks + dense layers)
   - Image preprocessing and prediction logic
   - Model training and evaluation functions
   - Singleton pattern for efficient model loading

2. **train_blink_model.py**
   - Standalone training script
   - Uses dataset at `D:\3rd_Year\Dataset\train_data`
   - Saves trained model to `models/blink_fatigue_model.keras`

3. **blink_fatigue_routes.py**
   - Flask-RESTX namespace for API endpoints
   - JWT authentication required for all endpoints
   - RESTful API design

4. **db_model.py** (updated)
   - Added `BlinkFatigueTest` model for storing results
   - Tracks predictions, confidence, probabilities, and fatigue levels

### Frontend Components

1. **blink_fatigue_service.dart**
   - Service layer for API communication
   - Handles image upload and prediction requests
   - Token-based authentication

2. **blink_fatigue_cnn_test_page.dart**
   - Real-time camera capture
   - CNN model integration
   - Results visualization with probabilities

## API Endpoints

All endpoints require JWT authentication via Bearer token.

### POST /blink-fatigue/predict
Predict drowsiness without saving to database.

**Request:**
- Multipart form data
- `image`: Eye image file (JPG, JPEG, PNG)

**Response:**
```json
{
  "prediction": "drowsy",
  "confidence": 0.95,
  "probabilities": {
    "drowsy": 0.95,
    "notdrowsy": 0.05
  },
  "fatigue_level": "Critical - High Fatigue",
  "alert": true,
  "timestamp": "2024-01-15T10:30:00"
}
```

### POST /blink-fatigue/test/submit
Submit test and save results to database.

**Request:**
- Multipart form data
- `image`: Eye image file
- `test_duration` (optional): Test duration in seconds

**Response:**
```json
{
  "id": 1,
  "user_id": 1,
  "prediction": "drowsy",
  "confidence": 0.95,
  "probabilities": {
    "drowsy": 0.95,
    "notdrowsy": 0.05
  },
  "fatigue_level": "Critical - High Fatigue",
  "alert_triggered": true,
  "test_duration": 2.5,
  "created_at": "2024-01-15T10:30:00"
}
```

### GET /blink-fatigue/history
Get user's test history.

**Response:**
```json
{
  "tests": [...],
  "total_tests": 10,
  "drowsy_count": 3,
  "alert_count": 2
}
```

### GET /blink-fatigue/history/{test_id}
Get specific test details.

### GET /blink-fatigue/stats
Get aggregated statistics and trends.

**Response:**
```json
{
  "total_tests": 10,
  "average_confidence": 0.87,
  "drowsy_percentage": 30.0,
  "alert_percentage": 20.0,
  "fatigue_distribution": {
    "Alert": 7,
    "High Fatigue": 2,
    "Critical - High Fatigue": 1
  },
  "recent_trend": "Alert and well-rested",
  "last_test_date": "2024-01-15T10:30:00"
}
```

## Setup Instructions

### 1. Install Backend Dependencies

```bash
cd netracare_backend
pip install -r requirements.txt
```

New dependencies added:
- `tensorflow` - For CNN model
- `Pillow` - For image processing

### 2. Train the Model

```bash
cd netracare_backend
python train_blink_model.py
```

This will:
- Load images from `D:\3rd_Year\Dataset\train_data`
- Train CNN model with data augmentation
- Save trained model to `models/blink_fatigue_model.keras`
- Display training progress and accuracy

Expected training time: 10-30 minutes (depends on GPU/CPU)

### 3. Initialize Database

The new `BlinkFatigueTest` table will be created automatically when you run the Flask app:

```bash
python app.py
```

Or if using Flask CLI:
```bash
flask --app app.py db init
flask --app app.py db migrate -m "Add blink fatigue tests"
flask --app app.py db upgrade
```

### 4. Frontend Integration

The Flutter service is ready to use. Import in your pages:

```dart
import '../services/blink_fatigue_service.dart';
import '../pages/blink_fatigue_cnn_test_page.dart';
```

Navigate to the test page:
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const BlinkFatigueCNNTestPage()),
);
```

## CNN Model Architecture

Based on the Kaggle implementation with enhancements:

```
Input: 145x145x3 RGB image
↓
Conv2D(32, 3x3) + ReLU + MaxPool(2x2) + BatchNorm
↓
Conv2D(64, 3x3) + ReLU + MaxPool(2x2) + BatchNorm
↓
Conv2D(128, 3x3) + ReLU + MaxPool(2x2) + BatchNorm
↓
Conv2D(256, 3x3) + ReLU + MaxPool(2x2) + BatchNorm
↓
Flatten
↓
Dropout(0.5) + Dense(512) + ReLU
↓
Dropout(0.3) + Dense(256) + ReLU
↓
Dropout(0.2)
↓
Dense(2, softmax) → [drowsy_prob, notdrowsy_prob]
```

**Training Features:**
- Data augmentation (rotation, shift, flip, zoom, brightness)
- Early stopping with patience=10
- Learning rate reduction on plateau
- Validation split: 20%
- Batch size: 32
- Optimizer: Adam (lr=0.001)

## Fatigue Level Classification

| Drowsy Probability | Fatigue Level | Alert Triggered |
|-------------------|---------------|-----------------|
| ≥ 0.8 | Critical - High Fatigue | Yes |
| 0.6 - 0.8 | High Fatigue | Yes |
| 0.4 - 0.6 | Moderate Fatigue | No |
| 0.2 - 0.4 | Low Fatigue | No |
| < 0.2 | Alert | No |

## Usage Examples

### Backend - Making Predictions

```python
from blink_fatigue_model import get_model_singleton

# Get model instance
model = get_model_singleton()

# Predict from image file
result = model.predict('path/to/eye_image.jpg')

# Predict from bytes
with open('eye_image.jpg', 'rb') as f:
    image_bytes = f.read()
result = model.predict(image_bytes)

print(result)
# {
#   'prediction': 'drowsy',
#   'confidence': 0.95,
#   'probabilities': {'drowsy': 0.95, 'notdrowsy': 0.05},
#   'fatigue_level': 'Critical - High Fatigue',
#   'alert': True,
#   'timestamp': '...'
# }
```

### Frontend - Using the Service

```dart
import '../services/blink_fatigue_service.dart';
import 'dart:io';

// Predict only (no database save)
final result = await BlinkFatigueService.predictDrowsiness(imageFile);

// Submit test (saves to database)
final result = await BlinkFatigueService.submitTest(
  imageFile: imageFile,
  testDuration: 30.0,
);

// Get history
final history = await BlinkFatigueService.getHistory();
print('Total tests: ${history['total_tests']}');
print('Drowsy count: ${history['drowsy_count']}');

// Get statistics
final stats = await BlinkFatigueService.getStatistics();
print('Recent trend: ${stats['recent_trend']}');
```

## Testing the Implementation

### 1. Test Backend API

Start the Flask server:
```bash
cd netracare_backend
python app.py
```

Visit API documentation: `http://localhost:5000/docs`

Test prediction endpoint with curl:
```bash
curl -X POST \
  http://localhost:5000/blink-fatigue/predict \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "image=@test_eye_image.jpg"
```

### 2. Test Frontend

1. Run Flutter app
2. Login with user credentials
3. Navigate to "Blink & Fatigue Detection"
4. Allow camera permissions
5. Capture image
6. View CNN prediction results

## Model Performance

After training, check model performance:

```python
from blink_fatigue_model import BlinkFatigueModel

model = BlinkFatigueModel('models/blink_fatigue_model.keras')

# Evaluate on test set (if you have separate test data)
metrics = model.evaluate_model('path/to/test_data')
print(f"Test Accuracy: {metrics['test_accuracy']:.4f}")
```

## Troubleshooting

### Model Not Found Error
- Ensure `train_blink_model.py` has been run successfully
- Check that `models/blink_fatigue_model.keras` exists
- Verify path in `get_model_singleton()`

### Low Accuracy
- Train for more epochs (increase from 50)
- Adjust learning rate
- Add more data augmentation
- Check dataset quality

### Prediction Errors
- Verify image format (JPG, JPEG, PNG)
- Check image is readable
- Ensure TensorFlow is installed: `pip install tensorflow`

### Frontend Camera Issues
- Check camera permissions in AndroidManifest.xml / Info.plist
- Ensure device has camera
- Test on physical device (not emulator)

## Future Enhancements

1. **Real-time Video Stream Processing**
   - Process video frames instead of single images
   - Continuous monitoring mode

2. **Model Improvements**
   - Collect more training data
   - Implement transfer learning (VGG16, ResNet)
   - Add attention mechanisms

3. **Advanced Features**
   - Fatigue pattern tracking over time
   - Predictive alerts before severe fatigue
   - Integration with eye tracking for combined analysis
   - Export reports as PDF

4. **Optimization**
   - Model quantization for mobile deployment
   - TensorFlow Lite conversion
   - On-device inference (no backend needed)

## File Structure

```
netracare_backend/
├── blink_fatigue_model.py      # CNN model class
├── train_blink_model.py        # Training script
├── blink_fatigue_routes.py     # API endpoints
├── db_model.py                 # Database models (updated)
├── app.py                      # Flask app (updated)
├── requirements.txt            # Dependencies (updated)
└── models/
    └── blink_fatigue_model.keras  # Trained model (after training)

netracare/
├── lib/
│   ├── services/
│   │   └── blink_fatigue_service.dart   # API service
│   └── pages/
│       ├── blink_fatigue_cnn_test_page.dart  # CNN test page
│       ├── blink_fatigue_test_page.dart      # Original simulation
│       └── blink_fatigue_page.dart           # Landing page
```

## Code Quality Features

✅ **Modular Design**: Separate files for model, routes, service, and UI
✅ **Type Safety**: Full type hints in Python, strong typing in Dart
✅ **Error Handling**: Comprehensive try-catch blocks and validation
✅ **Documentation**: Docstrings and comments throughout
✅ **Professional Patterns**: Singleton for model, namespace routing, service layer
✅ **Security**: JWT authentication, token validation
✅ **Scalability**: Easy to extend with new features
✅ **Maintainability**: Clear separation of concerns

## References

- Kaggle Model: https://www.kaggle.com/code/manasa01234/cnn-model-training-group
- Dataset: D:\3rd_Year\Dataset\train_data (drowsy/notdrowsy folders)
