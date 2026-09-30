import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Extension methods on BuildContext for quick, null-safe access to theme and layout tokens.
extension BuildContextExt on BuildContext {
  /// Theme of current context
  ThemeData get theme => Theme.of(this);

  /// ColorScheme of current context
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Custom app theme colors (solid colors only)
  AppCustomColors get appColors =>
      Theme.of(this).extension<AppCustomColors>() ?? AppCustomColors.light;

  /// Whether current theme is dark
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// TextTheme of current context
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// MediaQuery shortcut
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen width
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Screen height
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Safe area top padding
  double get topPadding => MediaQuery.of(this).padding.top;

  /// Safe area bottom padding
  double get bottomPadding => MediaQuery.of(this).padding.bottom;

  /// Keyboard height / bottom inset
  double get bottomInset => MediaQuery.of(this).viewInsets.bottom;

  /// Hide active keyboard
  void hideKeyboard() {
    FocusScopeNode currentFocus = FocusScope.of(this);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  /// Show standard notification snackbar with fast 1.5s duration
  void showSnackBar(
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? appColors.error : appColors.textPrimary,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// String utility extensions
extension StringExt on String {
  /// Extract initials from a name (e.g. "John Doe" -> "JD")
  String get initials {
    if (trim().isEmpty) return 'U';
    final parts = trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
  }

  /// Clean trim or fallback
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
