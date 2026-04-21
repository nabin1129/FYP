import 'package:flutter/material.dart';
import 'package:netracare/config/app_theme.dart';
import 'package:netracare/models/consultation/attachment_model.dart';

/// Widget for displaying attachments in chat
class ChatAttachmentWidget extends StatelessWidget {
  final Attachment attachment;
  final bool isMine;
  final VoidCallback? onTap;

  const ChatAttachmentWidget({
    super.key,
    required this.attachment,
    required this.isMine,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: AppTheme.spaceSM),
        padding: const EdgeInsets.all(AppTheme.spaceSM),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(
            color: isMine
                ? Colors.white.withValues(alpha: 0.3)
                : AppTheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Attachment type and title
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAttachmentIcon(),
                const SizedBox(width: AppTheme.spaceSM),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        attachment.type.displayName,
                        style: TextStyle(
                          fontSize: AppTheme.fontXS,
                          fontWeight: FontWeight.w600,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppTheme.primary,
                        ),
                      ),
                      if (attachment.linkedEntityTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          attachment.linkedEntityTitle!,
                          style: TextStyle(
                            fontSize: AppTheme.fontSM,
                            fontWeight: FontWeight.w500,
                            color: isMine ? Colors.white : AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // File name and size
            if (attachment.fileName.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSM),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      attachment.fileName,
                      style: TextStyle(
                        fontSize: AppTheme.fontXS,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.7)
                            : AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    attachment.sizeDisplay,
                    style: TextStyle(
                      fontSize: AppTheme.fontXS,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ],

            // Description
            if (attachment.linkedEntityDescription != null &&
                attachment.linkedEntityDescription!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                attachment.linkedEntityDescription!,
                style: TextStyle(
                  fontSize: AppTheme.fontXS,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // Download/View hint
            const SizedBox(height: AppTheme.spaceXS),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.download_outlined,
                  size: 12,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppTheme.primary.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap to view',
                  style: TextStyle(
                    fontSize: AppTheme.fontXS,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.primary.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentIcon() {
    IconData icon;
    Color iconColor;

    switch (attachment.type) {
      case AttachmentType.testResult:
        icon = Icons.science_outlined;
        break;
      case AttachmentType.medicalRecord:
        icon = Icons.description_outlined;
        break;
      case AttachmentType.clinicalNote:
        icon = Icons.note_outlined;
        break;
      case AttachmentType.file:
        if (attachment.isPdf) {
          icon = Icons.picture_as_pdf_outlined;
        } else if (attachment.isImage) {
          icon = Icons.image_outlined;
        } else {
          icon = Icons.attach_file_outlined;
        }
    }

    iconColor = isMine ? Colors.white : AppTheme.primary;

    return Icon(icon, size: 18, color: iconColor);
  }
}
