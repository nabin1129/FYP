import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/consultation_model.dart';

/// Reusable Consultation History Card Widget
class ConsultationHistoryCard extends StatelessWidget {
  final Consultation consultation;
  final VoidCallback? onAccept;

  const ConsultationHistoryCard({
    super.key,
    required this.consultation,
    this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Doctor Name and Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.doctorName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      consultation.date,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSM,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(consultation.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  consultation.status.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(consultation.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // Consultation Type and Duration
          Row(
            children: [
              Icon(
                consultation.type == ConsultationType.videoCall
                    ? Icons.videocam
                    : Icons.chat_bubble_outline,
                size: 16,
                color: AppTheme.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                consultation.type.toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              const Icon(
                Icons.access_time,
                size: 16,
                color: AppTheme.textLight,
              ),
              const SizedBox(width: 4),
              Text(
                consultation.duration,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // Notes Section
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSM),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              consultation.notes,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          // Accept Button (only for pending consultations)
          if (consultation.status == ConsultationStatus.pending && onAccept != null) ...[
            const SizedBox(height: AppTheme.spaceSM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Accept Consultation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(ConsultationStatus status) {
    switch (status) {
      case ConsultationStatus.completed:
        return AppTheme.success;
      case ConsultationStatus.scheduled:
        return AppTheme.info;
      case ConsultationStatus.pending:
        return AppTheme.warning;
      case ConsultationStatus.cancelled:
        return AppTheme.error;
    }
  }
}
