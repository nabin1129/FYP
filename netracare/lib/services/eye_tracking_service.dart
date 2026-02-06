import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_service.dart';

class EyeTrackingResult {
  final double gazeAccuracy;
  final int dataPointsCollected;
  final int successfulTracking;
  final int testDuration;
  final String classification;
  final Map<String, dynamic> rawData;

  EyeTrackingResult({
    required this.gazeAccuracy,
    required this.dataPointsCollected,
    required this.successfulTracking,
    required this.testDuration,
    required this.classification,
    required this.rawData,
  });

  Map<String, dynamic> toJson() {
    return {
      'gaze_accuracy': gazeAccuracy,
      'data_points_collected': dataPointsCollected,
      'successful_tracking': successfulTracking,
      'test_duration': testDuration,
      'classification': classification,
      'raw_data': rawData,
    };
  }

  factory EyeTrackingResult.fromJson(Map<String, dynamic> json) {
    return EyeTrackingResult(
      gazeAccuracy: (json['gaze_accuracy'] as num).toDouble(),
      dataPointsCollected: json['data_points_collected'] as int,
      successfulTracking: json['successful_tracking'] as int,
      testDuration: json['test_duration'] as int,
      classification: json['classification'] as String,
      rawData: json['raw_data'] as Map<String, dynamic>? ?? {},
    );
  }
}

class EyeTrackingTestData {
  final List<Map<String, dynamic>> dataPoints;
  final String testName;
  final int screenWidth;
  final int screenHeight;
  final double testDuration;

  EyeTrackingTestData({
    required this.dataPoints,
    required this.testName,
    required this.screenWidth,
    required this.screenHeight,
    required this.testDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'test_name': testName,
      'data_points': dataPoints,
      'screen_width': screenWidth,
      'screen_height': screenHeight,
      'test_duration': testDuration,
    };
  }
}

class EyeTrackingService {
  static const String _endpoint = '/eye-tracking';

  /// Save eye tracking test results to backend
  static Future<Map<String, dynamic>> saveTestResults(
    EyeTrackingResult result,
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(result.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        throw Exception('Failed to save results: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error saving test results: $e');
    }
  }

  /// Upload raw eye tracking data for analysis
  static Future<Map<String, dynamic>> uploadTestData(
    EyeTrackingTestData testData,
  ) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/upload-data'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(testData.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        throw Exception('Failed to upload test data: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error uploading test data: $e');
    }
  }

  /// Retrieve historical eye tracking test results
  static Future<List<EyeTrackingResult>> getTestHistory({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}$_endpoint/history?limit=$limit&offset=$offset',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final results = (data['results'] as List)
            .map(
              (item) =>
                  EyeTrackingResult.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        return results;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        throw Exception('Failed to retrieve history: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error retrieving test history: $e');
    }
  }

  /// Get the latest eye tracking test result
  static Future<EyeTrackingResult> getLatestResult() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/latest'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return EyeTrackingResult.fromJson(data);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('No test results found');
      } else {
        throw Exception('Failed to retrieve result: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error retrieving latest result: $e');
    }
  }

  /// Get test statistics for the user
  static Future<Map<String, dynamic>> getTestStatistics() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/statistics'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        throw Exception(
          'Failed to retrieve statistics: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      throw Exception('Error retrieving statistics: $e');
    }
  }

  /// Delete a specific test result
  static Future<void> deleteTestResult(int resultId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/$resultId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        if (response.statusCode == 401) {
          throw Exception('Unauthorized - Please login again');
        } else {
          throw Exception('Failed to delete result: ${response.reasonPhrase}');
        }
      }
    } catch (e) {
      throw Exception('Error deleting test result: $e');
    }
  }

  /// Generate a PDF report of test results
  static Future<String> generateReport(int resultId) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/$resultId/generate-report'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['report_url'] as String;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        throw Exception('Failed to generate report: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error generating report: $e');
    }
  }

  /// Calibrate eye tracker
  static Future<Map<String, dynamic>> calibrateTracker() async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$_endpoint/calibrate'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else {
        throw Exception('Failed to calibrate: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw Exception('Error during calibration: $e');
    }
  }
}
