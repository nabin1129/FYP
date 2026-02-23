import '../models/doctor/patient_model.dart';
import '../models/doctor/medical_record_model.dart';
import '../models/doctor/doctor_analytics_model.dart';
import '../models/consultation/chat_message_model.dart';

/// Service to manage doctor dashboard operations
class DoctorService {
  // Singleton pattern
  static final DoctorService _instance = DoctorService._internal();
  factory DoctorService() => _instance;
  DoctorService._internal();

  // In-memory storage
  final List<Patient> _patients = [];
  final Map<String, List<MedicalRecord>> _medicalRecords = {};
  final Map<String, List<ClinicalNote>> _clinicalNotes = {};
  final List<ConsultationRequest> _consultationRequests = [];
  final Map<String, List<ChatMessage>> _chatHistory = {};
  DoctorAnalytics? _analytics;
  bool _initialized = false;

  /// Initialize with mock data
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

  // ============================================
  // PATIENT OPERATIONS
  // ============================================

  /// Get all patients
  List<Patient> getAllPatients() {
    if (!_initialized) initialize();
    return List.unmodifiable(_patients);
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

  // ============================================
  // ANALYTICS OPERATIONS
  // ============================================

  /// Get dashboard analytics
  DoctorAnalytics getAnalytics() {
    if (!_initialized) initialize();
    return _analytics ?? DoctorAnalytics.getMockAnalytics();
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

  /// Get pending consultation requests
  List<ConsultationRequest> getPendingRequests() {
    if (!_initialized) initialize();
    return _consultationRequests
        .where((r) => r.status == RequestStatus.pending)
        .toList();
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

  // ============================================
  // CHAT OPERATIONS
  // ============================================

  /// Get chat history with a patient
  List<ChatMessage> getChatHistory(String patientId) {
    if (!_initialized) initialize();
    return _chatHistory[patientId] ?? [];
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
