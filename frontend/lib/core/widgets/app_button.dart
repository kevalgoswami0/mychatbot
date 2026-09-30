import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../theme/text_styles.dart';
import '../utils/extensions.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

/// Minimal, accessible, solid-color button conforming to the design spec.
/// 12px radius, 48px height minimum, zero elevation, no gradients.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.height = 48.0,
  });

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide borderSide;

    switch (variant) {
      case AppButtonVariant.primary:
        backgroundColor = colors.primary;
        foregroundColor = colors.onPrimary;
        borderSide = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        backgroundColor = colors.surface;
        foregroundColor = colors.textPrimary;
        borderSide = BorderSide(color: colors.border, width: 1);
        break;
      case AppButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        foregroundColor = colors.textPrimary;
        borderSide = BorderSide.none;
        break;
      case AppButtonVariant.danger:
        backgroundColor = colors.error;
        foregroundColor = Colors.white;
        borderSide = BorderSide.none;
        break;
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (icon != null) ...[
          Icon(icon, size: 19, color: foregroundColor),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          text,
          style: AppTextStyles.button.copyWith(
            color: effectiveOnPressed == null && !isLoading
                ? colors.textSecondary.withValues(alpha: 0.5)
                : foregroundColor,
          ),
        ),
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: Material(
        color: effectiveOnPressed == null && !isLoading
            ? (variant == AppButtonVariant.ghost ? Colors.transparent : colors.border)
            : backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: borderSide,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: effectiveOnPressed,
          splashColor: foregroundColor.withValues(alpha: 0.12),
          highlightColor: foregroundColor.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Center(child: content),
          ),
        ),
      ),
    );
  }
}
