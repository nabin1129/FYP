import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../services/notification_service.dart';

/// A single notification card used inside [NotificationPanel].
class NotificationItem extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback? onDelete;

  const NotificationItem({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color accentColor() {
      switch (notification.type) {
        case 'consultation_request':
          return colors.info;
        case 'consultation_scheduled':
          return colors.primary;
        case 'new_message':
          return colors.success;
        case 'test_shared':
          return colors.warning;
        default:
          return colors.info;
      }
    }

    IconData icon() {
      switch (notification.type) {
        case 'consultation_request':
          return Icons.local_hospital_outlined;
        case 'consultation_scheduled':
          return Icons.calendar_today;
        case 'new_message':
          return Icons.chat_bubble_outline;
        case 'test_shared':
          return Icons.assignment;
        default:
          return Icons.notifications_outlined;
      }
    }

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Icon(Icons.delete_outline, color: colors.error),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            color: notification.isRead
                ? colors.surface
                : colors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: notification.isRead
                  ? colors.border
                  : colors.info.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon(), color: accentColor(), size: 20),
              ),
              const SizedBox(width: AppTheme.spaceMD),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: colors.textPrimary,
                              fontSize: AppTheme.fontBody,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead) ...[
                          const SizedBox(width: AppTheme.spaceXS),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accentColor(),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: colors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          notification.timeAgo,
                          style: TextStyle(
                            fontSize: AppTheme.fontXS,
                            color: colors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (!notification.isRead)
                          GestureDetector(
                            onTap: onMarkRead,
                            child: Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
