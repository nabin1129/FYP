import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/widgets/consultation/consultation_history_card.dart';

/// Consultation History Tab Content
class ConsultationHistoryTab extends StatelessWidget {
  final List<Consultation> consultations;

  const ConsultationHistoryTab({super.key, required this.consultations});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (consultations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color: colors.testIconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 48, color: colors.primary),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'No consultation history',
              style: TextStyle(
                fontSize: AppTheme.fontLG,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Text(
              'Your past consultations will appear here',
              style: TextStyle(
                fontSize: AppTheme.fontBody,
                color: colors.textSecondary,
              ),
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
    final missed = consultations
        .where((c) => c.status == ConsultationStatus.missed)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      children: [
        // Upcoming (Scheduled/Booked) Consultations
        if (scheduled.isNotEmpty) ...[
          Text(
            'Upcoming (Booked)',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...scheduled.map((c) => ConsultationHistoryCard(consultation: c)),
          const SizedBox(height: AppTheme.spaceMD),
        ],
        // Pending Requests
        if (pending.isNotEmpty) ...[
          Text(
            'Pending Requests',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...pending.map((c) => ConsultationHistoryCard(consultation: c)),
          const SizedBox(height: AppTheme.spaceMD),
        ],
        // Missed Consultations
        if (missed.isNotEmpty) ...[
          Text(
            'Missed',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: colors.error,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...missed.map((c) => ConsultationHistoryCard(consultation: c)),
          const SizedBox(height: AppTheme.spaceMD),
        ],
        // Completed Consultations
        if (completed.isNotEmpty) ...[
          Text(
            'Completed',
            style: TextStyle(
              fontSize: AppTheme.fontLG,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          ...completed.map((c) => ConsultationHistoryCard(consultation: c)),
        ],
      ],
    );
  }
}
