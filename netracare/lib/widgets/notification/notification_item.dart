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

  Color get _accentColor {
    switch (notification.type) {
      case 'consultation_request':
        return AppTheme.info;
      case 'consultation_scheduled':
        return AppTheme.primary;
      case 'new_message':
        return AppTheme.success;
      case 'test_shared':
        return AppTheme.warning;
      default:
        return AppTheme.info;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'consultation_request':
        return Icons.video_call;
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

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spaceMD),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: const Icon(Icons.delete_outline, color: AppTheme.error),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
          padding: const EdgeInsets.all(AppTheme.spaceMD),
          decoration: BoxDecoration(
            color: notification.isRead
                ? AppTheme.surface
                : _accentColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: notification.isRead
                  ? AppTheme.border
                  : _accentColor.withValues(alpha: 0.15),
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
                  color: _accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(_icon, color: _accentColor, size: 20),
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
                              color: AppTheme.textPrimary,
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
                              color: _accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: AppTheme.fontSM,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          notification.timeAgo,
                          style: const TextStyle(
                            fontSize: AppTheme.fontXS,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (!notification.isRead)
                          GestureDetector(
                            onTap: onMarkRead,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.check_circle_outline,
                                size: 18,
                                color: AppTheme.textSecondary,
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
