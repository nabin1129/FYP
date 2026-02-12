import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

/// Service for real-time blink detection using EAR algorithm
class BlinkDetectionService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  static Future<String?> _getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Analyze single camera frame for blink detection
  /// Returns EAR (Eye Aspect Ratio) and blink status
  static Future<Map<String, dynamic>> analyzeFrame(XFile imageFile) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      // Read image bytes
      final bytes = await imageFile.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/blink-detection/analyze-frame'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'image': base64Image}),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Frame analysis timeout'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'ear': (data['ear'] ?? 0.0).toDouble(),
          'is_blink': data['is_blink'] ?? false,
          'left_ear': (data['left_ear'] ?? 0.0).toDouble(),
          'right_ear': (data['right_ear'] ?? 0.0).toDouble(),
          'message': data['message'] ?? '',
        };
      } else {
        throw Exception('Frame analysis failed: ${response.statusCode}');
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'ear': 0.0,
        'is_blink': false,
      };
    }
  }

  /// Submit complete blink & fatigue test results
  static Future<Map<String, dynamic>> submitTest({
    required int blinkCount,
    required int durationSeconds,
    required double drowsinessProbability,
    required double confidenceScore,
    String? fatigueLevel,
  }) async {
    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please login again.');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/blink-detection/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'blink_count': blinkCount,
          'duration_seconds': durationSeconds,
          'drowsiness_probability': drowsinessProbability,
          'confidence_score': confidenceScore,
          'fatigue_level': fatigueLevel,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Test submission timeout'),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        throw Exception('Session expired. Please login again.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Test submission failed');
      }
    } catch (e) {
      throw Exception('Failed to submit test: ${e.toString()}');
    }
  }
}
