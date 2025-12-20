# Frontend-Backend Integration Guide

## Overview
The Flutter frontend is now fully integrated with the Flask backend API. This guide explains how to use and configure the integration.

## Configuration

### Backend URL Configuration
Edit `lib/config/api_config.dart` to set your backend URL:

```dart
static const String baseUrl = 'http://localhost:5000';
```

**Important:** For different platforms, use:
- **Android Emulator**: `http://10.0.2.2:5000`
- **iOS Simulator**: `http://localhost:5000`
- **Web**: `http://localhost:5000`
- **Physical Device**: Use your computer's IP address (e.g., `http://192.168.1.100:5000`)

### Backend CORS
The backend is configured to accept requests from all origins. In production, update `app.py` to restrict origins:

```python
CORS(app, resources={
    r"/*": {
        "origins": ["https://yourdomain.com"],  # Production domain
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"],
    }
})
```

## Features Implemented

### 1. Authentication
- **Login**: Users can log in with email and password
- **Signup**: Users can create new accounts
- **Token Storage**: JWT tokens are securely stored using `flutter_secure_storage`
- **Auto-login**: App checks for existing tokens on startup

### 2. User Profile
- **Profile Display**: Shows user information from the backend
- **Auto-load**: Profile loads automatically when the page opens
- **Error Handling**: Shows appropriate error messages if profile fetch fails

### 3. API Service
The `ApiService` class (`lib/services/api_service.dart`) provides:
- `login(email, password)` - User login
- `signup(name, email, password, age?, sex?)` - User registration
- `getProfile()` - Fetch user profile
- `uploadTestFile(fileBytes, fileName)` - Upload test files
- `getToken()` - Get stored authentication token
- `saveToken(token)` - Save authentication token
- `deleteToken()` - Clear authentication token (logout)

## Running the Application

### Backend
```bash
cd netracare_backend
.\venv\Scripts\Activate.ps1  # Windows PowerShell
python app.py
```

The backend will run on `http://localhost:5000`

### Frontend
```bash
cd netracare
flutter pub get
flutter run
```

## API Endpoints Used

- `POST /auth/login` - User login
- `POST /auth/signup` - User registration
- `GET /user/profile` - Get user profile (requires authentication)
- `POST /tests/upload` - Upload test file (requires authentication)

## Error Handling

The integration includes comprehensive error handling:
- Network errors are caught and displayed to users
- Authentication errors automatically log users out
- Form validation prevents empty submissions
- Loading states prevent multiple simultaneous requests

## Security

- JWT tokens are stored securely using `flutter_secure_storage`
- Tokens are automatically included in authenticated requests
- Tokens are cleared on logout
- Backend validates all tokens before processing requests

## Testing

1. Start the backend server
2. Run the Flutter app
3. Test signup with a new account
4. Test login with existing credentials
5. Verify profile loads correctly
6. Test logout functionality

## Troubleshooting

### Connection Errors
- Verify backend is running
- Check the base URL in `api_config.dart`
- For physical devices, ensure device and computer are on the same network
- Check firewall settings

### Authentication Errors
- Verify token is being saved correctly
- Check backend logs for authentication issues
- Ensure CORS is properly configured

### Profile Not Loading
- Check if user is authenticated
- Verify backend `/user/profile` endpoint is working
- Check network tab for API responses
