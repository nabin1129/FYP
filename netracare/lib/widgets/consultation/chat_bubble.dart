import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/chat_message_model.dart';
import 'package:netracare/models/consultation/message_delivery_status.dart';

/// Reusable Chat Bubble Widget
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    IconData? statusIcon;
    if (isUser) {
      switch (message.status) {
        case MessageDeliveryStatus.pending:
          statusIcon = Icons.access_time;
          break;
        case MessageDeliveryStatus.failed:
          statusIcon = Icons.error_outline;
          break;
        case MessageDeliveryStatus.read:
          statusIcon = Icons.done_all;
          break;
        case MessageDeliveryStatus.sent:
          statusIcon = Icons.done;
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : AppTheme.surfaceLight,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusMedium),
                  topRight: const Radius.circular(AppTheme.radiusMedium),
                  bottomLeft: Radius.circular(
                    isUser ? AppTheme.radiusMedium : AppTheme.radiusSmall,
                  ),
                  bottomRight: Radius.circular(
                    isUser ? AppTheme.radiusSmall : AppTheme.radiusMedium,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      fontSize: AppTheme.fontBody,
                      color: isUser ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppTheme.textLight,
                        ),
                      ),
                      if (statusIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          statusIcon,
                          size: 14,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.textLight,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
