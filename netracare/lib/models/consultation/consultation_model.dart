// Status of a consultation
enum ConsultationStatus {
  scheduled,
  pending,
  completed,
  cancelled;

  @override
  String toString() {
    switch (this) {
      case ConsultationStatus.scheduled:
        return 'Scheduled';
      case ConsultationStatus.pending:
        return 'Pending';
      case ConsultationStatus.completed:
        return 'Completed';
      case ConsultationStatus.cancelled:
        return 'Cancelled';
    }
  }

  static ConsultationStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'scheduled':
        return ConsultationStatus.scheduled;
      case 'pending':
        return ConsultationStatus.pending;
      case 'completed':
        return ConsultationStatus.completed;
      case 'cancelled':
        return ConsultationStatus.cancelled;
      default:
        return ConsultationStatus.pending;
    }
  }
}

/// Type of consultation
enum ConsultationType {
  videoCall,
  physical,
  chat;

  @override
  String toString() {
    switch (this) {
      case ConsultationType.videoCall:
        return 'Video Call';
      case ConsultationType.physical:
        return 'Physical';
      case ConsultationType.chat:
        return 'Chat';
    }
  }

  static ConsultationType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'video_call':
      case 'videocall':
      case 'video call':
      case 'video':
        return ConsultationType.videoCall;
      case 'physical':
      case 'in_person':
      case 'in-person':
      case 'physical consultation':
        return ConsultationType.physical;
      case 'chat':
        return ConsultationType.chat;
      default:
        return ConsultationType.videoCall;
    }
  }
}

/// Consultation model used across the booking and history flows
class Consultation {
  final String id;
  final String doctorName;
  final String date;
  final ConsultationType type;
  final ConsultationStatus status;
  final String duration;
  final String notes;

  const Consultation({
    required this.id,
    required this.doctorName,
    required this.date,
    required this.type,
    required this.status,
    required this.duration,
    required this.notes,
  });

  /// Parse from API JSON response
  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: (json['id'] ?? json['consultation_id'] ?? '').toString(),
      // Support both camelCase (backend to_dict) and snake_case keys
      doctorName:
          json['doctorName'] as String? ?? json['doctor_name'] as String? ?? '',
      date:
          json['date'] as String? ??
          json['scheduled_datetime'] as String? ??
          json['created_at'] as String? ??
          '',
      type: ConsultationType.fromString(
        json['type'] as String? ??
            json['consultation_type'] as String? ??
            'chat',
      ),
      status: ConsultationStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
      duration: json['duration'] as String? ?? 'N/A',
      notes: json['notes'] as String? ?? json['reason'] as String? ?? '',
    );
  }

  /// Mock history for offline / fallback use
  static List<Consultation> getMockHistory() => [
    const Consultation(
      id: '1',
      doctorName: 'Dr. Rajesh Kumar Shrestha',
      date: 'Feb 28, 2026 — 10:00 AM',
      type: ConsultationType.videoCall,
      status: ConsultationStatus.scheduled,
      duration: '30 min',
      notes: 'Follow-up on visual acuity test results.',
    ),
    const Consultation(
      id: '2',
      doctorName: 'Dr. Srijana Poudel',
      date: 'Feb 25, 2026 — 2:00 PM',
      type: ConsultationType.chat,
      status: ConsultationStatus.completed,
      duration: '15 min',
      notes: 'Discussed colour vision test report. No concerns.',
    ),
    const Consultation(
      id: '3',
      doctorName: 'Dr. Bikash Thapa',
      date: 'Requested on Feb 24, 2026',
      type: ConsultationType.videoCall,
      status: ConsultationStatus.pending,
      duration: 'Not scheduled',
      notes: 'Awaiting doctor approval and schedule confirmation.',
    ),
  ];
}
