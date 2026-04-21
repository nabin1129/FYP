import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/doctor/patient_model.dart';
import '../models/doctor/medical_record_model.dart';
import '../models/doctor/doctor_analytics_model.dart';
import '../models/consultation/chat_message_model.dart';
import 'doctor_api_service.dart';

/// Service to manage doctor dashboard operations
/// Integrates with DoctorApiService for backend calls, with mock data fallback
class DoctorService {
  // Singleton pattern
  static final DoctorService _instance = DoctorService._internal();
  factory DoctorService() => _instance;
  DoctorService._internal();

  static const Duration _requestTimeout = Duration(seconds: 15);

  static Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return http
        .get(uri, headers: headers)
        .timeout(_requestTimeout, onTimeout: _onTimeout);
  }

  static Future<http.Response> _onTimeout() {
    throw Exception(
      'Request timed out. Please check your internet connection and try again.',
    );
  }

  // In-memory storage (cache + fallback)
  final List<Patient> _patients = [];
  final Map<String, List<MedicalRecord>> _medicalRecords = {};
  final Map<String, List<ClinicalNote>> _clinicalNotes = {};
  final List<ConsultationRequest> _consultationRequests = [];
  final Map<String, List<ChatMessage>> _chatHistory = {};
  DoctorAnalytics? _analytics;
  bool _initialized = false;

  /// Initialize with mock data (for offline/fallback)
  void initialize() {
    if (_initialized) return;

    _patients.addAll(Patient.getMockPatients());
    _consultationRequests.addAll(ConsultationRequest.getMockRequests());
    _analytics = DoctorAnalytics.getMockAnalytics();

    // Initialize medical records and clinical notes for each patient
    for (final patient in _patients) {
      _medicalRecords[patient.id] = MedicalRecord.getMockRecords(patient.id);
      _clinicalNotes[patient.id] = ClinicalNote.getMockNotes(patient.id);
      _chatHistory[patient.id] = ChatMessage.getMockMessages();
    }

    _initialized = true;
  }

  /// Initialize from API — always resets state (called on each login)
  Future<void> initializeAsync() async {
    // Reset so stale data from a previous session is cleared
    _initialized = false;
    _patients.clear();
    _consultationRequests.clear();
    _analytics = null;
    _doctorName = null;
    _doctorSpecialization = null;

    try {
      await fetchDoctorProfileAsync();

      final patients = await getPatientsAsync();
      _patients.clear();
      _patients.addAll(patients);

      final requests = await getConsultationRequestsAsync();
      _consultationRequests.clear();
      _consultationRequests.addAll(requests);

      _analytics = await getAnalyticsAsync();
      _initialized = true;
    } catch (e) {
      _initialized = true; // Mark done even on failure so sync getters work
    }
  }

  // ============================================
  // DOCTOR PROFILE
  // ============================================

  String? _doctorName;
  String? _doctorSpecialization;

  String get doctorName => _doctorName ?? 'Doctor';
  String get doctorSpecialization => _doctorSpecialization ?? '';

  /// Fetch doctor profile from API
  Future<void> fetchDoctorProfileAsync() async {
    try {
      final token = await DoctorApiService.getDoctorToken();
      if (token == null) return;

      final response = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorProfileEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final doctor = data['doctor'] as Map<String, dynamic>? ?? {};
        _doctorName = doctor['name'] as String?;
        _doctorSpecialization = doctor['specialization'] as String?;
      }
    } catch (_) {
      // Keep defaults
    }
  }

  // ============================================
  // PATIENT OPERATIONS
  // ============================================

  /// Get all patients
  List<Patient> getAllPatients() {
    if (!_initialized) initialize();
    return List.unmodifiable(_patients);
  }

  /// Get all patients from API
  Future<List<Patient>> getPatientsAsync() async {
    try {
      final token = await DoctorApiService.getDoctorToken();
      if (token == null) throw Exception('No doctor token');

      final response = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorPatientsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['patients'] as List;
        return list
            .map((p) => Patient.fromJson(p as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed: ${response.statusCode}');
    } catch (_) {
      return List.from(_patients);
    }
  }

  /// Get patient by ID
  Patient? getPatientById(String id) {
    if (!_initialized) initialize();
    try {
      return _patients.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get patient by ID from API
  Future<Patient?> getPatientByIdAsync(String id) async {
    try {
      final token = await DoctorApiService.getDoctorToken();
      if (token == null) throw Exception('No doctor token');

      final patientId = int.parse(id);
      final response = await _get(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorPatientDetailEndpoint(patientId)}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return Patient.fromJson(data['patient'] as Map<String, dynamic>);
      }

      return null;
    } catch (_) {
      return getPatientById(id);
    }
  }

  /// Search patients by name
  List<Patient> searchPatients(String query) {
    if (!_initialized) initialize();
    if (query.isEmpty) return getAllPatients();

    final lowerQuery = query.toLowerCase();
    return _patients
        .where((p) => p.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Filter patients by status
  List<Patient> filterPatientsByStatus(HealthStatus? status) {
    if (!_initialized) initialize();
    if (status == null) return getAllPatients();
    return _patients.where((p) => p.status == status).toList();
  }

  /// Search and filter patients
  List<Patient> getFilteredPatients({
    String? searchQuery,
    HealthStatus? status,
  }) {
    if (!_initialized) initialize();

    List<Patient> result = List.from(_patients);

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      result = result
          .where((p) => p.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    if (status != null) {
      result = result.where((p) => p.status == status).toList();
    }

    return result;
  }

  // ============================================
  // MEDICAL RECORDS OPERATIONS
  // ============================================

  /// Get medical records for a patient
  List<MedicalRecord> getMedicalRecords(String patientId) {
    if (!_initialized) initialize();
    return _medicalRecords[patientId] ?? [];
  }

  /// Get medical records by type
  List<MedicalRecord> getMedicalRecordsByType(
    String patientId,
    MedicalRecordType type,
  ) {
    if (!_initialized) initialize();
    return getMedicalRecords(patientId).where((r) => r.type == type).toList();
  }

  /// Add medical record
  void addMedicalRecord(MedicalRecord record) {
    if (!_initialized) initialize();

    if (!_medicalRecords.containsKey(record.patientId)) {
      _medicalRecords[record.patientId] = [];
    }
    _medicalRecords[record.patientId]!.insert(0, record);
  }

  /// Persist medical record to backend and update local cache.
  Future<MedicalRecord> addMedicalRecordAsync({
    required String patientId,
    required MedicalRecordType recordType,
    required String title,
    required String description,
    String category = 'general',
    String? fileName,
    String? fileUrl,
    int? fileSize,
    String? mimeType,
  }) async {
    final created = await DoctorApiService.createMedicalRecord(
      patientId: patientId,
      recordType: recordType,
      title: title,
      description: description,
      category: category,
      fileUrl: fileUrl,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
    );

    final record = MedicalRecord.fromJson(created);
    addMedicalRecord(record);
    return record;
  }

  Future<List<MedicalRecord>> getMedicalRecordsAsync(String patientId) async {
    try {
      final records = await DoctorApiService.getDoctorMedicalRecords();
      return records
          .where((record) {
            final recordType = (record['record_type']?.toString() ?? '')
                .toLowerCase();
            return recordType != 'clinical_note' &&
                recordType != 'test_result' &&
                record['patient_id']?.toString() == patientId;
          })
          .map(MedicalRecord.fromJson)
          .toList();
    } catch (_) {
      return getMedicalRecords(patientId);
    }
  }

  // ============================================
  // CLINICAL NOTES OPERATIONS
  // ============================================

  /// Get clinical notes for a patient
  List<ClinicalNote> getClinicalNotes(String patientId) {
    if (!_initialized) initialize();
    return _clinicalNotes[patientId] ?? [];
  }

  /// Add clinical note
  void addClinicalNote(ClinicalNote note) {
    if (!_initialized) initialize();

    if (!_clinicalNotes.containsKey(note.patientId)) {
      _clinicalNotes[note.patientId] = [];
    }
    _clinicalNotes[note.patientId]!.insert(0, note);
  }

  /// Persist clinical note to backend and update local cache.
  Future<ClinicalNote> addClinicalNoteAsync({
    required String patientId,
    required String title,
    required String content,
    required NoteCategory category,
  }) async {
    final created = await DoctorApiService.createClinicalNote(
      patientId: patientId,
      title: title,
      content: content,
      category: category,
    );

    final parsedNote = ClinicalNote.fromJson(created);
    addClinicalNote(parsedNote);
    return parsedNote;
  }

  Future<List<ClinicalNote>> getClinicalNotesAsync(String patientId) async {
    try {
      final records = await DoctorApiService.getDoctorMedicalRecords();
      return records
          .where(
            (record) =>
                (record['record_type']?.toString() ?? '').toLowerCase() ==
                'clinical_note',
          )
          .map(ClinicalNote.fromJson)
          .where((note) => note.patientId == patientId)
          .toList();
    } catch (_) {
      return getClinicalNotes(patientId);
    }
  }

  // ============================================
  // ANALYTICS OPERATIONS
  // ============================================

  /// Get dashboard analytics
  DoctorAnalytics getAnalytics() {
    if (!_initialized) initialize();
    return _analytics ?? DoctorAnalytics.getMockAnalytics();
  }

  /// Get dashboard analytics from API
  Future<DoctorAnalytics> getAnalyticsAsync() async {
    try {
      final token = await DoctorApiService.getDoctorToken();
      if (token == null) throw Exception('No doctor token');

      final response = await _get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.doctorStatsEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final stats = jsonDecode(response.body) as Map<String, dynamic>;
        final scores = _patients.map((p) => p.healthScore).toList();
        return DoctorAnalytics.fromJson(stats, scores);
      }

      throw Exception('Failed: ${response.statusCode}');
    } catch (_) {
      return _analytics ?? DoctorAnalytics.empty();
    }
  }

  /// Get patient statistics summary
  Map<String, dynamic> getPatientStats() {
    if (!_initialized) initialize();

    final goodCount = _patients
        .where((p) => p.status == HealthStatus.good)
        .length;
    final attentionCount = _patients
        .where((p) => p.status == HealthStatus.attention)
        .length;
    final criticalCount = _patients
        .where((p) => p.status == HealthStatus.critical)
        .length;

    final avgScore = _patients.isEmpty
        ? 0
        : _patients.map((p) => p.healthScore).reduce((a, b) => a + b) /
              _patients.length;

    return {
      'total': _patients.length,
      'good': goodCount,
      'attention': attentionCount,
      'critical': criticalCount,
      'averageScore': avgScore.round(),
    };
  }

  // ============================================
  // CONSULTATION OPERATIONS
  // ============================================

  /// Get all consultation requests
  List<ConsultationRequest> getConsultationRequests() {
    if (!_initialized) initialize();
    return List.unmodifiable(_consultationRequests);
  }

  /// Get all consultation requests from API
  Future<List<ConsultationRequest>> getConsultationRequestsAsync() async {
    try {
      final token = await DoctorApiService.getDoctorToken();
      if (token == null) throw Exception('No doctor token');

      final response = await _get(
        Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.doctorConsultationsEndpoint}',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['consultations'] as List;
        return list
            .map((c) => ConsultationRequest.fromJson(c as Map<String, dynamic>))
            .toList();
      }

      throw Exception('Failed: ${response.statusCode}');
    } catch (_) {
      return List.from(_consultationRequests);
    }
  }

  /// Get pending consultation requests
  List<ConsultationRequest> getPendingRequests() {
    if (!_initialized) initialize();
    return _consultationRequests
        .where((r) => r.status == RequestStatus.pending)
        .toList();
  }

  /// Get pending requests from API
  Future<List<ConsultationRequest>> getPendingRequestsAsync() async {
    // Falls back to local data until doctor pending requests API is available
    return getPendingRequests();
  }

  /// Accept consultation request
  bool acceptRequest(String requestId, String scheduledDate) {
    if (!_initialized) initialize();

    final index = _consultationRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) return false;

    final request = _consultationRequests[index];
    _consultationRequests[index] = ConsultationRequest(
      id: request.id,
      patientId: request.patientId,
      patientName: request.patientName,
      patientImageUrl: request.patientImageUrl,
      requestType: request.requestType,
      requestedAt: request.requestedAt,
      message: request.message,
      status: RequestStatus.accepted,
    );

    return true;
  }

  /// Accept consultation request via API
  Future<bool> acceptRequestAsync(
    int consultationId,
    String scheduledDate,
  ) async {
    // Falls back to local accept until schedule consultation API is available
    return acceptRequest(consultationId.toString(), scheduledDate);
  }

  /// Reject consultation request
  bool rejectRequest(String requestId) {
    if (!_initialized) initialize();

    final index = _consultationRequests.indexWhere((r) => r.id == requestId);
    if (index == -1) return false;

    final request = _consultationRequests[index];
    _consultationRequests[index] = ConsultationRequest(
      id: request.id,
      patientId: request.patientId,
      patientName: request.patientName,
      patientImageUrl: request.patientImageUrl,
      requestType: request.requestType,
      requestedAt: request.requestedAt,
      message: request.message,
      status: RequestStatus.rejected,
    );

    return true;
  }

  /// Reject consultation request via API
  Future<bool> rejectRequestAsync(int consultationId) async {
    final success = await DoctorApiService.cancelConsultation(consultationId);
    if (success) {
      rejectRequest(consultationId.toString());
    }
    return success;
  }

  // ============================================
  // CHAT OPERATIONS
  // ============================================

  /// Get chat history with a patient
  List<ChatMessage> getChatHistory(String patientId) {
    if (!_initialized) initialize();
    return _chatHistory[patientId] ?? [];
  }

  /// Get chat history from API
  Future<List<ChatMessage>> getChatHistoryAsync(int consultationId) async {
    try {
      final messages = await DoctorApiService.getConsultationMessages(
        consultationId: consultationId.toString(),
      );
      // Convert Map messages to ChatMessage objects
      return messages.map((msg) {
        return ChatMessage(
          id: msg['id']?.toString() ?? '',
          sender: msg['sender'] == 'doctor'
              ? MessageSender.doctor
              : MessageSender.user,
          message: msg['content'] ?? msg['message'] ?? '',
          time: _formatTime(msg['timestamp'] ?? msg['created_at'] ?? ''),
        );
      }).toList();
    } catch (e) {
      // Fall through to mock data
    }
    return ChatMessage.getMockMessages();
  }

  /// Format API timestamp to display time
  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp.toString());
      return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}';
    } catch (e) {
      return '';
    }
  }

  /// Send message to patient
  void sendMessage(String patientId, String message) {
    if (!_initialized) initialize();

    if (!_chatHistory.containsKey(patientId)) {
      _chatHistory[patientId] = [];
    }

    final now = DateTime.now();
    final timeStr =
        '${now.hour}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';

    final newMessage = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: MessageSender.doctor,
      message: message,
      time: timeStr,
    );

    _chatHistory[patientId]!.add(newMessage);
  }

  /// Send message via API
  Future<ChatMessage?> sendMessageAsync(
    int consultationId,
    String message,
  ) async {
    try {
      final msgData = await DoctorApiService.sendDoctorMessage(
        consultationId: consultationId.toString(),
        message: message,
      );
      return ChatMessage(
        id: msgData['id']?.toString() ?? '',
        sender: MessageSender.doctor,
        message: msgData['content'] ?? msgData['message'] ?? message,
        time: _formatTime(msgData['timestamp'] ?? msgData['created_at'] ?? ''),
      );
    } catch (e) {
      // Return null if API fails
    }
    return null;
  }

  // ============================================
  // UTILITY
  // ============================================

  /// Reset all data (for testing)
  void reset() {
    _patients.clear();
    _medicalRecords.clear();
    _clinicalNotes.clear();
    _consultationRequests.clear();
    _chatHistory.clear();
    _analytics = null;
    _initialized = false;
  }
}
