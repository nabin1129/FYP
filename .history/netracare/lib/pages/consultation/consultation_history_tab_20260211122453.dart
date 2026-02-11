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
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      itemCount: consultations.length,
      itemBuilder: (context, index) {
        return ConsultationHistoryCard(
          consultation: consultations[index],
        );
      },
    );
  }
}
