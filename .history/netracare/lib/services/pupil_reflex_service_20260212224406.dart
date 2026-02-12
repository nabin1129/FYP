import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';

/// Service for pupil reflex test API calls
class PupilReflexService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  // =========================
  // HELPER METHODS
  // =========================

  static Future<String?> _getToken() async {
    return await _storage.read(key: _tokenKey);
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
      if (response.body.isNotEmpty) {
        message = response.body;
      }
    }

    throw Exception(message);
  }

  // =========================
  // SUBMIT TEST
  // =========================

  /// Submit pupil reflex test results to backend
  ///
  /// Args:
  ///   reactionTime: Pupil reaction time in seconds
  ///   constrictionAmplitude: Normal, Weak, or Strong
  ///   symmetry: Equal or Unequal
  ///   testDuration: Total test duration in seconds
  ///   imageFile: Optional eye image file
  ///   leftPupilBefore: Optional left pupil size before flash
  ///   leftPupilAfter: Optional left pupil size after flash
  ///   rightPupilBefore: Optional right pupil size before flash
  ///   rightPupilAfter: Optional right pupil size after flash
  ///
  /// Returns:
  ///   Map containing saved test data with ID
  static Future<Map<String, dynamic>> submitTest({
    required double reactionTime,
    required String constrictionAmplitude,
    required String symmetry,
    double? testDuration,
    File? imageFile,
    double? leftPupilBefore,
    double? leftPupilAfter,
    double? rightPupilBefore,
    double? rightPupilAfter,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    // Create multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/pupil-reflex/test/submit'),
    );

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add required fields
    request.fields['reaction_time'] = reactionTime.toString();
    request.fields['constriction_amplitude'] = constrictionAmplitude;
    request.fields['symmetry'] = symmetry;

    // Add optional fields
    if (testDuration != null) {
      request.fields['test_duration'] = testDuration.toString();
    }
    if (leftPupilBefore != null) {
      request.fields['left_pupil_size_before'] = leftPupilBefore.toString();
    }
    if (leftPupilAfter != null) {
      request.fields['left_pupil_size_after'] = leftPupilAfter.toString();
    }
    if (rightPupilBefore != null) {
      request.fields['right_pupil_size_before'] = rightPupilBefore.toString();
    }
    if (rightPupilAfter != null) {
      request.fields['right_pupil_size_after'] = rightPupilAfter.toString();
    }

    // Add image file if provided
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    // Send request
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      _throwReadableError(response);
    }
  }

  // =========================
  // GET TESTS
  // =========================

  /// Get all pupil reflex tests for current user
  ///
  /// Returns:
  ///   Map containing:
  ///   - tests: List of test records
  ///   - total_tests: Total count
  ///   - avg_reaction_time: Average reaction time
  static Future<Map<String, dynamic>> getTests() async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pupil-reflex/tests'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      _throwReadableError(response);
    }
  }

  // =========================
  // GET SINGLE TEST
  // =========================

  /// Get specific pupil reflex test by ID
  ///
  /// Args:
  ///   testId: ID of the test to retrieve
  ///
  /// Returns:
  ///   Map containing test details
  static Future<Map<String, dynamic>> getTest(int testId) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/pupil-reflex/tests/$testId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Test not found');
    } else {
      _throwReadableError(response);
    }
  }

  // =========================
  // DELETE TEST
  // =========================

  /// Delete specific pupil reflex test
  ///
  /// Args:
  ///   testId: ID of the test to delete
  static Future<void> deleteTest(int testId) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/pupil-reflex/tests/$testId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else if (response.statusCode == 404) {
      throw Exception('Test not found');
    } else {
      _throwReadableError(response);
    }
  }
}
