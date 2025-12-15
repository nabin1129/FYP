import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';

class ApiService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  // Get stored token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Save token
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Delete token (logout)
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Get headers with authentication
  static Future<Map<String, String>> getHeaders({bool includeAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // Login
  static Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
        headers: await getHeaders(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);
        await saveToken(authResponse.token);
        return authResponse;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Signup
  static Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
    int? age,
    String? sex,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signupEndpoint}'),
        headers: await getHeaders(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          if (age != null) 'age': age,
          if (sex != null) 'sex': sex,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final authResponse = AuthResponse.fromJson(data);
        await saveToken(authResponse.token);
        return authResponse;
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['message'] ?? 'Signup failed');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Get user profile
  static Future<User> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}'),
        headers: await getHeaders(includeAuth: true),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(data);
      } else if (response.statusCode == 401) {
        await deleteToken();
        throw Exception('Unauthorized. Please login again.');
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Failed to fetch profile');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }

  // Upload test file
  static Future<Map<String, dynamic>> uploadTestFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.testUploadEndpoint}'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        await deleteToken();
        throw Exception('Unauthorized. Please login again.');
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>;
        throw Exception(error['error'] ?? 'Upload failed');
      }
    } catch (e) {
      throw Exception('Network error: ${e.toString()}');
    }
  }
}
