import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_button.dart';
import '../auth/providers/auth_provider.dart';
import '../subscription/providers/subscription_provider.dart';
import 'widgets/edit_name_bottom_sheet.dart';

/// Profile screen displaying user avatar, details, active subscription info, and quick actions.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showEditNameSheet(BuildContext context, WidgetRef ref, String currentName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) => EditNameBottomSheet(
        initialName: currentName,
        onSave: (newName) {
          ref.read(authProvider.notifier).updateProfile(name: newName);
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go(AppRoutes.authPath);
              }
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(authProvider).value;
    final subAsync = ref.watch(userSubscriptionProvider);

    final userName = user?.name ?? 'User';
    final userEmail = user?.email ?? '';
    final isGuest = user?.isGuest ?? false;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Big round avatar
              AppAvatar(
                name: userName,
                size: 80,
                type: AppAvatarType.user,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                userName,
                style: AppTextStyles.titleLarge.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                userEmail,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              if (isGuest) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Text(
                    'Guest Session',
                    style: AppTextStyles.micro.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Active Subscription Section
              subAsync.when(
                data: (sub) => Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.workspace_premium_rounded, size: 20, color: colors.primary),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '${sub.planName} Tier',
                                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                            decoration: BoxDecoration(
                              color: sub.hasSubscription
                                  ? colors.success.withValues(alpha: 0.15)
                                  : colors.textSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Text(
                              sub.hasSubscription ? 'ACTIVE' : 'FREE',
                              style: AppTextStyles.micro.copyWith(
                                color: sub.hasSubscription ? colors.success : colors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        sub.endDate != null
                            ? 'Subscription expires on ${AppDateFormatters.formatDateDivider(sub.endDate!)}'
                            : 'Free plan with 10-minute trial session. Upgrade for unlimited reasoning.',
                        style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push(AppRoutes.subscriptionPath),
                          child: Text(sub.hasSubscription ? 'Manage Subscription' : 'Upgrade to Unlimited'),
                        ),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (err, stack) => const SizedBox.shrink(),
              ),

              const SizedBox(height: AppSpacing.md),

              // Details card
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: Text('Display Name', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                      subtitle: Text(userName, style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                      trailing: Icon(Icons.edit_outlined, size: 18, color: colors.textSecondary),
                      onTap: () => _showEditNameSheet(context, ref, userName),
                    ),
                    Divider(color: colors.border, height: 1),
                    ListTile(
                      title: Text('Account Email', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                      subtitle: Text(userEmail, style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                    ),
                    if (user != null) ...[
                      Divider(color: colors.border, height: 1),
                      ListTile(
                        title: Text('User ID', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                        subtitle: Text('#${user.id}', style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                      ),
                      Divider(color: colors.border, height: 1),
                      ListTile(
                        title: Text('Registered Since', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                        subtitle: Text(
                          AppDateFormatters.formatDateDivider(user.createdAt),
                          style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Navigation Card for other screens
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.people_alt_outlined, color: colors.textPrimary, size: 20),
                      title: Text('Users Directory', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('View registered accounts (GET /users/)', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                      trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                      onTap: () => context.push(AppRoutes.usersPath),
                    ),
                    Divider(color: colors.border, height: 1),
                    ListTile(
                      leading: Icon(Icons.history_rounded, color: colors.textPrimary, size: 20),
                      title: Text('Chat History', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('Manage all previous conversation threads', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                      trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                      onTap: () => context.push(AppRoutes.historyPath),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              AppButton(
                text: 'Sign Out',
                variant: AppButtonVariant.secondary,
                icon: Icons.logout_rounded,
                onPressed: () => _confirmLogout(context, ref),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
