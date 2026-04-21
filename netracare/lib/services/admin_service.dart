import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/admin/admin_doctor_model.dart';
import '../models/admin/admin_user_model.dart';
import 'api_service.dart';

/// Admin Service — fully API-driven, fetches real data from backend.
/// Singleton pattern consistent with other services.
class AdminService {
  static final AdminService _instance = AdminService._internal();
  factory AdminService() => _instance;
  AdminService._internal();

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

  List<AdminDoctor> _doctors = [];
  List<AdminUser> _users = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _analytics = {};
  bool _loaded = false;
  bool _loading = false;

  // ========================================
  // DATA LOADING
  // ========================================

  bool get isLoaded => _loaded;

  Future<Map<String, String>> _adminHeaders() async {
    final token = await ApiService.getAdminToken();
    if (token == null || token.isEmpty) {
      throw 'Admin session expired. Please login again.';
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Fetch all admin data from backend in parallel.
  Future<void> loadAll() async {
    if (_loading) return;
    _loading = true;
    try {
      await Future.wait([_fetchUsers(), _fetchDoctors(), _fetchStats()]);
      _loaded = true;
    } finally {
      _loading = false;
    }
  }

  /// Force refresh all data.
  Future<void> refresh() async {
    _loaded = false;
    await loadAll();
  }

  Future<void> _fetchUsers() async {
    try {
      final headers = await _adminHeaders();
      final res = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminUsersEndpoint}'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['users'] as List? ?? [];
        _users = list
            .map((j) => AdminUser.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchDoctors() async {
    try {
      final headers = await _adminHeaders();
      final res = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminDoctorsEndpoint}'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = data['doctors'] as List? ?? [];
        _doctors = list
            .map((j) => AdminDoctor.fromJson(j as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchStats() async {
    try {
      final headers = await _adminHeaders();
      final res = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminStatsEndpoint}'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        _stats = jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {}
  }

  // ========================================
  // STATS
  // ========================================

  int get totalDoctors => _stats['total_doctors'] as int? ?? _doctors.length;
  int get totalUsers => _stats['total_users'] as int? ?? _users.length;
  int get activeDoctors =>
      _stats['active_doctors'] as int? ??
      _doctors.where((d) => d.isActive).length;
  int get activeUsers => _stats['active_users'] as int? ?? _users.length;

  double get avgRating {
    if (_doctors.isEmpty) return 0.0;
    return _doctors.fold(0.0, (sum, d) => sum + d.rating) / _doctors.length;
  }

  Map<String, dynamic> get analytics => _analytics;

  Future<Map<String, dynamic>> loadAnalytics({int days = 30}) async {
    _analytics = await getAnalyticsOverview(days: days);
    return _analytics;
  }

  // ========================================
  // DOCTOR OPERATIONS
  // ========================================

  List<AdminDoctor> get doctors => List.unmodifiable(_doctors);

  List<AdminDoctor> searchDoctors(String query, {String filter = 'all'}) {
    final q = query.toLowerCase();
    return _doctors.where((d) {
      final matchSearch =
          q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.email.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q) ||
          d.id.toLowerCase().contains(q);
      final matchFilter =
          filter == 'all' ||
          (filter == 'active' && d.isActive) ||
          (filter == 'inactive' && !d.isActive);
      return matchSearch && matchFilter;
    }).toList();
  }

  /// Create a doctor via the backend API.
  Future<AdminDoctor> addDoctor(AdminDoctor doctor) async {
    final headers = await _adminHeaders();
    final res = await _post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminCreateDoctorEndpoint}'),
      headers: headers,
      body: jsonEncode({
        'name': doctor.name,
        'email': doctor.email,
        'password': doctor.password,
        'phone': doctor.phone,
        'nhpc_number': doctor.nhpcNumber,
        'qualification': doctor.qualification,
        'specialization': doctor.specialization,
        'experience_years': doctor.experienceYears,
        'working_place': doctor.workingPlace,
        'address': doctor.address,
        'is_active': doctor.isActive,
        'is_available': doctor.isAvailable,
      }),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 201) {
      final created = AdminDoctor.fromJson(
        data['doctor'] as Map<String, dynamic>,
      );
      _doctors.insert(0, created);
      _stats['total_doctors'] = (_stats['total_doctors'] as int? ?? 0) + 1;
      return created;
    }
    throw data['message'] as String? ?? 'Failed to create doctor';
  }

  /// Update a doctor via the backend API.
  Future<AdminDoctor> updateDoctor(int backendId, AdminDoctor updated) async {
    final body = <String, dynamic>{
      'name': updated.name,
      'phone': updated.phone,
      'specialization': updated.specialization,
      'nhpc_number': updated.nhpcNumber,
      'qualification': updated.qualification,
      'experience_years': updated.experienceYears,
      'working_place': updated.workingPlace,
      'address': updated.address,
      'is_active': updated.isActive,
      'is_available': updated.isAvailable,
    };
    if (updated.password.isNotEmpty && updated.password.length >= 6) {
      body['password'] = updated.password;
    }
    final headers = await _adminHeaders();
    final res = await _put(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminDoctorUpdateEndpoint(backendId)}',
      ),
      headers: headers,
      body: jsonEncode(body),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final result = AdminDoctor.fromJson(
        data['doctor'] as Map<String, dynamic>,
      );
      final idx = _doctors.indexWhere((d) => d.backendId == backendId);
      if (idx != -1) _doctors[idx] = result;
      return result;
    }
    throw data['message'] as String? ?? 'Failed to update doctor';
  }

  /// Delete a doctor via the backend API.
  Future<void> deleteDoctor(int backendId) async {
    final headers = await _adminHeaders();
    final res = await _delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminDoctorUpdateEndpoint(backendId)}',
      ),
      headers: headers,
    );
    if (res.statusCode == 200) {
      _doctors.removeWhere((d) => d.backendId == backendId);
      _stats['total_doctors'] = (_stats['total_doctors'] as int? ?? 1) - 1;
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    throw data['message'] as String? ?? 'Failed to delete doctor';
  }

