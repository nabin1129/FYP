import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/widgets/consultation/consultation_history_card.dart';

/// Consultation History Tab Content
class ConsultationHistoryTab extends StatelessWidget {
  final List<Consultation> consultations;
  final Function(String consultationId)? onAcceptConsultation;

  const ConsultationHistoryTab({
    super.key,
    required this.consultations,
    this.onAcceptConsultation,
  });

  @override
  Widget build(BuildContext context) {
    if (consultations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color: AppTheme.testIconBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                size: 48,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            const Text(
              'No consultation history',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            const Text(
              'Your past consultations will appear here',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    // Separate consultations by status
    final scheduled = consultations
        .where((c) => c.status == ConsultationStatus.scheduled)
        .toList();
    final pending = consultations
        .where((c) => c.status == ConsultationStatus.pending)
        .toList();
    final completed = consultations
        .where((c) => c.status == ConsultationStatus.completed)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      children: [
        // Upcoming (Scheduled/Booked) Consultations
        if (scheduled.isNotEmpty) ...[
          const Text(
            'Upcoming (Booked)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...scheduled.map((c) => ConsultationHistoryCard(consultation: c)),
          const SizedBox(height: AppTheme.spaceMD),
        ],
        // Pending Requests
        if (pending.isNotEmpty) ...[
          const Text(
            'Pending Requests',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...pending.map((c) => ConsultationHistoryCard(consultation: c)),
          const SizedBox(height: AppTheme.spaceMD),
        ],
        // Completed Consultations
        if (completed.isNotEmpty) ...[
          const Text(
            'Completed',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...completed.map((c) => ConsultationHistoryCard(consultation: c)),
        ],
      ],
    );
  }
}
