import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_button.dart';
import '../auth/providers/auth_provider.dart';
import '../history/providers/history_provider.dart';
import 'providers/settings_provider.dart';

/// Settings screen for theme customization, profile access, clearing chats, and logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.background,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.go(AppRoutes.authPath);
      await ref.read(authProvider.notifier).logout();
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

    // Show deleting feedback
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentThemeMode = ref.watch(themeModeProvider);
    final user = ref.watch(authProvider).value;

    final isAuthenticated = user != null;
    final userName = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name : 'User';
    final userEmail = user?.email ?? '';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          children: [
            // User Profile Card
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                side: BorderSide(color: colors.border, width: 1),
              ),
              child: InkWell(
                onTap: () {
                  if (isAuthenticated) {
                    context.push(AppRoutes.profilePath);
                  } else {
                    context.go(AppRoutes.authPath);
                  }
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      AppAvatar(name: userName, size: 48),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAuthenticated ? userName : 'Not Signed In',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isAuthenticated ? userEmail : 'Tap to sign in to your account',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
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

            // Account & Data Section
            _SectionHeader(title: 'Account & Data'),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep_outlined,
                      color: colors.error,
                      size: 22,
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
                      size: 22,
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

            // Sign out button
            AppButton(
              text: 'Sign Out',
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _logout(context, ref),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
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
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.micro.copyWith(
          color: context.appColors.textSecondary,
          letterSpacing: 0.8,
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
