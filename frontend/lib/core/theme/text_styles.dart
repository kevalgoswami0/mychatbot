import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal, clean typography system based on Inter.
class AppTextStyles {
  AppTextStyles._();

  /// Font family getter
  static String get fontFamily => GoogleFonts.inter().fontFamily ?? 'Inter';

  /// Display text style (Large headings, Splash)
  static TextStyle display = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.25,
  );

  /// Title Large (Screen titles)
  static TextStyle titleLarge = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Title Medium (Card titles, App bar title)
  static TextStyle titleMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// Title Small (Compact card titles, sub-headers)
  static TextStyle titleSmall = GoogleFonts.inter(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  /// Body Large (Chat message bubbles, primary inputs) - 15-16sp, line height 1.45
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 15.5,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    height: 1.48,
  );

  /// Body Medium (Regular description text, secondary content)
  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.45,
  );

  /// Body Small / Caption (Timestamps, chips, labels)
  static TextStyle caption = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.35,
  );

  /// Micro text (Badges, token counters)
  static TextStyle micro = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Button text style
  static TextStyle button = GoogleFonts.inter(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Code block font style
  static TextStyle code = GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}
