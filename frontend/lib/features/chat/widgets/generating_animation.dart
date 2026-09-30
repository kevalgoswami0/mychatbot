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
      duration: const Duration(milliseconds: 1200),
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
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 Pulsing/bouncing gradient dots
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final double delay = i * 0.2;
                final double value = ((_controller.value - delay) % 1.0);
                final double scale = 0.5 + 0.5 * (1.0 - (value * 2 - 1).abs());
                final double opacity = 0.35 + 0.65 * (1.0 - (value * 2 - 1).abs());

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withValues(alpha: opacity),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.3 * opacity),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Thinking...',
            style: AppTextStyles.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle glowing pulsing cursor shown at the footer during real-time streaming.
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
      duration: const Duration(milliseconds: 900),
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
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final val = _pulseAnimation.value;
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.5 + 0.5 * val),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.4 * val),
                      blurRadius: 6 * val,
                      spreadRadius: 2 * val,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Generating...',
            style: AppTextStyles.micro.copyWith(
              color: colors.primary.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
