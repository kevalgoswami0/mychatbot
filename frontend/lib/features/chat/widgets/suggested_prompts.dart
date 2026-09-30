import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/providers/auth_provider.dart';

/// Dynamic greeting widget presented when starting a new chat or when messages are empty.
/// Replaces static prompts with a live, personalized greeting based on authenticated user data.
class SuggestedPrompts extends ConsumerWidget {
  const SuggestedPrompts({
    super.key,
    required this.onPromptSelected,
  });

  final ValueChanged<String> onPromptSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(authProvider).value;
    final String greetingName;
    if (user != null && !user.isGuest && user.name.trim().isNotEmpty) {
      greetingName = user.name.trim().split(' ').first;
    } else {
      greetingName = 'there';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambient AI Logo Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 30,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Dynamic Personalized Greeting
            Text(
              'Hello, $greetingName',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'How can I help you today?',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
