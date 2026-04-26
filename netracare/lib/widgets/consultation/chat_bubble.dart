import 'package:flutter/material.dart';

import 'package:netracare/config/app_theme.dart';
import 'package:netracare/features/shared/widgets/shared_widgets.dart';
import 'package:netracare/models/consultation/chat_message_model.dart';
import 'package:netracare/models/consultation/message_delivery_status.dart';

import 'chat_attachment_widget.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.isMine});

  final ChatMessage message;
  final bool? isMine;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mine = isMine ?? (message.sender == MessageSender.user);
    final bubbleColor = mine ? colors.primary : colors.surfaceLight;
    final textColor = mine ? Colors.white : colors.textPrimary;
    final metadataColor = mine
        ? Colors.white.withValues(alpha: 0.78)
        : colors.textLight;

    IconData? statusIcon;
    if (mine) {
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
        mainAxisAlignment: mine
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
                color: bubbleColor,
                border: mine
                    ? null
                    : Border.all(color: colors.border.withValues(alpha: 0.7)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusMedium),
                  topRight: const Radius.circular(AppTheme.radiusMedium),
                  bottomLeft: Radius.circular(
                    mine ? AppTheme.radiusMedium : AppTheme.radiusSmall,
                  ),
                  bottomRight: Radius.circular(
                    mine ? AppTheme.radiusSmall : AppTheme.radiusMedium,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.message.isNotEmpty)
                    AppText(message.message, color: textColor),
                  if (message.attachments != null &&
                      message.attachments!.isNotEmpty) ...[
                    if (message.message.isNotEmpty)
                      const SizedBox(height: AppTheme.spaceSM),
                    ...message.attachments!.map(
                      (attachment) => Padding(
                        padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
                        child: ChatAttachmentWidget(
                          attachment: attachment,
                          isMine: mine,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message.time,
                        style: TextStyle(
                          fontSize: AppTheme.fontXS,
                          color: metadataColor,
                        ),
                      ),
                      if (statusIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(statusIcon, size: 14, color: metadataColor),
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
