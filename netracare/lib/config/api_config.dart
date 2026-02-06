class ApiConfig {
  // Change this to your backend URL
  // For local development (Android Emulator): use http://10.0.2.2:5000
  // For local development (iOS Simulator): use http://localhost:5000
  // For local development (Web): use http://localhost:5000
  // For physical device: use your computer's IP address, e.g., http://192.168.1.100:5000
  //
  // NOTE: Use 10.0.2.2 on Android emulator to reach host machine
  static const String baseUrl = 'http://10.0.2.2:5000';

  // API endpoints
  static const String loginEndpoint = '/auth/login';
  static const String signupEndpoint = '/auth/signup';
  static const String profileEndpoint = '/user/profile';
  static const String testUploadEndpoint = '/tests/upload';
  static const String visualAcuityEndpoint = '/visual-acuity/tests';
  static const String visualAcuityTestsEndpoint = '/visual-acuity/tests';
  static const String colourVisionPlatesEndpoint = '/colour-vision/plates';
  static const String colourVisionTestsEndpoint = '/colour-vision/tests';
  static const String eyeTrackingTestsEndpoint = '/eye-tracking/tests';
}
