# Quick Start - Blink & Fatigue Detection

## Step 1: Install Dependencies

Open PowerShell in `netracare_backend` directory:

```powershell
cd D:\3rd_Year\FYP\netracare_backend
pip install -r requirements.txt
```

## Step 2: Train the CNN Model

```powershell
python train_blink_model.py
```

**Expected output:**
```
============================================================
Blink Fatigue Detection - Model Training
============================================================

📊 Dataset Statistics:
  - Drowsy images: 3000+
  - Not drowsy images: 3000+
  - Total images: 6000+

🔧 Initializing CNN model...
🚀 Starting training...
```

**Training time:** 15-30 minutes (CPU) or 5-10 minutes (GPU)

**Success indicators:**
- Validation accuracy > 85%
- Model saved to `models/blink_fatigue_model.keras`

## Step 3: Initialize Database

Run Flask app to create new database tables:

```powershell
python app.py
```

The app will automatically create the `blink_fatigue_tests` table.

## Step 4: Test Backend API

1. Keep Flask server running
2. Open browser: http://localhost:5000/docs
3. Find "blink-fatigue" namespace
4. Test endpoints:
   - Login first via `/auth/login` to get JWT token
   - Click "Authorize" button and enter: `Bearer YOUR_TOKEN`
   - Try `/blink-fatigue/predict` endpoint

## Step 5: Test Flutter App

```powershell
cd D:\3rd_Year\FYP\netracare
flutter run
```

**Test flow:**
1. Login to app
2. Navigate to "Blink & Fatigue Detection" from dashboard
3. Click "Enable Camera & Start Test"
4. Allow camera permissions
5. Click "Capture & Analyze"
6. View CNN prediction results
7. Check "Results" page for history

## Verification Checklist

- [ ] TensorFlow installed successfully
- [ ] Model training completed without errors
- [ ] Model file exists at `models/blink_fatigue_model.keras`
- [ ] Flask server starts without errors
- [ ] API docs accessible at http://localhost:5000/docs
- [ ] `/blink-fatigue` namespace visible in Swagger UI
- [ ] Flutter app compiles successfully
- [ ] Camera permissions granted
- [ ] Image capture works
- [ ] CNN prediction returns results
- [ ] Results saved to database

## Common Issues

### Issue: "ModuleNotFoundError: No module named 'tensorflow'"
**Solution:** 
```powershell
pip install tensorflow
```

### Issue: "Model file not found"
**Solution:** Run training script first:
```powershell
python train_blink_model.py
```

### Issue: "Dataset not found"
**Solution:** Verify dataset path in `train_blink_model.py` line 17:
```python
DATASET_PATH = r"D:\3rd_Year\Dataset\train_data"
```

### Issue: Camera not working in Flutter
**Solution:** Test on physical device, not emulator. Check permissions in:
- Android: `android/app/src/main/AndroidManifest.xml`
- iOS: `ios/Runner/Info.plist`

## API Testing with Postman

1. **Login:**
   ```
   POST http://localhost:5000/auth/login
   Body: {"email": "user@example.com", "password": "password"}
   ```

2. **Copy token from response**

3. **Test Prediction:**
   ```
   POST http://localhost:5000/blink-fatigue/predict
   Headers: Authorization: Bearer YOUR_TOKEN
   Body (form-data): image: [select eye image file]
   ```

## Expected Results

**Drowsy Detection:**
```json
{
  "prediction": "drowsy",
  "confidence": 0.92,
  "probabilities": {
    "drowsy": 0.92,
    "notdrowsy": 0.08
  },
  "fatigue_level": "Critical - High Fatigue",
  "alert": true
}
```

**Alert Detection:**
```json
{
  "prediction": "notdrowsy",
  "confidence": 0.88,
  "probabilities": {
    "drowsy": 0.12,
    "notdrowsy": 0.88
  },
  "fatigue_level": "Alert",
  "alert": false
}
```

## Next Steps

After successful testing:
1. Fine-tune model with more epochs if accuracy is low
2. Collect user feedback on detection accuracy
3. Implement continuous monitoring mode
4. Add results to PDF reports
5. Create fatigue trend graphs

## Support

For issues or questions, check:
- Backend implementation: `BLINK_FATIGUE_IMPLEMENTATION.md`
- Error logs in terminal output
- Flask server logs
- Flutter debug console