  /// Toggle doctor active status via API.
  Future<void> toggleDoctorStatus(int backendId) async {
    final doc = _doctors.firstWhere((d) => d.backendId == backendId);
    final headers = await _adminHeaders();
    final res = await _put(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminDoctorUpdateEndpoint(backendId)}',
      ),
      headers: headers,
      body: jsonEncode({'is_active': !doc.isActive}),
    );
    if (res.statusCode == 200) {
      doc.isActive = !doc.isActive;
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    throw data['message'] as String? ?? 'Failed to toggle status';
  }

  // ========================================
  // USER OPERATIONS
  // ========================================

  List<AdminUser> get users => List.unmodifiable(_users);

  List<AdminUser> searchUsers(String query, {String filter = 'all'}) {
    final q = query.toLowerCase();
    return _users.where((u) {
      final matchSearch =
          q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
      return matchSearch;
    }).toList();
  }

  /// Update a user via the backend API.
  Future<AdminUser> getUserDetail(int backendId) async {
    final headers = await _adminHeaders();
    final res = await _get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminUserDetailEndpoint(backendId)}',
      ),
      headers: headers,
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return AdminUser.fromJson(data['user'] as Map<String, dynamic>);
    }

    throw data['message'] as String? ?? 'Failed to fetch user detail';
  }

  /// Update a user via the backend API.
  Future<AdminUser> updateUser(
    int backendId,
    Map<String, dynamic> fields,
  ) async {
    final headers = await _adminHeaders();
    final res = await _put(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminUserDetailEndpoint(backendId)}',
      ),
      headers: headers,
      body: jsonEncode(fields),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      final result = AdminUser.fromJson(data['user'] as Map<String, dynamic>);
      final idx = _users.indexWhere((u) => u.backendId == backendId);
      if (idx != -1) _users[idx] = result;
      return result;
    }
    throw data['message'] as String? ?? 'Failed to update user';
  }

  /// Delete a user via the backend API.
  Future<void> deleteUser(int backendId) async {
    final headers = await _adminHeaders();
    final res = await _delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminUserDetailEndpoint(backendId)}',
      ),
      headers: headers,
    );
    if (res.statusCode == 200) {
      _users.removeWhere((u) => u.backendId == backendId);
      _stats['total_users'] = (_stats['total_users'] as int? ?? 1) - 1;
      return;
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    throw data['message'] as String? ?? 'Failed to delete user';
  }

  Future<Map<String, dynamic>> getAnalyticsOverview({int days = 30}) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.adminAnalyticsOverviewEndpoint}?days=$days',
    );

    final headers = await _adminHeaders();
    final res = await _get(uri, headers: headers);
    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 200) {
      return data;
    }

    throw data['message'] as String? ?? 'Failed to fetch analytics overview';
  }

  Future<Map<String, dynamic>> createReminder({
    required String recipientType,
    required int recipientId,
    required String title,
    required String message,
    String priority = 'normal',
    String? relatedType,
    int? relatedId,
    String? scheduledFor,
  }) async {
    final payload = <String, dynamic>{
      'recipient_type': recipientType,
      'recipient_id': recipientId,
      'title': title,
      'message': message,
      'priority': priority,
      if (relatedType != null) 'related_type': relatedType,
      if (relatedId != null) 'related_id': relatedId,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
    };

    final headers = await _adminHeaders();
    final res = await _post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminReminderCreateEndpoint}'),
      headers: headers,
      body: jsonEncode(payload),
    );

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 201) {
      return data;
    }

    throw data['message'] as String? ?? 'Failed to create reminder';
  }

  Future<Map<String, dynamic>> fetchUserReport({
    required int userId,
    int days = 30,
  }) async {
    final headers = await _adminHeaders();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.adminUserReportEndpoint(userId)}?days=$days',
    );
    final res = await _get(uri, headers: headers);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) return data['report'] as Map<String, dynamic>;
    throw data['message'] as String? ?? 'Failed to fetch report';
  }

  Future<http.Response> downloadUserReportPdf({
    required int userId,
    int days = 30,
  }) async {
    final headers = await _adminHeaders();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.adminUserReportPdfEndpoint(userId)}?days=$days',
    );
    return _get(uri, headers: headers);
  }

  // ========================================
  // MEDICAL RECORDS
  // ========================================

  Future<List<Map<String, dynamic>>> getMedicalRecords({
    bool includeDeleted = false,
  }) async {
    final response = await getMedicalRecordsPaged(
      includeDeleted: includeDeleted,
    );
    return List<Map<String, dynamic>>.from(response['records'] ?? const []);
  }

  Future<Map<String, dynamic>> getMedicalRecordsPaged({
    bool includeDeleted = false,
    String? status,
    String? recordType,
    String? query,
    int? doctorId,
    int? patientId,
    int page = 1,
    int perPage = 20,
  }) async {
    final headers = await _adminHeaders();
    final uri =
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordsEndpoint}',
        ).replace(
          queryParameters: {
            'include_deleted': includeDeleted ? 'true' : 'false',
            'page': page.toString(),
            'per_page': perPage.toString(),
            if (status != null && status.isNotEmpty) 'status': status,
            if (recordType != null && recordType.isNotEmpty)
              'record_type': recordType,
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
            if (doctorId != null) 'doctor_id': doctorId.toString(),
            if (patientId != null) 'patient_id': patientId.toString(),
          },
        );
    final res = await _get(uri, headers: headers);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return {
        'records': List<Map<String, dynamic>>.from(data['records'] ?? const []),
        'total': data['total'] ?? 0,
        'page': data['page'] ?? page,
        'per_page': data['per_page'] ?? perPage,
        'total_pages': data['total_pages'] ?? 0,
      };
    }
    throw data['message'] as String? ?? 'Failed to fetch medical records';
  }

  Future<Map<String, dynamic>> getMedicalRecordDetail(int recordId) async {
    final headers = await _adminHeaders();
    final res = await _get(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordDetailEndpoint(recordId)}',
      ),
      headers: headers,
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return data;
    }
    throw data['message'] as String? ?? 'Failed to fetch medical record detail';
  }

  /// Upload a file as an admin and return `{file_url, file_name, file_size, mime_type}`.
  Future<Map<String, dynamic>> uploadRecordFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final token = await ApiService.getAdminToken();
    if (token == null || token.isEmpty) {
      throw 'Admin session expired. Please login again.';
    }
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordUploadEndpoint}',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

    final streamed = await request.send().timeout(_requestTimeout);
    final response = await http.Response.fromStream(streamed);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return data;
    throw data['message'] as String? ?? 'File upload failed';
  }

  Future<Map<String, dynamic>> createMedicalRecord(
    Map<String, dynamic> payload,
  ) async {
    final headers = await _adminHeaders();
    final res = await _post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordsEndpoint}'),
      headers: headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }
    throw data['message'] as String? ?? 'Failed to create medical record';
  }

  Future<Map<String, dynamic>> updateMedicalRecord(
    int recordId,
    Map<String, dynamic> payload,
  ) async {
    final headers = await _adminHeaders();
    final res = await _put(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordDetailEndpoint(recordId)}',
      ),
      headers: headers,
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200) {
      return data;
    }
    throw data['message'] as String? ?? 'Failed to update medical record';
  }

  Future<void> deleteMedicalRecord(int recordId) async {
    final headers = await _adminHeaders();
    final res = await _delete(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordDetailEndpoint(recordId)}',
      ),
      headers: headers,
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw data['message'] as String? ?? 'Failed to delete medical record';
    }
  }

  Future<void> restoreMedicalRecord(int recordId) async {
    final headers = await _adminHeaders();
    final res = await _post(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordDetailEndpoint(recordId)}/restore',
      ),
      headers: headers,
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw data['message'] as String? ?? 'Failed to restore medical record';
    }
  }

  Future<void> reassignMedicalRecord({
    required int recordId,
    required int doctorId,
  }) async {
    final headers = await _adminHeaders();
    final res = await _post(
      Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.adminMedicalRecordDetailEndpoint(recordId)}/reassign',
      ),
      headers: headers,
      body: jsonEncode({'doctor_id': doctorId}),
    );
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw data['message'] as String? ?? 'Failed to reassign medical record';
    }
  }
}
