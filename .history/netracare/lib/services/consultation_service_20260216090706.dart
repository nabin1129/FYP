import '../models/consultation/consultation_model.dart';

/// Service to manage consultation state and operations
class ConsultationService {
  // Singleton pattern
  static final ConsultationService _instance = ConsultationService._internal();
  factory ConsultationService() => _instance;
  ConsultationService._internal();

  // In-memory consultation storage
  final List<Consultation> _consultations = [];
  bool _initialized = false;

  /// Initialize with mock data
  void initialize() {
    if (_initialized) return;
    _consultations.addAll(Consultation.getMockHistory());
    _initialized = true;
  }

  /// Get all consultations
  List<Consultation> getAllConsultations() {
    if (!_initialized) initialize();
    return List.unmodifiable(_consultations);
  }

  /// Get next scheduled consultation
  Consultation? getNextScheduledConsultation() {
    if (!_initialized) initialize();
    final scheduled = _consultations
        .where((c) => c.status == ConsultationStatus.scheduled)
        .toList();
    return scheduled.isNotEmpty ? scheduled.first : null;
  }

  /// Add a new consultation request
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
      duration: 'Not scheduled',
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
      duration: '30 min',
      notes: 'Consultation confirmed and scheduled.',
    );

    _consultations[index] = updatedConsultation;
    return true;
  }

  /// Cancel a consultation
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
      duration: consultation.duration,
      notes: '${consultation.notes}\nCancelled by patient.',
    );

    _consultations[index] = updatedConsultation;
    return true;
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
      'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}
