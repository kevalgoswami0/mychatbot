import 'package:flutter/material.dart';

/// Solid colors only. ABSOLUTELY NO GRADIENTS anywhere.
class AppColors {
  AppColors._();

  // --- Light Palette ---
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F7F9);
  static const Color lightBorder = Color(0xFFE6E8EC);
  static const Color lightPrimary = Color(0xFF2563EB); // Royal Cobalt Blue (Non-purple)
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightUserBubble = Color(0xFF2563EB);
  static const Color lightUserBubbleText = Color(0xFFFFFFFF);
  static const Color lightBotBubble = Color(0xFFF1F3F6);
  static const Color lightBotBubbleText = Color(0xFF111827);

  // --- Dark Palette ---
  static const Color darkBackground = Color(0xFF0E0F13);
  static const Color darkSurface = Color(0xFF16181D);
  static const Color darkBorder = Color(0xFF262A31);
  static const Color darkPrimary = Color(0xFF3B82F6); // Vibrant Blue
  static const Color darkOnPrimary = Color(0xFFFFFFFF);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkUserBubble = Color(0xFF3B82F6);
  static const Color darkUserBubbleText = Color(0xFFFFFFFF);
  static const Color darkBotBubble = Color(0xFF1D2026);
  static const Color darkBotBubbleText = Color(0xFFF3F4F6);

  // --- Semantic States ---
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color proAccent = Color(0xFFD97706);
}

/// Custom ThemeExtension to expose semantic chat colors cleanly to widgets.
@immutable
class AppCustomColors extends ThemeExtension<AppCustomColors> {
  const AppCustomColors({
    required this.background,
    required this.surface,
    required this.border,
    required this.primary,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.userBubble,
    required this.userBubbleText,
    required this.botBubble,
    required this.botBubbleText,
    required this.error,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color border;
  final Color primary;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color userBubble;
  final Color userBubbleText;
  final Color botBubble;
  final Color botBubbleText;
  final Color error;
  final Color success;

  static const light = AppCustomColors(
    background: AppColors.lightBackground,
    surface: AppColors.lightSurface,
    border: AppColors.lightBorder,
    primary: AppColors.lightPrimary,
    onPrimary: AppColors.lightOnPrimary,
    textPrimary: AppColors.lightTextPrimary,
    textSecondary: AppColors.lightTextSecondary,
    userBubble: AppColors.lightUserBubble,
    userBubbleText: AppColors.lightUserBubbleText,
    botBubble: AppColors.lightBotBubble,
    botBubbleText: AppColors.lightBotBubbleText,
    error: AppColors.error,
    success: AppColors.success,
  );

  static const dark = AppCustomColors(
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    border: AppColors.darkBorder,
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.darkOnPrimary,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    userBubble: AppColors.darkUserBubble,
    userBubbleText: AppColors.darkUserBubbleText,
    botBubble: AppColors.darkBotBubble,
    botBubbleText: AppColors.darkBotBubbleText,
    error: AppColors.error,
    success: AppColors.success,
  );

  @override
  AppCustomColors copyWith({
    Color? background,
    Color? surface,
    Color? border,
    Color? primary,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? userBubble,
    Color? userBubbleText,
    Color? botBubble,
    Color? botBubbleText,
    Color? error,
    Color? success,
  }) {
    return AppCustomColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      userBubble: userBubble ?? this.userBubble,
      userBubbleText: userBubbleText ?? this.userBubbleText,
      botBubble: botBubble ?? this.botBubble,
      botBubbleText: botBubbleText ?? this.botBubbleText,
      error: error ?? this.error,
      success: success ?? this.success,
    );
  }

  @override
  AppCustomColors lerp(ThemeExtension<AppCustomColors>? other, double t) {
    if (other is! AppCustomColors) return this;
    return AppCustomColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleText: Color.lerp(userBubbleText, other.userBubbleText, t)!,
      botBubble: Color.lerp(botBubble, other.botBubble, t)!,
      botBubbleText: Color.lerp(botBubbleText, other.botBubbleText, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}
