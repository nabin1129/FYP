import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
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
