import 'package:flutter/material.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';

/// Elegant, modern typing wave indicator shown while the AI is thinking before first token.
class ThinkingWaveIndicator extends StatefulWidget {
  const ThinkingWaveIndicator({super.key});

  @override
  State<ThinkingWaveIndicator> createState() => _ThinkingWaveIndicatorState();
}

class _ThinkingWaveIndicatorState extends State<ThinkingWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 Pulsing bouncing gradient dots
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double delay = i * 0.22;
                final double value = ((_controller.value - delay) % 1.0);
                final double curve = (1.0 - (value * 2 - 1).abs());
                final double scale = 0.55 + 0.45 * curve;
                final double opacity = 0.4 + 0.6 * curve;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colors.primary.withValues(alpha: opacity),
                          const Color(0xFF06B6D4).withValues(alpha: opacity),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.4 * opacity),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(width: AppSpacing.sm + 2),
          Text(
            'Thinking...',
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic glowing pulsing wave shown at the bottom of the response while streaming tokens.
class StreamingIndicatorBadge extends StatefulWidget {
  const StreamingIndicatorBadge({super.key});

  @override
  State<StreamingIndicatorBadge> createState() => _StreamingIndicatorBadgeState();
}

class _StreamingIndicatorBadgeState extends State<StreamingIndicatorBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final val = _pulseAnimation.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06 + 0.05 * val),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.15 + 0.15 * val),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glowing pulsating dot
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: 0.6 + 0.4 * val),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.5 * val),
                        blurRadius: 8 * val,
                        spreadRadius: 2 * val,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Generating...',
                  style: AppTextStyles.micro.copyWith(
                    color: colors.primary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
