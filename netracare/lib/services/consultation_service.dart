import '../models/consultation/consultation_model.dart';
import '../models/consultation/doctor_model.dart';
import 'doctor_api_service.dart';

/// Service to manage consultation state and operations
/// Uses API service for real data, falls back to mock data
class ConsultationService {
  // Singleton pattern
  static final ConsultationService _instance = ConsultationService._internal();
  factory ConsultationService() => _instance;
  ConsultationService._internal();

  // In-memory consultation cache
  List<Consultation> _consultations = [];
  List<Doctor> _doctors = [];
  bool _initialized = false;
  final bool _useApi = true; // Set to false to use mock data only

  /// Initialize service - attempts to load from API first
  Future<void> initializeAsync() async {
    if (_initialized) return;

    try {
      if (_useApi) {
        _consultations = await DoctorApiService.getPatientConsultations();
        _doctors = await DoctorApiService.getAvailableDoctors();
      }
    } catch (e) {
      // Fallback to mock data
      _consultations = Consultation.getMockHistory();
      _doctors = Doctor.getMockDoctors();
    }

    _initialized = true;
  }

  /// Initialize with mock data (synchronous fallback)
  void initialize() {
    if (_initialized) return;
    _consultations = Consultation.getMockHistory();
    _doctors = Doctor.getMockDoctors();
    _initialized = true;
  }

  /// Get all consultations
  List<Consultation> getAllConsultations() {
    if (!_initialized) initialize();
    return List.unmodifiable(_consultations);
  }

  /// Get consultations async (fetches from API)
  Future<List<Consultation>> getAllConsultationsAsync() async {
    try {
      _consultations = await DoctorApiService.getPatientConsultations();
      return _consultations;
    } catch (e) {
      if (!_initialized) initialize();
      return _consultations;
    }
  }

  /// Get next scheduled consultation
  Consultation? getNextScheduledConsultation() {
    if (!_initialized) initialize();
    final scheduled = _consultations
        .where((c) => c.status == ConsultationStatus.scheduled)
        .toList();
    return scheduled.isNotEmpty ? scheduled.first : null;
  }

  /// Get next scheduled consultation async
  Future<Consultation?> getNextScheduledConsultationAsync() async {
    try {
      return await DoctorApiService.getNextScheduledConsultation();
    } catch (e) {
      return getNextScheduledConsultation();
    }
  }

  /// Get upcoming consultations
  Future<List<Consultation>> getUpcomingConsultations() async {
    try {
      return await DoctorApiService.getUpcomingConsultations();
    } catch (e) {
      if (!_initialized) initialize();
      return _consultations
          .where(
            (c) =>
                c.status == ConsultationStatus.scheduled ||
                c.status == ConsultationStatus.pending,
          )
          .toList();
    }
  }

  /// Get available doctors
  List<Doctor> getAvailableDoctors() {
    if (!_initialized) initialize();
    return List.unmodifiable(_doctors);
  }

  /// Get available doctors async
  Future<List<Doctor>> getAvailableDoctorsAsync({
    String? specialization,
  }) async {
    try {
      _doctors = await DoctorApiService.getAvailableDoctors(
        specialization: specialization,
      );
      return _doctors;
    } catch (e) {
      if (!_initialized) initialize();
      return _doctors;
    }
  }

  /// Search doctors
  Future<List<Doctor>> searchDoctors(String query) async {
    try {
      return await DoctorApiService.searchDoctors(query);
    } catch (e) {
      if (!_initialized) initialize();
      return _doctors
          .where(
            (d) =>
                d.name.toLowerCase().contains(query.toLowerCase()) ||
                d.specialization.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    }
  }

  /// Book a new consultation with API
  Future<Consultation?> bookConsultationAsync({
    required int doctorId,
    required ConsultationType type,
    String? reason,
    int? doctorSlotId,
  }) async {
    try {
      final consultationType = switch (type) {
        ConsultationType.physical => 'physical',
        ConsultationType.chat => 'chat',
      };

      final consultation = await DoctorApiService.bookConsultation(
        doctorId: doctorId,
        consultationType: consultationType,
        reason: reason,
        doctorSlotId: doctorSlotId,
      );

      if (consultation != null) {
        _consultations.insert(0, consultation);
      }

      return consultation;
    } catch (e) {
      rethrow;
    }
  }

  /// Add a new consultation request (local/mock)
  String requestConsultation({
    required String doctorName,
    required ConsultationType type,
    String? preferredDate,
  }) {
    if (!_initialized) initialize();

    // Generate new ID
    final newId = (_consultations.length + 1).toString();

    // Create pending consultation
    final consultation = Consultation(
      id: newId,
      doctorName: doctorName,
      date: preferredDate ?? 'Requested on ${_formatCurrentDate()}',
      type: type,
      status: ConsultationStatus.pending,
      notes: 'Awaiting doctor approval and schedule confirmation.',
    );

    // Insert at the beginning (most recent first)
    _consultations.insert(0, consultation);

    return newId;
  }

  /// Simulate doctor accepting a consultation (for demo purposes)
  bool acceptConsultation(String consultationId, String scheduledDate) {
    if (!_initialized) initialize();

    final index = _consultations.indexWhere((c) => c.id == consultationId);
    if (index == -1) return false;

    final consultation = _consultations[index];
    if (consultation.status != ConsultationStatus.pending) return false;

    // Update to scheduled
    final updatedConsultation = Consultation(
      id: consultation.id,
      doctorName: consultation.doctorName,
      date: scheduledDate,
      type: consultation.type,
      status: ConsultationStatus.scheduled,
      notes: 'Consultation confirmed and scheduled.',
    );

    _consultations[index] = updatedConsultation;
    return true;
  }

  /// Cancel a consultation
  Future<bool> cancelConsultationAsync(String consultationId) async {
    try {
      final success = await DoctorApiService.cancelConsultation(
        int.parse(consultationId),
      );

      if (success) {
        final index = _consultations.indexWhere((c) => c.id == consultationId);
        if (index != -1) {
          final consultation = _consultations[index];
          _consultations[index] = Consultation(
            id: consultation.id,
            doctorName: consultation.doctorName,
            date: consultation.date,
            type: consultation.type,
            status: ConsultationStatus.cancelled,
            notes: '${consultation.notes}\nCancelled by patient.',
          );
        }
      }

      return success;
    } catch (e) {
      return cancelConsultation(consultationId);
    }
  }

  /// Cancel a consultation (local)
  bool cancelConsultation(String consultationId) {
    if (!_initialized) initialize();

    final index = _consultations.indexWhere((c) => c.id == consultationId);
    if (index == -1) return false;

    final consultation = _consultations[index];
    final updatedConsultation = Consultation(
      id: consultation.id,
      doctorName: consultation.doctorName,
      date: consultation.date,
      type: consultation.type,
      status: ConsultationStatus.cancelled,
      notes: '${consultation.notes}\nCancelled by patient.',
    );

    _consultations[index] = updatedConsultation;
    return true;
  }

  /// Refresh data from API
  Future<void> refresh() async {
    _initialized = false;
    await initializeAsync();
  }

  /// Clear cached data
  void clear() {
    _consultations.clear();
    _doctors.clear();
    _initialized = false;
  }

  String _formatCurrentDate() {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}
