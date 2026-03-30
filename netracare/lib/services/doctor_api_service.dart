import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/consultation/consultation_model.dart';
import '../models/consultation/doctor_model.dart';

/// API Service for Doctor-Patient linking and consultations
/// Handles real API calls to the backend
class DoctorApiService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _tokenKey = 'auth_token';
  static const String _doctorTokenKey = 'doctor_token';

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
  // DOCTOR ACCOUNT MANAGEMENT
  // =========================

  /// Change doctor's password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/doctors/change-password'),
        headers: _getHeaders(token),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Password change failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all users for doctor to view
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/doctors/all-users'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['users'] ?? []);
      }

      throw Exception('Failed to fetch users');
    } catch (e) {
      rethrow;
    }
  }

  /// Share test result with doctor via consultation
  static Future<void> shareTestWithDoctor({
    required String consultationId,
    required String testType,
    required String testId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/consultations/$consultationId/share-test',
        ),
        headers: _getHeaders(token),
        body: jsonEncode({'test_type': testType, 'test_id': testId}),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to share test');
      }
    } catch (e) {
      rethrow;
    }
  }

  // =========================
  // MESSAGING (PATIENT)
  // =========================

  /// Get chat messages for patient-doctor consultation
  static Future<List<Map<String, dynamic>>> getConsultationMessages({
    required String consultationId,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/consultations/$consultationId/messages',
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }

      throw Exception('Failed to fetch messages');
    } catch (e) {
      rethrow;
    }
  }

  /// Send message from patient to doctor
  static Future<Map<String, dynamic>> sendPatientMessage({
    required String consultationId,
    required String message,
  }) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/consultations/$consultationId/messages',
        ),
        headers: _getHeaders(token),
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? {};
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to send message');
    } catch (e) {
      rethrow;
    }
  }

  // =========================
  // MESSAGING (DOCTOR)
  // =========================

  /// Get chat messages for doctor (doctor-side endpoint)
  static Future<List<Map<String, dynamic>>> getDoctorConsultationMessages({
    required String consultationId,
  }) async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/consultations/$consultationId/doctor/messages',
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['messages'] ?? []);
      }

      throw Exception('Failed to fetch messages');
    } catch (e) {
      rethrow;
    }
  }

  /// Send message from doctor to patient
  static Future<Map<String, dynamic>> sendDoctorMessage({
    required String consultationId,
    required String message,
  }) async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/consultations/$consultationId/doctor/messages',
        ),
        headers: _getHeaders(token),
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? {};
      }

      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to send message');
    } catch (e) {
      rethrow;
    }
  }

  // =========================
  // CONSULTATION MANAGEMENT
  // =========================

  /// Accept a consultation request
  static Future<void> acceptConsultation({
    required String consultationId,
  }) async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/consultations/$consultationId'),
        headers: _getHeaders(token),
        body: jsonEncode({'status': 'scheduled'}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to accept consultation');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a consultation request
  static Future<void> rejectConsultation({
    required String consultationId,
  }) async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/consultations/$consultationId'),
        headers: _getHeaders(token),
        body: jsonEncode({'status': 'rejected'}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to reject consultation');
      }
    } catch (e) {
      rethrow;
    }
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
          if (preferredDatetime != null)
            'preferred_datetime': preferredDatetime,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Consultation.fromJson(
          data['consultation'] as Map<String, dynamic>,
        );
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

      var url = '${ApiConfig.baseUrl}${ApiConfig.patientConsultationsEndpoint}';
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
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.patientUpcomingEndpoint}'),
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
          '${ApiConfig.baseUrl}${ApiConfig.cancelConsultationEndpoint(consultationId)}',
        ),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================
  // NOTIFICATIONS (USER)
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

      var url = '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}';
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
          '${ApiConfig.baseUrl}${ApiConfig.userNotificationCountEndpoint}',
        ),
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
          '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}/$notificationId/read',
        ),
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
          '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}/read-all',
        ),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete a user notification
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.delete(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.userNotificationsEndpoint}/$notificationId',
        ),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================
  // NOTIFICATIONS (DOCTOR)
  // =========================

  /// Get doctor notifications
  static Future<List<Map<String, dynamic>>> getDoctorNotifications({
    bool unreadOnly = false,
  }) async {
    try {
      final token = await getDoctorToken();

      if (token == null) {
        throw Exception('Please login');
      }

      var url = '${ApiConfig.baseUrl}${ApiConfig.doctorNotificationsEndpoint}';
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

  /// Get doctor unread notification count
  static Future<int> getDoctorUnreadNotificationCount() async {
    try {
      final token = await getDoctorToken();

      if (token == null) return 0;

      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorNotificationCountEndpoint}',
        ),
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

  /// Mark doctor notification as read
  static Future<bool> markDoctorNotificationRead(int notificationId) async {
    try {
      final token = await getDoctorToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorNotificationsEndpoint}/$notificationId/read',
        ),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Mark all doctor notifications as read
  static Future<bool> markAllDoctorNotificationsRead() async {
    try {
      final token = await getDoctorToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorNotificationsEndpoint}/read-all',
        ),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Delete a doctor notification
  /// Note: Doctor delete endpoint has /delete suffix unlike user endpoint
  static Future<bool> deleteDoctorNotification(int notificationId) async {
    try {
      final token = await getDoctorToken();

      if (token == null) {
        throw Exception('Please login');
      }

      final response = await http.delete(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorNotificationsEndpoint}/$notificationId/delete',
        ),
        headers: _getHeaders(token),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
