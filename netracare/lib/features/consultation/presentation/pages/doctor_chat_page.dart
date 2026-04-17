import 'package:flutter/material.dart';

import 'package:netracare/features/chat/presentation/pages/realtime_chat_page.dart';
import 'package:netracare/models/consultation/doctor_model.dart';

/// Patient-facing doctor chat page.
class DoctorChatPage extends StatelessWidget {
  const DoctorChatPage({super.key, required this.doctor, this.consultationId});

  final Doctor doctor;
  final int? consultationId;

  @override
  Widget build(BuildContext context) {
    return RealtimeChatPage(
      title: doctor.name,
      subtitle: doctor.specialization,
      isDoctor: false,
      consultationId: consultationId,
      doctorId: int.tryParse(doctor.id),
      avatarUrl: doctor.image,
    );
  }
}
