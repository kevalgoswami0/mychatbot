import 'package:flutter/animation.dart';

/// Animation durations and curves following minimalist, high-performance guidelines.
class AppDurations {
  AppDurations._();

  /// Ultra-fast micro-interaction duration (100ms)
  static const Duration fast = Duration(milliseconds: 100);

  /// Quick feedback transition (150ms)
  static const Duration quick = Duration(milliseconds: 150);

  /// Standard navigation and component transition (250ms)
  static const Duration standard = Duration(milliseconds: 250);

  /// Slightly longer transition (300ms)
  static const Duration medium = Duration(milliseconds: 300);

  /// Splash screen display duration (1200ms)
  static const Duration splash = Duration(milliseconds: 1200);

  /// Default curve for ultra-smooth, premium transitions
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Snappy curve for buttons and micro-feedback
  static const Curve snappyCurve = Curves.easeOutQuad;
}
