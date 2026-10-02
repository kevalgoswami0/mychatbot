import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';

/// Clean, responsive chat input bar.
/// Handles multiline expansion (up to 5 lines), send/stop button morphing, and keyboard dismiss.
class ChatInputField extends StatefulWidget {
  const ChatInputField({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.isGenerating,
    this.enabled = true,
    this.disabledHint,
    this.onDisabledTap,
    this.onVoiceTap,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final bool isGenerating;
  final bool enabled;
  final String? disabledHint;
  final VoidCallback? onDisabledTap;
  final VoidCallback? onVoiceTap;

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _canSend) {
      setState(() => _canSend = hasText);
    }
  }

  void _submit() {
    if (!widget.enabled) {
      widget.onDisabledTap?.call();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;

    widget.onSend(text);
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isEnabled = widget.enabled;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: context.bottomPadding > 0 ? context.bottomPadding : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          top: BorderSide(
            color: colors.border.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Expanded input field
          Expanded(
            child: GestureDetector(
              onTap: !isEnabled ? widget.onDisabledTap : null,
              child: Container(
                constraints: const BoxConstraints(
                  maxHeight: 120, // ~5 lines
                ),
                decoration: BoxDecoration(
                  color: isEnabled ? colors.surface : colors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(
                    color: isEnabled ? colors.border : colors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _controller,
                  enabled: isEnabled,
                  minLines: 1,
                  maxLines: AppConstants.maxInputLines,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isEnabled ? colors.textPrimary : colors.textSecondary,
                  ),
                  cursorColor: colors.primary,
                  decoration: InputDecoration(
                    prefixIcon: !isEnabled
                        ? Icon(Icons.lock_rounded, size: 18, color: colors.primary)
                        : null,
                    hintText: !isEnabled
                        ? (widget.disabledHint ?? 'Daily limit reached. Upgrade to continue.')
                        : 'Message ${AppConstants.appName}...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: !isEnabled
                          ? colors.primary.withValues(alpha: 0.8)
                          : colors.textSecondary.withValues(alpha: 0.65),
                      fontSize: !isEnabled ? 13 : 15,
                    ),
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm + 2,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs + 2),

          // Send / Voice Call / Stop / Upgrade button
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: widget.isGenerating
                    ? colors.error
                    : (!isEnabled
                        ? colors.primary
                        : (_canSend
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.12))),
                shape: CircleBorder(
                  side: BorderSide(
                    color: widget.isGenerating
                        ? colors.error
                        : (!isEnabled
                            ? colors.primary
                            : (_canSend
                                ? colors.primary
                                : colors.primary.withValues(alpha: 0.4))),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: widget.isGenerating
                      ? widget.onStop
                      : (!isEnabled
                          ? widget.onDisabledTap
                          : (_canSend ? _submit : widget.onVoiceTap)),
                  child: Center(
                    child: widget.isGenerating
                        ? const Icon(
                            Icons.stop_rounded,
                            size: 22,
                            color: Colors.white,
                          )
                        : (!isEnabled
                            ? const Icon(
                                Icons.lock_open_rounded,
                                size: 18,
                                color: Colors.white,
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(scale: animation, child: child),
                                child: _canSend
                                    ? Icon(
                                        Icons.arrow_upward_rounded,
                                        key: const ValueKey('send_icon'),
                                        size: 22,
                                        color: colors.onPrimary,
                                      )
                                    : Icon(
                                        Icons.graphic_eq_rounded,
                                        key: const ValueKey('voice_call_icon'),
                                        size: 22,
                                        color: colors.primary,
                                      ),
                              )),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
