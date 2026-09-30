import 'package:flutter/material.dart';
import '../theme/text_styles.dart';
import '../utils/extensions.dart';

enum AppAvatarType { user, bot }

/// Fully round avatar with solid colors only.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.type = AppAvatarType.user,
    this.name,
    this.size = 36.0,
    this.backgroundColor,
    this.foregroundColor,
  });

  final AppAvatarType type;
  final String? name;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final isBot = type == AppAvatarType.bot;
    final bg = backgroundColor ?? (isBot ? colors.surface : colors.primary);
    final fg = foregroundColor ?? (isBot ? colors.primary : colors.onPrimary);

    return RepaintBoundary(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
            color: colors.border,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: isBot
            ? Icon(
                Icons.auto_awesome_rounded,
                size: size * 0.52,
                color: fg,
              )
            : Text(
                (name ?? 'User').initials,
                style: AppTextStyles.micro.copyWith(
                  color: fg,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
