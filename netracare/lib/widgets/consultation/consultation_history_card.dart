import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/consultation_model.dart';
import 'package:netracare/features/chat/presentation/pages/realtime_chat_page.dart';

/// Reusable Consultation History Card Widget
class ConsultationHistoryCard extends StatelessWidget {
  final Consultation consultation;

  const ConsultationHistoryCard({super.key, required this.consultation});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: colors.medicalTestSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: colors.border),
        boxShadow: AppTheme.adaptiveCardShadow(context),
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
                      style: TextStyle(
                        fontSize: AppTheme.fontLG,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    Text(
                      consultation.date,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: colors.textSecondary,
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
                  color: _getStatusColor(
                    consultation.status,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  consultation.status.toString(),
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(consultation.status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // Consultation Type
          Row(
            children: [
              Icon(
                consultation.type == ConsultationType.physical
                    ? Icons.local_hospital_outlined
                    : Icons.chat_bubble_outline,
                size: 16,
                color: colors.textLight,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  consultation.type.toString(),
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // Notes Section
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSM),
            decoration: BoxDecoration(
              color: colors.medicalTestSurfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              consultation.notes,
              style: TextStyle(
                fontSize: AppTheme.fontSM,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMD),
          // Chat Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openChat(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Chat with Doctor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RealtimeChatPage(
          title: consultation.doctorName,
          subtitle: 'Chat',
          isDoctor: false,
          consultationId: int.tryParse(consultation.id),
          doctorId: int.tryParse(consultation.doctorId),
          avatarUrl: consultation.doctorImage,
        ),
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
      case ConsultationStatus.missed:
        return AppTheme.error;
    }
  }
}
