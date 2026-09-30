import 'package:flutter/widgets.dart';

/// Spacing system strictly based on a 4/8 pixel grid.
class AppSpacing {
  AppSpacing._();

  /// 2px micro spacing
  static const double xxxs = 2.0;

  /// 4px extra-extra-small spacing
  static const double xxs = 4.0;

  /// 8px extra-small spacing
  static const double xs = 8.0;

  /// 12px small spacing
  static const double sm = 12.0;

  /// 16px medium spacing (base spacing)
  static const double md = 16.0;

  /// 20px medium-large spacing
  static const double ml = 20.0;

  /// 24px large spacing
  static const double lg = 24.0;

  /// 32px extra-large spacing
  static const double xl = 32.0;

  /// 40px extra-extra-large spacing
  static const double xxl = 40.0;

  /// 48px huge spacing
  static const double xxxl = 48.0;

  /// 64px display spacing
  static const double display = 64.0;

  // Corner Radii (Design Rules: 16px cards/bubbles, 12px inputs/buttons, full-round avatars/send)
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0; // inputs / buttons
  static const double radiusLg = 16.0; // cards / bubbles
  static const double radiusXl = 24.0;
  static const double radiusFull = 999.0; // avatars / send button

  // Pre-configured EdgeInsets for consistency
  static const EdgeInsets paddingZero = EdgeInsets.zero;
  static const EdgeInsets paddingAllXxs = EdgeInsets.all(xxs);
  static const EdgeInsets paddingAllXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingAllSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingAllMd = EdgeInsets.all(md);
  static const EdgeInsets paddingAllLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingAllXl = EdgeInsets.all(xl);

  static const EdgeInsets paddingHSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHLg = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets paddingVSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVLg = EdgeInsets.symmetric(vertical: lg);

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
}
