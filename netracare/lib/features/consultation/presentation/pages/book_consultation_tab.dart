import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/widgets/consultation/doctor_card.dart';
import 'package:netracare/widgets/consultation/booking_request_dialog.dart';
import 'doctor_chat_page.dart';

/// Book Consultation Tab Content
class BookConsultationTab extends StatelessWidget {
  final List<Doctor> doctors;
  final VoidCallback? onConsultationRequested;

  const BookConsultationTab({
    super.key,
    required this.doctors,
    this.onConsultationRequested,
  });

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: AppTheme.textLight),
            SizedBox(height: AppTheme.spaceMD),
            Text(
              'No doctors available',
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      itemCount: doctors.length,
      itemBuilder: (context, index) {
        final doctor = doctors[index];
        return DoctorCard(
          doctor: doctor,
          onVideoCall: () => _handleBookConsultation(context, doctor),
          onChat: () => _openDoctorChat(context, doctor),
        );
      },
    );
  }

  void _handleBookConsultation(BuildContext context, Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => BookingRequestDialog(
        doctor: doctor,
        onConsultationRequested: onConsultationRequested,
      ),
    );
  }

  void _openDoctorChat(BuildContext context, Doctor doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DoctorChatPage(doctor: doctor)),
    );
  }

}
