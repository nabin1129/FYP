import 'package:flutter/material.dart';

import 'package:netracare/features/chat/presentation/pages/realtime_chat_page.dart';

/// Doctor-facing patient chat page.
class DoctorChatPage extends StatelessWidget {
  const DoctorChatPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.consultationId,
  });

  final String patientId;
  final String patientName;
  final int? consultationId;

  @override
  Widget build(BuildContext context) {
    return RealtimeChatPage(
      title: patientName,
      subtitle: 'Patient chat',
      isDoctor: true,
      consultationId: consultationId,
      patientId: int.tryParse(patientId),
    );
  }
}
