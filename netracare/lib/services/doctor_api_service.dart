import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/consultation/consultation_model.dart';
import '../models/consultation/doctor_model.dart';
import '../models/consultation/doctor_slot_model.dart';
import '../models/doctor/medical_record_model.dart';

/// API Service for Doctor-Patient linking and consultations
/// Handles real API calls to the backend
class DoctorApiService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const String _tokenKey = 'auth_token';
  static const String _doctorTokenKey = 'doctor_token';
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

  static Future<http.Response> _put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http
        .put(uri, headers: headers, body: body)
        .timeout(_requestTimeout, onTimeout: _onTimeout);
  }

  static Future<http.Response> _delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http
        .delete(uri, headers: headers, body: body)
        .timeout(_requestTimeout, onTimeout: _onTimeout);
  }

  static Future<http.Response> _onTimeout() {
    throw Exception(
      'Request timed out. Please check your internet connection and try again.',
    );
  }

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

      final response = await _post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorChangePasswordEndpoint}',
        ),
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

      final response = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorAllUsersEndpoint}'),
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

      final response = await _post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.shareTestEndpointRaw(consultationId)}',
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

      final response = await _get(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.consultationMessagesEndpointRaw(consultationId)}',
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

      final response = await _post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.consultationMessagesEndpointRaw(consultationId)}',
        ),
        headers: _getHeaders(token),
        body: jsonEncode({'content': message}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(
          data['data'] ?? data['chat_message'] ?? {},
        );
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

      final response = await _get(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorConsultationMessagesEndpointRaw(consultationId)}',
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

      final response = await _post(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorConsultationMessagesEndpointRaw(consultationId)}',
        ),
        headers: _getHeaders(token),
        body: jsonEncode({'content': message}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Map<String, dynamic>.from(
          data['data'] ?? data['chat_message'] ?? {},
        );
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

      final response = await _put(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.consultationDetailEndpointRaw(consultationId)}',
        ),
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

      final response = await _put(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.consultationDetailEndpointRaw(consultationId)}',
        ),
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

  /// Mark a consultation as completed
  static Future<void> completeConsultation({
    required String consultationId,
  }) async {
    try {
      final token = await getDoctorToken();
      if (token == null) {
        throw Exception('Please login as a doctor');
      }

      final response = await _put(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.consultationDetailEndpointRaw(consultationId)}',
        ),
        headers: _getHeaders(token),
        body: jsonEncode({'status': 'completed'}),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to complete consultation');
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

      final response = await _get(Uri.parse(url), headers: _getHeaders(null));

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

      final response = await _get(Uri.parse(url), headers: _getHeaders(null));

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

      final response = await _get(Uri.parse(url), headers: _getHeaders(null));

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
    String consultationType = 'chat',
    String? reason,
    String? preferredDatetime,
    int? doctorSlotId,
  }) async {
    try {
      final token = await getToken();

      if (token == null) {
        throw Exception('Please login to book a consultation');
      }

      final response = await _post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.bookConsultationEndpoint}'),
        headers: _getHeaders(token),
        body: jsonEncode({
          'doctor_id': doctorId,
          'consultation_type': consultationType,
          'reason': reason,
          if (preferredDatetime != null)
            'preferred_datetime': preferredDatetime,
          if (doctorSlotId != null) 'doctor_slot_id': doctorSlotId,
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

  /// Get available doctor assigned physical slots for patient booking
  static Future<List<DoctorSlot>> getAvailableDoctorSlots({
    required int doctorId,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Please login');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.availableDoctorSlotsEndpoint}?doctor_id=$doctorId',
    );

    final response = await _get(uri, headers: _getHeaders(token));
    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to fetch slots');
    }

    final data = jsonDecode(response.body);
    return (data['slots'] as List)
        .map((slot) => DoctorSlot.fromJson(slot as Map<String, dynamic>))
        .toList();
  }

  /// Get doctor's managed physical slots
  static Future<List<DoctorSlot>> getDoctorSlots({
    bool includePast = false,
  }) async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.doctorSlotsEndpoint}?include_past=${includePast.toString()}',
    );
    final response = await _get(uri, headers: _getHeaders(token));

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to fetch doctor slots');
    }

    final data = jsonDecode(response.body);
    return (data['slots'] as List)
        .map((slot) => DoctorSlot.fromJson(slot as Map<String, dynamic>))
        .toList();
  }

  /// Create doctor-assigned physical slot
  static Future<DoctorSlot> createDoctorSlot({
    required DateTime slotStartAtUtc,
    String? location,
    bool isActive = true,
  }) async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final response = await _post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorSlotsEndpoint}'),
      headers: _getHeaders(token),
      body: jsonEncode({
        'slot_start_at': slotStartAtUtc.toUtc().toIso8601String(),
        'location': location,
        'is_active': isActive,
      }),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to create slot');
    }

    final data = jsonDecode(response.body);
    return DoctorSlot.fromJson(data['slot'] as Map<String, dynamic>);
  }

  /// Update doctor-assigned slot
  static Future<DoctorSlot> updateDoctorSlot({
    required int slotId,
    DateTime? slotStartAtUtc,
    String? location,
    bool? isActive,
  }) async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final payload = <String, dynamic>{
      if (slotStartAtUtc != null)
        'slot_start_at': slotStartAtUtc.toUtc().toIso8601String(),
      if (location != null) 'location': location,
      if (isActive != null) 'is_active': isActive,
    };

    final response = await _put(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.doctorSlotDetailEndpoint(slotId)}',
      ),
      headers: _getHeaders(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to update slot');
    }

    final data = jsonDecode(response.body);
    return DoctorSlot.fromJson(data['slot'] as Map<String, dynamic>);
  }

  /// Delete doctor-assigned slot
  static Future<void> deleteDoctorSlot(int slotId) async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final response = await _delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.doctorSlotDetailEndpoint(slotId)}',
      ),
      headers: _getHeaders(token),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to delete slot');
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

      final response = await _get(Uri.parse(url), headers: _getHeaders(token));

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

      final response = await _get(
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

      final response = await _post(
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

      final response = await _get(Uri.parse(url), headers: _getHeaders(token));

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

      final response = await _get(
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

      final response = await _post(
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

      final response = await _post(
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

      final response = await _delete(
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

      final response = await _get(Uri.parse(url), headers: _getHeaders(token));

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

      final response = await _get(
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

      final response = await _post(
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

      final response = await _post(
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

      final response = await _delete(
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

  // =========================
  // PATIENT DOCUMENTS/RECORDS
  // =========================

  /// Get patient test results for sharing
  static Future<List<Map<String, dynamic>>> getPatientTestResults(
    String patientId,
  ) async {
    try {
      final token = await getDoctorToken();
      if (token == null) return [];

      final response = await _get(
        Uri.parse('${ApiConfig.baseUrl}/api/patients/$patientId/test-results'),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(
          data['test_results'] as List? ?? [],
        );
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching patient test results: $e');
      return [];
    }
  }

  /// Get patient clinical notes for sharing
  static Future<List<Map<String, dynamic>>> getPatientClinicalNotes(
    String patientId,
  ) async {
    try {
      final token = await getDoctorToken();
      if (token == null) return [];

      final response = await _get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/patients/$patientId/clinical-notes',
        ),
        headers: _getHeaders(token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(
          data['clinical_notes'] as List? ?? [],
        );
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching patient clinical notes: $e');
      return [];
    }
  }

  /// Send message with attachments
  static Future<bool> sendChatMessageWithAttachments({
    required bool isDoctor,
    required int consultationId,
    required String? message,
    required List<Map<String, dynamic>> attachments,
  }) async {
    try {
      final token = isDoctor ? await getDoctorToken() : await getToken();
      if (token == null) return false;

      // Determine message_type based on attachment type
      String messageType = 'attachment';
      if (attachments.isNotEmpty) {
        final attachmentType =
            attachments.first['type']?.toString().toLowerCase() ?? '';
        if (attachmentType.contains('test')) {
          messageType = 'testResult';
        } else if (attachmentType.contains('clinical')) {
          messageType = 'clinicalNote';
        } else if (attachmentType.contains('medical')) {
          messageType = 'medicalRecord';
        }
      }

      final endpoint = isDoctor
          ? ApiConfig.doctorConsultationMessagesEndpointRaw(
              consultationId.toString(),
            )
          : ApiConfig.consultationMessagesEndpointRaw(
              consultationId.toString(),
            );

      final response = await _post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: _getHeaders(token),
        body: jsonEncode({
          'content': message,
          'message_type': messageType,
          'attachments': attachments,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending chat message with attachments: $e');
      return false;
    }
  }

  // =========================
  // MEDICAL RECORDS
  // =========================

  /// Upload a file to the backend and return `{file_url, file_name, file_size, mime_type}`.
  static Future<Map<String, dynamic>> uploadRecordFile({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final token = await getDoctorToken();
    if (token == null) throw Exception('Please login as a doctor');

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.medicalRecordUploadEndpoint}',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as Map<String, dynamic>);
    }
    final error = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(error['message'] ?? 'File upload failed');
  }

  static Future<Map<String, dynamic>> createMedicalRecord({
    required String patientId,
    required MedicalRecordType recordType,
    required String title,
    required String description,
    String category = 'general',
    String? fileUrl,
    String? fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final response = await _post(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.doctorMedicalRecordsEndpoint}',
      ),
      headers: _getHeaders(token),
      body: jsonEncode({
        'patient_id': int.tryParse(patientId),
        'record_type': recordType.apiValue,
        'title': title,
        'description': description,
        'category': category,
        'file_url': fileUrl,
        'file_name': fileName,
        'file_size': fileSize,
        'mime_type': mimeType,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data['record'] ?? data);
    }

    final error = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(error['message'] ?? 'Failed to create medical record');
  }

  static Future<Map<String, dynamic>> createClinicalNote({
    required String patientId,
    required String title,
    required String content,
    required NoteCategory category,
  }) async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final response = await _post(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.doctorMedicalRecordsEndpoint}',
      ),
      headers: _getHeaders(token),
      body: jsonEncode({
        'patient_id': int.tryParse(patientId),
        'record_type': 'clinical_note',
        'title': title,
        'description': content,
        'category': category.apiValue,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Map<String, dynamic>.from(data['record'] ?? data);
    }

    final error = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(error['message'] ?? 'Failed to create clinical note');
  }

  static Future<List<Map<String, dynamic>>> getDoctorMedicalRecords() async {
    final token = await getDoctorToken();
    if (token == null) {
      throw Exception('Please login as a doctor');
    }

    final response = await _get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.doctorMedicalRecordsEndpoint}',
      ),
      headers: _getHeaders(token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['records'] ?? const []);
    }

    final error = jsonDecode(response.body) as Map<String, dynamic>;
    throw Exception(error['message'] ?? 'Failed to fetch medical records');
  }
}
