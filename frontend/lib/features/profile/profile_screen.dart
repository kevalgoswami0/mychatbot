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
import '../history/providers/history_provider.dart';
import '../settings/providers/settings_provider.dart';
import '../subscription/providers/subscription_provider.dart';
import 'widgets/edit_name_bottom_sheet.dart';

/// Unified Profile & Settings screen displaying user details, active subscription info,
/// appearance (theme), conversation data management, account deletion, and sign out.
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

  Future<void> _confirmClearAllChats(BuildContext context, WidgetRef ref) async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        title: const Text('Clear All Conversations?'),
        content: const Text(
          'This action cannot be undone. All your chat sessions and message histories will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(conversationsProvider.notifier).clearAll();
      if (context.mounted) {
        context.showSnackBar('All conversations cleared');
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.error, size: 24),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Delete Account?')),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your account?\n\nThis will erase all your messages, chat history, active subscriptions, and user data from our database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Deleting your account...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      await ref.read(authProvider.notifier).deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your account has been deleted permanently.'),
            duration: Duration(seconds: 3),
          ),
        );
        context.go(AppRoutes.authPath);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: colors.error,
            content: Text('Failed to delete account: ${e.toString().replaceAll('Exception: ', '')}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
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
              context.go(AppRoutes.authPath);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChangePassword(BuildContext context, WidgetRef ref, String email) async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colors.border),
        ),
        title: const Text('Change Password'),
        content: Text(
          'We will send a password reset verification code to $email.\n\nWould you like to proceed?',
          style: AppTextStyles.bodyMedium.copyWith(color: colors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Code'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Sending password reset code...'),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );

    try {
      final msg = await ref.read(authProvider.notifier).forgotPassword(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.showSnackBar(msg.isNotEmpty ? msg : 'Verification code sent to $email');
        context.push(AppRoutes.verifyResetOtpPath, extra: email);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        context.showSnackBar(
          'Failed to send verification code: ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final user = ref.watch(authProvider).value;
    final subAsync = ref.watch(userSubscriptionProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    final userName = user?.name ?? 'User';
    final userEmail = user?.email ?? '';
    final isGuest = user?.isGuest ?? false;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Profile & Settings',
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.xs),
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

              const SizedBox(height: AppSpacing.lg),

              // Details card
              _SectionHeader(title: 'Account Information'),
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
                    if (user != null && !isGuest) ...[
                      Divider(color: colors.border, height: 1),
                      ListTile(
                        title: Text(
                          'Change Password',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Send verification code to reset password',
                          style: AppTextStyles.caption.copyWith(color: colors.textSecondary),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.textSecondary),
                        onTap: () => _handleChangePassword(context, ref, userEmail),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Appearance Section
              _SectionHeader(title: 'Appearance'),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  children: [
                    _ThemeRadioTile(
                      title: 'System Default',
                      subtitle: 'Match system device theme',
                      icon: Icons.brightness_auto_rounded,
                      selected: currentThemeMode == ThemeMode.system,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system),
                    ),
                    Divider(color: colors.border, height: 1),
                    _ThemeRadioTile(
                      title: 'Light Mode',
                      subtitle: 'Clean light aesthetics',
                      icon: Icons.light_mode_outlined,
                      selected: currentThemeMode == ThemeMode.light,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light),
                    ),
                    Divider(color: colors.border, height: 1),
                    _ThemeRadioTile(
                      title: 'Dark Mode',
                      subtitle: 'Pure dark surface colors',
                      icon: Icons.dark_mode_outlined,
                      selected: currentThemeMode == ThemeMode.dark,
                      onTap: () => ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Data & Privacy Section
              _SectionHeader(title: 'Data & Privacy'),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.history_rounded, color: colors.textPrimary, size: 20),
                      title: Text('Chat History', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      subtitle: Text('Manage all previous conversation threads', style: AppTextStyles.caption.copyWith(color: colors.textSecondary)),
                      trailing: Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
                      onTap: () => context.push(AppRoutes.historyPath),
                    ),
                    Divider(color: colors.border, height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.delete_sweep_outlined,
                        color: colors.error,
                        size: 20,
                      ),
                      title: Text(
                        'Clear All Conversations',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Erase all chats and local message histories',
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      onTap: () => _confirmClearAllChats(context, ref),
                    ),
                    Divider(color: colors.border, height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: colors.error,
                        size: 20,
                      ),
                      title: Text(
                        'Delete Account',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Permanently remove account and data from database',
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      onTap: () => _confirmDeleteAccount(context, ref),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: AppTextStyles.micro.copyWith(
            color: context.appColors.textSecondary,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ThemeRadioTile extends StatelessWidget {
  const _ThemeRadioTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        size: 22,
        color: selected ? colors.primary : colors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          color: colors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(
          color: colors.textSecondary,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colors.primary, size: 20)
          : null,
    );
  }
}
