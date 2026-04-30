import 'package:flutter/foundation.dart';

// Status of a consultation
enum ConsultationStatus {
  scheduled,
  pending,
  completed,
  cancelled,
  missed;

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
      case ConsultationStatus.missed:
        return 'Missed';
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
      case 'missed':
        return ConsultationStatus.missed;
      default:
        return ConsultationStatus.pending;
    }
  }
}

/// Type of consultation
enum ConsultationType {
  physical,
  chat;

  @override
  String toString() {
    switch (this) {
      case ConsultationType.physical:
        return 'Physical';
      case ConsultationType.chat:
        return 'Chat';
    }
  }

  static ConsultationType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'physical':
      case 'in_person':
      case 'in-person':
      case 'physical consultation':
        return ConsultationType.physical;
      case 'chat':
        return ConsultationType.chat;
      default:
        return ConsultationType.chat;
    }
  }
}

/// Consultation model used across the booking and history flows
class Consultation {
  final String id;
  final String doctorName;
  final String doctorId;
  final String doctorImage;
  final String date;
  final DateTime? scheduledAt; // For filtering upcoming consultations
  final ConsultationType type;
  final ConsultationStatus status;
  final String notes;

  const Consultation({
    required this.id,
    required this.doctorName,
    this.doctorId = '',
    this.doctorImage = '',
    required this.date,
    this.scheduledAt,
    required this.type,
    required this.status,
    required this.notes,
  });

  /// Parse from API JSON response
  factory Consultation.fromJson(Map<String, dynamic> json) {
    // Parse scheduledAt from ISO string if available
    DateTime? scheduledAt;
    try {
      final scheduledAtStr =
          json['scheduled_at'] as String? ??
          json['scheduledAt'] as String? ??
          json['scheduled_datetime'] as String?;
      if (scheduledAtStr != null) {
        scheduledAt = DateTime.parse(scheduledAtStr);
      }
    } catch (e) {
      // If parsing fails, leave as null
      debugPrint('Failed to parse scheduledAt: $e');
    }

    return Consultation(
      id: (json['id'] ?? json['consultation_id'] ?? '').toString(),
      // Support both camelCase (backend to_dict) and snake_case keys
      doctorName:
          json['doctorName'] as String? ?? json['doctor_name'] as String? ?? '',
      doctorId:
          (json['doctorId'] as dynamic ?? json['doctor_id'] as dynamic ?? '')
              .toString(),
      doctorImage:
          json['doctorImage'] as String? ??
          json['doctor_image'] as String? ??
          '',
      date:
          json['date'] as String? ??
          json['scheduled_datetime'] as String? ??
          json['created_at'] as String? ??
          '',
      scheduledAt: scheduledAt,
      type: ConsultationType.fromString(
        json['type'] as String? ??
            json['consultation_type'] as String? ??
            'chat',
      ),
      status: ConsultationStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
      notes: json['notes'] as String? ?? json['reason'] as String? ?? '',
    );
  }

  /// Mock history for offline / fallback use
  static List<Consultation> getMockHistory() {
    // Generate future dates relative to now
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final nextWeek = now.add(const Duration(days: 7));

    return [
      Consultation(
        id: '1',
        doctorName: 'Dr. Rajesh Kumar Shrestha',
        date: 'Tomorrow at 10:00 AM',
        scheduledAt: tomorrow.copyWith(hour: 10, minute: 0),
        type: ConsultationType.physical,
        status: ConsultationStatus.scheduled,
        notes: 'Follow-up on visual acuity test results.',
      ),
      Consultation(
        id: '2',
        doctorName: 'Dr. Srijana Poudel',
        date: 'In 7 days at 2:00 PM',
        scheduledAt: nextWeek.copyWith(hour: 14, minute: 0),
        type: ConsultationType.chat,
        status: ConsultationStatus.scheduled,
        notes: 'Discuss colour vision test findings.',
      ),
      Consultation(
        id: '3',
        doctorName: 'Dr. Bikash Thapa',
        date:
            'Requested on ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        scheduledAt: null,
        type: ConsultationType.chat,
        status: ConsultationStatus.pending,
        notes: 'Awaiting doctor approval and schedule confirmation.',
      ),
    ];
  }
}
