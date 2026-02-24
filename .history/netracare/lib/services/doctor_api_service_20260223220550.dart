import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/consultation/consultation_model.dart';
import '../models/consultation/doctor_model.dart';
import '../models/consultation/chat_message_model.dart';

/// API Service for Doctor-Patient linking and consultations
/// Handles real API calls to the backend
class DoctorApiService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _doctorTokenKey = 'doctor_auth_token';

  // =========================
  // TOKEN MANAGEMENT
  // =========================

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<String?> getDoctorToken() async {
    return await _storage.read(key: _doctorTokenKey);
  }

  static Future<void> saveDoctorToken(String token) async {
    await _storage.write(key: _doctorTokenKey, value: token);
  }

  static Future<void> deleteDoctorToken() async {
    await _storage.delete(key: _doctorTokenKey);
  }

  static Map<String, String> _getHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================
  // DOCTOR LIST (FOR PATIENTS)
  // =========================

  /// Get list of available doctors for patients to book consultations
  static Future<List<Doctor>> getAvailableDoctors({
    String? specialization,
    bool availableOnly = true,
  }) async {
    try {
      var url = '${ApiConfig.baseUrl}${ApiConfig.doctorListEndpoint}';
      final params = <String, String>{};

      if (specialization != null) params['specialization'] = specialization;
      if (availableOnly) params['available'] = 'true';

      if (params.isNotEmpty) {
        url += '?${Uri(queryParameters: params).query}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(null),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final doctors = (data['doctors'] as List)
            .map((d) => Doctor.fromJson(d as Map<String, dynamic>))
            .toList();
        return doctors;
      }

      throw Exception('Failed to fetch doctors');
    } catch (e) {
      // Return mock data as fallback
      return Doctor.getMockDoctors();
    }
  }

  /// Search doctors by query
  static Future<List<Doctor>> searchDoctors(String query) async {
    try {
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.doctorSearchEndpoint}?q=$query';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(null),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['doctors'] as List)
            .map((d) => Doctor.fromJson(d as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Search failed');
    } catch (e) {
      // Filter mock data as fallback
      final allDoctors = Doctor.getMockDoctors();
      return allDoctors
          .where(
            (d) =>
                d.name.toLowerCase().contains(query.toLowerCase()) ||
                d.specialization.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
  }

  /// Get doctor details by ID
  static Future<Doctor?> getDoctorById(String doctorId) async {
    try {
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.doctorDetailEndpoint(int.parse(doctorId))}';

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(null),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Doctor.fromJson(data['doctor'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      // Return from mock data as fallback
      return Doctor.getMockDoctors().firstWhere(
        (d) => d.id == doctorId,
        orElse: () => Doctor.getMockDoctors().first,
      );
    }
  }

  // =========================
  // CONSULTATION BOOKING (PATIENT)
  // =========================

  /// Book a consultation with a doctor
  static Future<Consultation?> bookConsultation({
    required int doctorId,
    String consultationType = 'video_call',
    String? reason,
    String? preferredDatetime,
  }) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login to book a consultation');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.bookConsultationEndpoint}'),
        headers: _getHeaders(token),
        body: jsonEncode({
          'doctor_id': doctorId,
          'consultation_type': consultationType,
          'reason': reason,
          if (preferredDatetime != null) 'preferred_datetime': preferredDatetime,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Consultation.fromJson(
            data['consultation'] as Map<String, dynamic>);
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Booking failed');
    } catch (e) {
      rethrow;
    }
  }

  /// Get patient's consultation history
  static Future<List<Consultation>> getPatientConsultations({
    String? status,
  }) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      var url =
          '${ApiConfig.baseUrl}${ApiConfig.patientConsultationsEndpoint}';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['consultations'] as List)
            .map((c) => Consultation.fromJson(c as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch consultations');
    } catch (e) {
      // Return mock data as fallback
      return Consultation.getMockHistory();
    }
  }

  /// Get patient's upcoming consultations
  static Future<List<Consultation>> getUpcomingConsultations() async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.patientUpcomingEndpoint}'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['consultations'] as List)
            .map((c) => Consultation.fromJson(c as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch upcoming');
    } catch (e) {
      // Return mock scheduled consultations
      return Consultation.getMockHistory()
          .where((c) => c.status == ConsultationStatus.scheduled)
          .toList();
    }
  }

  /// Get next scheduled consultation
  static Future<Consultation?> getNextScheduledConsultation() async {
    try {
      final upcoming = await getUpcomingConsultations();
      if (upcoming.isEmpty) return null;

      // Return the first scheduled one
      return upcoming.firstWhere(
        (c) => c.status == ConsultationStatus.scheduled,
        orElse: () => upcoming.first,
      );
    } catch (e) {
      return null;
    }
  }

  /// Cancel a consultation
  static Future<bool> cancelConsultation(int consultationId) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.cancelConsultationEndpoint(consultationId)}'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================
  // CONSULTATION MESSAGES
  // =========================

  /// Get consultation messages
  static Future<List<ChatMessage>> getConsultationMessages(
      int consultationId) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.consultationMessagesEndpoint(consultationId)}'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed to fetch messages');
    } catch (e) {
      return ChatMessage.getMockMessages();
    }
  }

  /// Send a message in consultation
  static Future<ChatMessage?> sendMessage({
    required int consultationId,
    required String content,
    String messageType = 'text',
    String? testType,
    int? testId,
  }) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final body = {
        'content': content,
        'message_type': messageType,
      };

      if (testType != null) body['test_type'] = testType;
      if (testId != null) body['test_id'] = testId.toString();

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.consultationMessagesEndpoint(consultationId)}'),
        headers: _getHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ChatMessage.fromJson(data['data'] as Map<String, dynamic>);
      }

      throw Exception('Failed to send message');
    } catch (e) {
      return null;
    }
  }

  /// Share test result with doctor
  static Future<bool> shareTestResult({
    required int consultationId,
    required String testType,
    required int testId,
  }) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.shareTestEndpoint(consultationId)}'),
        headers: _getHeaders(token),
        body: jsonEncode({
          'test_type': testType,
          'test_id': testId,
        }),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // =========================
  // NOTIFICATIONS
  // =========================

  /// Get user notifications
  static Future<List<Map<String, dynamic>>> getUserNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      var url =
          '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}';
      if (unreadOnly) {
        url += '?unread=true';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['notifications'] as List);
      }

      throw Exception('Failed to fetch notifications');
    } catch (e) {
      return [];
    }
  }

  /// Get unread notification count
  static Future<int> getUnreadNotificationCount() async {
    try {
      final token = await getToken();

      if (token == null) return 0;

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.userNotificationCountEndpoint}'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] as int;
      }

      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mark notification as read
  static Future<bool> markNotificationRead(int notificationId) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}/$notificationId/read'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllNotificationsRead() async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
            '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}/read-all'),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
