/// Model for Consultation History
class Consultation {
  final String id;
  final String doctorName;
  final String date;
  final ConsultationType type;
  final ConsultationStatus status;
  final String duration;
  final String notes;

  Consultation({
    required this.id,
    required this.doctorName,
    required this.date,
    required this.type,
    required this.status,
    required this.duration,
    required this.notes,
  });

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] as String,
      doctorName: json['doctorName'] as String,
      date: json['date'] as String,
      type: ConsultationType.fromString(json['type'] as String),
      status: ConsultationStatus.fromString(json['status'] as String),
      duration: json['duration'] as String,
      notes: json['notes'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorName': doctorName,
      'date': date,
      'type': type.toString(),
      'status': status.toString(),
      'duration': duration,
      'notes': notes,
    };
  }

  // Static method to get mock consultation history
  static List<Consultation> getMockHistory() {
    return [
      Consultation(
        id: '1',
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        date: 'May 15, 2023',
        type: ConsultationType.videoCall,
        status: ConsultationStatus.completed,
        duration: '30 min',
        notes: 'Discussed visual acuity test results. Recommended follow-up in 3 months. Prescribed corrective lenses.',
      ),
      Consultation(
        id: '2',
        doctorName: 'Dr. Anita Gurung',
        date: 'Requested on Feb 10, 2026',
        type: ConsultationType.videoCall,
        status: ConsultationStatus.pending,
        duration: 'Not scheduled',
        notes: 'Awaiting doctor approval and schedule confirmation for video consultation.',
      ),
      Consultation(
        id: '3',
        doctorName: 'Dr. Srijana Poudel',
        date: 'April 10, 2023',
        type: ConsultationType.chat,
        status: ConsultationStatus.completed,
        duration: '15 min',
        notes: 'Reviewed eye tracking test. No immediate concerns. Continue with regular eye exercises.',
      ),
      Consultation(
        id: '4',
        doctorName: 'Dr. Bikash Thapa',
        date: 'March 5, 2023',
        type: ConsultationType.videoCall,
        status: ConsultationStatus.completed,
        duration: '45 min',
        notes: 'Comprehensive eye examination. Prescribed eye drops for dry eyes. Follow-up scheduled in 2 months.',
      ),
    ];
  }
}

/// Enum for consultation types
enum ConsultationType {
  videoCall,
  chat;

  static ConsultationType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'video call':
      case 'videocall':
        return ConsultationType.videoCall;
      case 'chat':
        return ConsultationType.chat;
      default:
        return ConsultationType.chat;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ConsultationType.videoCall:
        return 'Video Call';
      case ConsultationType.chat:
        return 'Chat';
    }
  }
}

/// Enum for consultation status
enum ConsultationStatus {
  completed,
  scheduled,
  pending,
  cancelled;

  static ConsultationStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return ConsultationStatus.completed;
      case 'scheduled':
        return ConsultationStatus.scheduled;
      case 'pending':
        return ConsultationStatus.pending;
      case 'cancelled':
        return ConsultationStatus.cancelled;
      default:
        return ConsultationStatus.pending;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ConsultationStatus.completed:
        return 'Completed';
      case ConsultationStatus.scheduled:
        return 'Scheduled';
      case ConsultationStatus.pending:
        return 'Pending';
      case ConsultationStatus.cancelled:
        return 'Cancelled';
    }
  }
}
