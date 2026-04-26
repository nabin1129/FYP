import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/doctor_model.dart';

/// Reusable Doctor Card Widget
class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onRequestBooking;
  final VoidCallback onChat;

  const DoctorCard({
    super.key,
    required this.doctor,
    required this.onRequestBooking,
    required this.onChat,
  });

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
          // Doctor Info Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor Image
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Image.network(
                  doctor.image,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colors.testIconBackground,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusMedium,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: colors.primary,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spaceMD),
              // Doctor Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.name,
                      style: TextStyle(
                        fontSize: AppTheme.fontXL,
                        fontWeight: FontWeight.bold,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.qualification,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctor.specialization,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSM),
                    // Rating and Experience
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 16,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          doctor.rating.toString(),
                          style: TextStyle(
                            fontSize: AppTheme.fontSM,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceMD),
                        Icon(
                          Icons.work_outline,
                          size: 16,
                          color: colors.textLight,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            doctor.experience,
                            style: TextStyle(
                              fontSize: AppTheme.fontSM,
                              color: colors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // Working Place & NHPC Number
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceSM),
            decoration: BoxDecoration(
              color: colors.medicalTestSurfaceMuted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_hospital, size: 16, color: colors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        doctor.workingPlace,
                        style: TextStyle(
                          fontSize: AppTheme.fontSM,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (doctor.address != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 22),
                      Expanded(
                        child: Text(
                          doctor.address!,
                          style: TextStyle(
                            fontSize: AppTheme.fontSM,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user,
                      size: 16,
                      color: colors.success,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'NHPC: ${doctor.nhpcNumber}',
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),

          // Contact Information
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 14, color: colors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        doctor.contactPhone,
                        style: TextStyle(
                          fontSize: AppTheme.fontSM,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSM),

          // Availability Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSM,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: doctor.availability.contains('Today')
                      ? colors.success.withValues(alpha: 0.1)
                      : colors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: doctor.availability.contains('Today')
                          ? colors.success
                          : colors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      doctor.availability,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        fontWeight: FontWeight.w600,
                        color: doctor.availability.contains('Today')
                            ? colors.success
                            : colors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Icon(Icons.schedule, size: 14, color: colors.textLight),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Next slot: ${doctor.nextSlot}',
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMD),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onRequestBooking,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: const Text(
                    'Request Booking',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text(
                    'Chat Now',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.primary,
                    side: BorderSide(color: colors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppTheme.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
