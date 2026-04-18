import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_service.dart';

/// Service for pupil reflex test API calls
class PupilReflexService {
  // =========================
  // HELPER METHODS
  // =========================

  static const Duration _requestTimeout = Duration(seconds: 15);

  static Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return http
        .get(uri, headers: headers)
        .timeout(_requestTimeout, onTimeout: _onTimeout);
  }

  static Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http
        .post(uri, headers: headers, body: body)
        .timeout(_requestTimeout, onTimeout: _onTimeout);
  }

  static Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return http
        .delete(uri, headers: headers)
        .timeout(_requestTimeout, onTimeout: _onTimeout);
  }

  static Future<http.Response> _onTimeout() {
    throw Exception(
      'Request timed out. Please check your internet connection and try again.',
    );
  }

  static Future<String?> _getToken() async {
    return await ApiService.getToken();
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
  // CLINICAL OUTPUT HELPERS
  // =========================

  /// Extract standardized clinical output from either top-level or nested payloads.
  static Map<String, dynamic>? extractClinicalOutput(
    Map<String, dynamic> payload,
  ) {
    final top = payload['clinical_output'];
    if (top is Map<String, dynamic>) {
      return top;
    }

    final results = payload['results'];
    if (results is Map<String, dynamic>) {
      final nested = results['clinical_output'];
      if (nested is Map<String, dynamic>) {
        return nested;
      }
    }

    return null;
  }

  /// Extract clinical summary text from payload when available.
  static String? extractClinicalSummary(Map<String, dynamic> payload) {
    final summary = payload['clinical_summary'];
    if (summary is String && summary.trim().isNotEmpty) {
      return summary;
    }

    final results = payload['results'];
    if (results is Map<String, dynamic>) {
      final nested = results['clinical_summary'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested;
      }
    }

    final clinical = extractClinicalOutput(payload);
    final interpretation = clinical?['interpretation'];
    if (interpretation is Map<String, dynamic>) {
      final text = interpretation['summary'];
      if (text is String && text.trim().isNotEmpty) {
        return text;
      }
    }

    return null;
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
    bool? nystagmusDetected,
    String? nystagmusType,
    String? nystagmusSeverity,
    double? nystagmusConfidence,
    String? diagnosis,
    String? recommendations,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    // Create multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pupilReflexSubmitEndpoint}'),
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

    // Add nystagmus detection fields
    if (nystagmusDetected != null) {
      request.fields['nystagmus_detected'] = nystagmusDetected.toString();
    }
    if (nystagmusType != null && nystagmusType.isNotEmpty) {
      request.fields['nystagmus_type'] = nystagmusType;
    }
    if (nystagmusSeverity != null && nystagmusSeverity.isNotEmpty) {
      request.fields['nystagmus_severity'] = nystagmusSeverity;
    }
    if (nystagmusConfidence != null) {
      request.fields['nystagmus_confidence'] = nystagmusConfidence.toString();
    }
    if (diagnosis != null && diagnosis.isNotEmpty) {
      request.fields['diagnosis'] = diagnosis;
    }
    if (recommendations != null && recommendations.isNotEmpty) {
      request.fields['recommendations'] = recommendations;
    }

    // Add image file if provided
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    // Send request
    final streamedResponse = await request.send().timeout(
      _requestTimeout,
      onTimeout: () => throw Exception(
        'Request timed out. Please check your internet connection and try again.',
      ),
    );
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

    final response = await _get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.pupilReflexTestsEndpoint}'),
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

    final response = await _get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pupilReflexTestDetailEndpoint(testId)}',
      ),
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

    final response = await _delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pupilReflexTestDetailEndpoint(testId)}',
      ),
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

  // =========================
  // NYSTAGMUS DETECTION (NEW)
  // =========================

  /// Start a new nystagmus detection test session
  ///
  /// Args:
  ///   testType: Type of test - 'pupil_reflex' or 'nystagmus'
  ///   eyeTested: Which eye - 'left', 'right', or 'both'
  ///
  /// Returns:
  ///   Map containing test_id and instructions
  static Future<Map<String, dynamic>> startNystagmusTest({
    String testType = 'nystagmus',
    String eyeTested = 'both',
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await _post(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pupilReflexStartTestEndpoint}',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'test_type': testType, 'eye_tested': eyeTested}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      _throwReadableError(response);
    }
  }

  /// Analyze video for nystagmus detection
  ///
  /// Args:
  ///   testId: Test session ID from startNystagmusTest
  ///   videoFile: Recorded eye tracking video file
  ///   flashTimestamps: Optional list of flash trigger times in seconds
  ///
  /// Returns:
  ///   Map containing analysis results with nystagmus detection
  static Future<Map<String, dynamic>> analyzeVideoForNystagmus({
    required String testId,
    required File videoFile,
    List<double>? flashTimestamps,
  }) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    // Create multipart request
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pupilReflexAnalyzeVideoEndpoint}',
      ),
    );

    // Add authorization header
    request.headers['Authorization'] = 'Bearer $token';

    // Add test_id
    request.fields['test_id'] = testId;

    // Add flash timestamps if provided
    if (flashTimestamps != null && flashTimestamps.isNotEmpty) {
      request.fields['flash_timestamps'] = jsonEncode(flashTimestamps);
    }

    // Add video file
    request.files.add(
      await http.MultipartFile.fromPath('video', videoFile.path),
    );

    // Send request
    final streamedResponse = await request.send().timeout(
      _requestTimeout,
      onTimeout: () => throw Exception(
        'Request timed out. Please check your internet connection and try again.',
      ),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please login again.');
    } else {
      _throwReadableError(response);
    }
  }

  /// Get nystagmus test results by test ID
  ///
  /// Args:
  ///   testId: Test ID from analyze video
  ///
  /// Returns:
  ///   Map containing complete test results including nystagmus data
  static Future<Map<String, dynamic>> getNystagmusResults(int testId) async {
    final token = await _getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session expired. Please login again.');
    }

    final response = await _get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.pupilReflexResultsEndpoint(testId)}',
      ),
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
}
