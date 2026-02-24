import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/distance_calibration_model.dart';

class ApiService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _tokenKey = 'auth_token';

  // =========================
  // TOKEN
  // =========================
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // =========================
  // LOGIN
  // =========================
  static Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final auth = AuthResponse.fromJson(data);
      await saveToken(auth.token);
      return auth;
    }

    _throwReadableError(response);
  }

  // =========================
  // SIGNUP
  // =========================
  static Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
    int? age,
    String? sex,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signupEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (age != null) 'age': age,
        if (sex != null) 'sex': sex,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final auth = AuthResponse.fromJson(data);
      await saveToken(auth.token);
      return auth;
    }

    _throwReadableError(response);
  }

  // =========================
  // PROFILE (FIXED)
  // =========================
  static Future<User> getProfile() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json', // 🔥 IMPORTANT
      },
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(response.body));
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // UPDATE PROFILE
  // =========================
  static Future<User> updateProfile({
    String? name,
    String? email,
    int? age,
    String? sex,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (age != null) body['age'] = age;
    if (sex != null) body['sex'] = sex;

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data['user'] as Map<String, dynamic>);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // FILE UPLOAD
  // =========================
  static Future<Map<String, dynamic>> uploadTestFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Unauthorized');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.testUploadEndpoint}'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
    );

    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Unauthorized');
    }

    throw Exception('Upload failed');
  }

  // =========================
  // VISUAL ACUITY TEST (Backend DA Model Integration)
  // =========================
  static Future<VisualAcuityResult> submitVisualAcuityTest({
    required int correct,
    required int total,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.visualAcuityEndpoint}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'correct_answers': correct, 'total_questions': total}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return VisualAcuityResult.fromJson(data);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // ===========================
  // COLOR VISION TEST
  // ===========================
  static String getBaseUrl() {
    return ApiConfig.baseUrl;
  }

  static Future<List<Map<String, dynamic>>> getColorVisionPlates({
    int count = 5,
  }) async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.colourVisionPlatesEndpoint}?count=$count',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final plates = data['plates'] as List;
      return plates.map((p) => p as Map<String, dynamic>).toList();
    }

    _throwReadableError(response);
  }

  static Future<Map<String, dynamic>> submitColorVisionTest({
    required List<int> plateIds,
    required List<String> plateImages,
    required List<String> userAnswers,
    required int score,
    double? testDuration,
  }) async {
    final token = await getToken();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.colourVisionTestsEndpoint}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'plate_ids': plateIds,
        'plate_images': plateImages,
        'user_answers': userAnswers,
        'test_duration': testDuration,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    _throwReadableError(response);
  }

  static Future<List<Map<String, dynamic>>> getColorVisionTests() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.colourVisionTestsEndpoint}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((test) => test as Map<String, dynamic>).toList();
    }

    _throwReadableError(response);
  }

  static Future<Map<String, dynamic>> getVisualAcuityTests() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.visualAcuityTestsEndpoint}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwReadableError(response);
  }

  static Future<Map<String, dynamic>> getEyeTrackingTests() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.eyeTrackingTestsEndpoint}'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    _throwReadableError(response);
  }

  static Future<Map<String, dynamic>> submitEyeTrackingTest({
    required double gazeAccuracy,
    required double testDuration,
    double? fixationStability,
    double? saccadeConsistency,
    double? overallScore,
    String? classification,
    String? testName,
    int? screenWidth,
    int? screenHeight,
    List<Map<String, dynamic>>? rawData,
    Map<String, dynamic>? pupilMetrics,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.eyeTrackingTestsEndpoint}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'gaze_accuracy': gazeAccuracy,
        'test_duration': testDuration,
        if (fixationStability != null) 'fixation_stability': fixationStability,
        if (saccadeConsistency != null)
          'saccade_consistency': saccadeConsistency,
        if (overallScore != null) 'overall_score': overallScore,
        if (classification != null) 'classification': classification,
        if (testName != null) 'test_name': testName,
        if (screenWidth != null) 'screen_width': screenWidth,
        if (screenHeight != null) 'screen_height': screenHeight,
        if (rawData != null) 'raw_data': rawData,
        if (pupilMetrics != null) 'pupil_metrics': pupilMetrics,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  static Future<Map<String, dynamic>> getAllTestResults() async {
    // Fetch all test types in parallel
    final results = await Future.wait([
      getVisualAcuityTests().catchError((e) => {'tests': [], 'total': 0}),
      getColorVisionTests()
          .then((tests) => {'tests': tests, 'total': tests.length})
          .catchError((e) => {'tests': [], 'total': 0}),
      getEyeTrackingTests().catchError((e) => {'tests': [], 'total': 0}),
    ]);

    return {
      'visual_acuity': results[0],
      'colour_vision': results[1],
      'eye_tracking': results[2],
    };
  }

  // DISTANCE CALIBRATION
  // =========================

  /// Save distance calibration data to backend
  static Future<Map<String, dynamic>> saveDistanceCalibration(
    DistanceCalibrationData calibration,
  ) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/distance/calibrate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(calibration.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Get user's active calibration data
  static Future<DistanceCalibrationData?> getActiveCalibration() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/distance/calibration/active'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['calibration'] != null) {
        return DistanceCalibrationData.fromJson(data['calibration']);
      }
      return null;
    }

    if (response.statusCode == 404) {
      return null; // No calibration found
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Get all calibrations for current user
  static Future<List<DistanceCalibrationData>> getAllCalibrations() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/distance/calibrations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> calibrations = data['calibrations'];
      return calibrations
          .map((c) => DistanceCalibrationData.fromJson(c))
          .toList();
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Validate distance against server-side rules
  static Future<Map<String, dynamic>> validateDistance({
    required double currentDistance,
    required double referenceDistance,
  }) async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/distance/validate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'current_distance': currentDistance,
        'reference_distance': referenceDistance,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // HEALTH DATA ENDPOINTS
  // =========================

  /// Get user's medical records (for future implementation)
  static Future<Map<String, dynamic>> getMedicalRecords() async {
    final token = await getToken();
    if (token == null) throw Exception('No authentication token found');

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/user/medical-records'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Session expired');
    } else {
      throw Exception('Failed to load medical records');
    }
  }

  // =========================
  // DOCTOR CONSULTATION ENDPOINTS
  // =========================

  /// Get list of available doctors
  static Future<List<Map<String, dynamic>>> getDoctors() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/consultation/doctors'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['doctors'] ?? []);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Book a consultation with a doctor
  static Future<Map<String, dynamic>> bookConsultation({
    required String doctorId,
    required String consultationType, // 'video' or 'chat'
    required String date,
    required String time,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/consultation/book'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'doctor_id': doctorId,
        'type': consultationType,
        'date': date,
        'time': time,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Get consultation history
  static Future<List<Map<String, dynamic>>> getConsultationHistory() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/consultation/history'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['consultations'] ?? []);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Get chat messages with a doctor
  static Future<List<Map<String, dynamic>>> getChatMessages({
    required String doctorId,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/consultation/chat/$doctorId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['messages'] ?? []);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  /// Send a chat message to a doctor
  static Future<Map<String, dynamic>> sendChatMessage({
    required String doctorId,
    required String message,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/consultation/chat/$doctorId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'message': message}),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // =========================
  // ERROR HANDLER
  // =========================
  static Never _throwReadableError(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';

    if (contentType.contains('application/json')) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? error['message'] ?? 'Request failed');
    }

    throw Exception('Server error (${response.statusCode})');
  }
}
