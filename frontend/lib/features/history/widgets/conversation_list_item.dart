import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/conversation.dart';

/// Conversation card with swipe-to-delete, relative timestamp, and menu actions.
class ConversationListItem extends StatelessWidget {
  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Light gray background on selected with reduced opacity
    final selectedColor = context.isDarkMode
        ? const Color(0xFF2C2E33).withValues(alpha: 0.5)
        : const Color(0xFFE8ECEF).withValues(alpha: 0.55);

    final selectedBorderColor = context.isDarkMode
        ? const Color(0xFF3F4248).withValues(alpha: 0.4)
        : const Color(0xFFD3D7DD).withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Dismissible(
        key: Key(conversation.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.error,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        onDismissed: (_) => onDelete(),
        child: Material(
          color: isSelected ? selectedColor : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: isSelected
                ? BorderSide(color: selectedBorderColor, width: 1)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm + 2,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 16,
                    color: isSelected ? colors.primary : colors.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Title
                  Expanded(
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // Three dots options menu (compact child avoids default 48px IconButton)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Options',
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: BorderSide(color: colors.border, width: 1),
                    ),
                    elevation: 2,
                    color: colors.background,
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: colors.textPrimary),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Rename', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Delete',
                              style: AppTextStyles.bodyMedium.copyWith(color: colors.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
