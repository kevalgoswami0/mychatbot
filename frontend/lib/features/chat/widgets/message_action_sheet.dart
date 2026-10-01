import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/message.dart';
import 'select_text_modal.dart';

/// Bottom sheet presenting message actions on long-press (Edit, Copy, Share, Regenerate, Delete).
class MessageActionSheet extends StatelessWidget {
  const MessageActionSheet({
    super.key,
    required this.message,
    required this.onDelete,
    required this.onRegenerate,
    this.onEdit,
  });

  final Message message;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag indicator handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
            // Edit Prompt action (only for user messages)
            if (message.isUser && onEdit != null) ...[
              ListTile(
                leading: Icon(Icons.edit_note_rounded, size: 22, color: colors.primary),
                title: Text(
                  'Edit prompt',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit!();
                },
              ),
            ],
            // Copy full action
            ListTile(
              leading: Icon(Icons.copy_rounded, size: 20, color: colors.textPrimary),
              title: Text('Copy text', style: AppTextStyles.bodyMedium),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Clipboard.setData(ClipboardData(text: message.content));
                context.showSnackBar('Message copied to clipboard');
              },
            ),
            // Select text section action (only for AI response)
            if (message.isAssistant) ...[
              ListTile(
                leading: Icon(Icons.highlight_alt_rounded, size: 20, color: colors.textPrimary),
                title: Text('Select text section', style: AppTextStyles.bodyMedium),
                subtitle: Text(
                  'Highlight and copy specific text',
                  style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  showSelectTextModal(context, message.content);
                },
              ),
            ],
            // Share action
            ListTile(
              leading: Icon(Icons.share_outlined, size: 20, color: colors.textPrimary),
              title: Text('Share', style: AppTextStyles.bodyMedium),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              onTap: () {
                Navigator.of(context).pop();
                // ignore: deprecated_member_use
                Share.share(
                  message.content,
                  subject: message.isUser ? 'Prompt' : 'Nova Chat Response',
                );
              },
            ),
            // Regenerate action (only for assistant messages)
            if (message.isAssistant) ...[
              ListTile(
                leading: Icon(Icons.refresh_rounded, size: 20, color: colors.textPrimary),
                title: Text('Regenerate response', style: AppTextStyles.bodyMedium),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onRegenerate();
                },
              ),
            ],
            // Delete action (only for user messages - not present when holding AI response)
            if (message.isUser) ...[
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
                title: Text(
                  'Delete message',
                  style: AppTextStyles.bodyMedium.copyWith(color: colors.error),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
