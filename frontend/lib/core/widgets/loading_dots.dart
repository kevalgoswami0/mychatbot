import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import '../utils/extensions.dart';

/// Three animated bouncing/pulsing dots with solid color and RepaintBoundary.
class LoadingDots extends StatefulWidget {
  const LoadingDots({
    super.key,
    this.color,
    this.size = 7.0,
    this.spacing = AppSpacing.xxs,
  });

  final Color? color;
  final double size;
  final double spacing;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? context.appColors.primary;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final delay = index * 0.2;
              final progress = (_controller.value - delay).clamp(0.0, 1.0);
              // Sine wave for smooth subtle bounce
              final offset = (progress <= 0.5)
                  ? (progress * 2.0)
                  : ((1.0 - progress) * 2.0);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                child: Transform.translate(
                  offset: Offset(0, -4.0 * offset),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.4 + (0.6 * offset)),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
