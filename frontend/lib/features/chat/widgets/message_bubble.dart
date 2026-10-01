import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/message.dart';
import 'markdown_message_body.dart';
import 'message_action_sheet.dart';

/// Highly optimized message bubble widget.
/// Enforces RepaintBoundary, rich aesthetics, prompt editing on hold,
/// and feedback (thumbs up/down, share, copy, regenerate) on completed bot responses.
class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.onDelete,
    required this.onRegenerate,
    required this.onRetry,
    this.onEditPrompt,
    this.showAvatar = true,
  });

  final Message message;
  final VoidCallback onDelete;
  final VoidCallback onRegenerate;
  final VoidCallback onRetry;
  final ValueChanged<String>? onEditPrompt;
  final bool showAvatar;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _isLiked = false;
  bool _isDisliked = false;

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) => MessageActionSheet(
        message: widget.message,
        onDelete: widget.onDelete,
        onRegenerate: widget.onRegenerate,
        onEdit: widget.message.isUser ? () => _showEditDialog(context) : null,
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.message.content);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            'Edit Prompt',
            style: AppTextStyles.titleMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 2,
              autofocus: true,
              style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Edit your prompt...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(color: colors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              onPressed: () {
                final newText = controller.text.trim();
                if (newText.isNotEmpty && newText != widget.message.content) {
                  Navigator.of(ctx).pop();
                  widget.onEditPrompt?.call(newText);
                } else {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save & Regenerate', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAssistantActionBar(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thumbs Up
          _MicroActionButton(
            icon: _isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
            color: _isLiked ? colors.primary : colors.textSecondary,
            tooltip: 'Good response',
            onTap: () {
              setState(() {
                _isLiked = !_isLiked;
                if (_isLiked) _isDisliked = false;
              });
              if (_isLiked) {
                context.showSnackBar('Thanks for your feedback!');
              }
            },
          ),
          const SizedBox(width: AppSpacing.xxs),
          // Thumbs Down
          _MicroActionButton(
            icon: _isDisliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
            color: _isDisliked ? colors.error : colors.textSecondary,
            tooltip: 'Bad response',
            onTap: () {
              setState(() {
                _isDisliked = !_isDisliked;
                if (_isDisliked) _isLiked = false;
              });
              if (_isDisliked) {
                context.showSnackBar('Feedback submitted.');
              }
            },
          ),
          const SizedBox(width: AppSpacing.xxs),
          // Copy
          _MicroActionButton(
            icon: Icons.copy_rounded,
            color: colors.textSecondary,
            tooltip: 'Copy response',
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.message.content));
              context.showSnackBar('Response copied to clipboard');
            },
          ),
          const SizedBox(width: AppSpacing.xxs),
          // Share
          _MicroActionButton(
            icon: Icons.share_outlined,
            color: colors.textSecondary,
            tooltip: 'Share',
            onTap: () {
              // ignore: deprecated_member_use
              Share.share(widget.message.content, subject: 'Nova Chat Response');
            },
          ),
          const SizedBox(width: AppSpacing.xxs),
          // Regenerate
          _MicroActionButton(
            icon: Icons.refresh_rounded,
            color: colors.textSecondary,
            tooltip: 'Regenerate response',
            onTap: widget.onRegenerate,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isUser = widget.message.isUser;
    final isFailed = widget.message.isFailed;
    final isSent = widget.message.isSent;

    final textColor = isUser ? colors.userBubbleText : colors.textPrimary;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isUser ? AppSpacing.md : AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: GestureDetector(
                onLongPress: () => _showActionSheet(context),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: isUser ? context.screenWidth * 0.80 : context.screenWidth * 0.94,
                  ),
                  padding: isUser
                      ? const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.xs,
                        ),
                  decoration: isUser
                      ? BoxDecoration(
                          color: colors.userBubble.withValues(alpha: 0.78),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppSpacing.radiusLg),
                            topRight: Radius.circular(AppSpacing.radiusLg),
                            bottomLeft: Radius.circular(AppSpacing.radiusLg),
                            bottomRight: Radius.circular(AppSpacing.xs),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        )
                      : const BoxDecoration(
                          color: Colors.transparent,
                        ),
                  child: Column(
                    crossAxisAlignment:
                        isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // User Message Content
                      if (isUser)
                        Text(
                          widget.message.content,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: textColor,
                            height: 1.35,
                          ),
                        )
                      // Assistant Markdown / Typing / Streaming Content
                      else ...[
                        if (widget.message.content.isNotEmpty)
                          MarkdownMessageBody(
                            data: widget.message.content,
                            textColor: textColor,
                            isStreaming: widget.message.isStreaming,
                          ),
                      ],

                      // Failed error banner & retry button
                      if (isFailed) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Builder(
                          builder: (context) {
                            final errLower = (widget.message.errorMessage ?? '').toLowerCase();
                            final isLimit = errLower.contains('limit') ||
                                errLower.contains('2 min') ||
                                errLower.contains('10 min') ||
                                errLower.contains('upgrade');
                            final isSubActive = errLower.contains('subscription active');

                            final String errorLabel = isSubActive
                                ? 'Subscription active.'
                                : (isLimit ? 'Daily limit reached.' : 'Unable to get response.');

                            final Color accentColor = isSubActive || isLimit
                                ? colors.primary
                                : colors.error;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm + 2,
                                vertical: AppSpacing.xs + 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSubActive
                                        ? Icons.check_circle_outline_rounded
                                        : (isLimit
                                            ? Icons.workspace_premium_rounded
                                            : Icons.error_outline_rounded),
                                    size: 16,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      errorLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: widget.onRetry,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                          boxShadow: [
                                            BoxShadow(
                                              color: colors.primary.withValues(alpha: 0.25),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.refresh_rounded,
                                              size: 13,
                                              color: colors.onPrimary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Retry',
                                              style: AppTextStyles.caption.copyWith(
                                                color: colors.onPrimary,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],

                      // Timestamp
                      if (widget.message.content.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          AppDateFormatters.formatMessageTime(widget.message.createdAt),
                          style: AppTextStyles.micro.copyWith(
                            color: isUser
                                ? textColor.withValues(alpha: 0.7)
                                : colors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],

                      // Bottom Action Bar on completed bot response (Thumbs, Share, Copy, Regenerate)
                      if (!isUser && isSent && widget.message.content.isNotEmpty)
                        _buildAssistantActionBar(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact micro-action button for assistant message footer
class _MicroActionButton extends StatelessWidget {
  const _MicroActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}
