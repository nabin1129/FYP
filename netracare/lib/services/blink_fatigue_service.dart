import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

/// Service for blink and eye fatigue detection API calls
class BlinkFatigueService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  // =========================
  // HELPER METHODS
  // =========================

  static Future<String?> _getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> _deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Never _throwReadableError(http.Response response) {
    String message = 'Request failed with status ${response.statusCode}';

    try {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('message')) {
        message = data['message'];
      } else if (data is Map && data.containsKey('error')) {
        message = data['error'];
      }
    } catch (_) {
      // If JSON parsing fails, use the raw body
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }

    throw Exception(message);
  }

  // =========================
  // PREDICT DROWSINESS
  // =========================

  /// Predict drowsiness from eye image without saving to database
  ///
  /// Args:
  ///   imageFile: File object containing the eye image
  ///
  /// Returns:
  ///   Map containing prediction results
  static Future<Map<String, dynamic>> predictDrowsiness(File imageFile) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    // Create multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/blink-fatigue/predict'),
    );

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add image file
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await _deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // SUBMIT TEST
  // =========================

  /// Submit blink fatigue test and save results to database
  ///
  /// Args:
  ///   imageFile: File object containing the eye image
  ///   testDuration: Optional test duration in seconds
  ///
  /// Returns:
  ///   Map containing saved test result
  static Future<Map<String, dynamic>> submitTest({
    required File imageFile,
    double? testDuration,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    // Create multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/blink-fatigue/test/submit'),
    );

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add image file
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    // Add optional test duration
    if (testDuration != null) {
      request.fields['test_duration'] = testDuration.toString();
    }

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await _deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // GET HISTORY
  // =========================

  /// Get user's blink fatigue test history
  ///
  /// Returns:
  ///   Map containing test history and statistics
  static Future<Map<String, dynamic>> getHistory() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/blink-fatigue/history'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await _deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // GET TEST DETAIL
  // =========================

  /// Get specific test result by ID
  ///
  /// Args:
  ///   testId: ID of the test to retrieve
  ///
  /// Returns:
  ///   Map containing test details
  static Future<Map<String, dynamic>> getTestDetail(int testId) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/blink-fatigue/history/$testId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await _deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }

  // =========================
  // GET STATISTICS
  // =========================

  /// Get aggregated fatigue statistics
  ///
  /// Returns:
  ///   Map containing statistics and trends
  static Future<Map<String, dynamic>> getStatistics() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/blink-fatigue/stats'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await _deleteToken();
      throw Exception('Session expired. Please login again.');
    }

    _throwReadableError(response);
  }
}
