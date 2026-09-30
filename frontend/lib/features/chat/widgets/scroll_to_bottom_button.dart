import 'package:flutter/material.dart';
import '../../../core/utils/extensions.dart';

/// Floating circular button that animates in when user scrolls up in chat.
class ScrollToBottomButton extends StatelessWidget {
  const ScrollToBottomButton({
    super.key,
    required this.visible,
    required this.onPressed,
  });

  final bool visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedSlide(
      duration: const Duration(milliseconds: 200),
      offset: visible ? Offset.zero : const Offset(0, 2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1.0 : 0.0,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Material(
            color: colors.background,
            shape: CircleBorder(
              side: BorderSide(color: colors.border, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: visible ? onPressed : null,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
