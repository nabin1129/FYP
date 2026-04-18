class DoctorSlot {
  final int id;
  final int doctorId;
  final DateTime slotStartAt;
  final String? location;
  final bool isActive;
  final bool isBooked;

  const DoctorSlot({
    required this.id,
    required this.doctorId,
    required this.slotStartAt,
    this.location,
    required this.isActive,
    required this.isBooked,
  });

  factory DoctorSlot.fromJson(Map<String, dynamic> json) {
    return DoctorSlot(
      id: (json['id'] as num?)?.toInt() ?? 0,
      doctorId: (json['doctor_id'] as num?)?.toInt() ?? 0,
      slotStartAt: DateTime.parse(json['slot_start_at'] as String),
      location: json['location'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isBooked: json['is_booked'] as bool? ?? false,
    );
  }

  String get displayDate {
    final local = slotStartAt.toLocal();
    return '${_month(local.month)} ${local.day}, ${local.year}';
  }

  String get displayTime {
    final local = slotStartAt.toLocal();
    final hour12 = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final amPm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $amPm';
  }

  static String _month(int month) {
    const months = [
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
    return months[month - 1];
  }
}
