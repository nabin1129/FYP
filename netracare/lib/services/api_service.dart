import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  // =========================
  // TOKEN HANDLING
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
  // PROFILE
  // =========================
  static Future<User> getProfile() async {
    final token = await getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Unauthorized. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    // 🔒 CRITICAL SAFETY CHECK
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) {
      await deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Unauthorized. Please login again.');
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

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await deleteToken();
      throw Exception('Unauthorized');
    }

    throw Exception('Upload failed');
  }

  // =========================
  // ERROR HANDLER (INTERNAL)
  // =========================
  static Never _throwReadableError(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';

    if (contentType.contains('application/json')) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? error['message'] ?? 'Request failed');
    }

    throw Exception('Server error. Please try again.');
  }
}
