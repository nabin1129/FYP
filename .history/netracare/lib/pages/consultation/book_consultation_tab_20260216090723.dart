import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/doctor_model.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/services/consultation_service.dart';
import 'package:netracare/widgets/consultation/doctor_card.dart';
import 'package:netracare/pages/consultation/doctor_chat_page.dart';

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
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceSM),
              decoration: BoxDecoration(
                color: AppTheme.testIconBackground,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(Icons.videocam, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            const Expanded(
              child: Text(
                'Request Video Consultation',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Banner
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSM),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppTheme.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Video consultation requires doctor approval. The doctor will schedule and confirm your appointment.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.info,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              const Text(
                'Requesting consultation with:',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                          child: Image.network(
                            doctor.image,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 56,
                                height: 56,
                                color: AppTheme.testIconBackground,
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.primary,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                doctor.qualification,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    const Divider(height: 1),
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildDetailRow(
                      Icons.local_hospital,
                      'Hospital',
                      doctor.workingPlace,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      Icons.verified_user,
                      'NHPC Number',
                      doctor.nhpcNumber,
                    ),
                    const SizedBox(height: 6),
                    _buildDetailRow(
                      Icons.phone,
                      'Contact',
                      doctor.contactPhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceMD),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSM),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.success.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: AppTheme.success),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Doctor available: ${doctor.nextSlot}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Create pending consultation
              final consultationService = ConsultationService();
              consultationService.requestConsultation(
                doctorName: doctor.name,
                type: ConsultationType.videoCall,
              );

              Navigator.pop(context);

              // Notify parent to refresh
              onConsultationRequested?.call();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request Sent Successfully',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Dr. ${doctor.name.split(' ').last} will review and schedule your consultation',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
            ),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _openDoctorChat(BuildContext context, Doctor doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DoctorChatPage(doctor: doctor)),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppTheme.textLight),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
