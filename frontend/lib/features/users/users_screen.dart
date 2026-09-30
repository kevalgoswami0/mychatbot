import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_avatar.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/backend_user.dart';
import 'providers/users_provider.dart';

/// Users Directory Screen showing all registered accounts from backend GET /users/.
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final usersAsync = ref.watch(usersListProvider);
    final filteredUsers = ref.watch(filteredUsersProvider);
    final searchQuery = ref.watch(userSearchQueryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Users Directory',
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(usersListProvider),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: AppTextField(
                controller: _searchController,
                hint: 'Search users by name or email...',
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(userSearchQueryProvider.notifier).clear();
                        },
                      )
                    : null,
                onChanged: (val) {
                  ref.read(userSearchQueryProvider.notifier).setQuery(val);
                },
              ),
            ),
            Expanded(
              child: usersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 36, color: colors.error),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Failed to load users: $err',
                          style: AppTextStyles.bodyMedium.copyWith(color: colors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(usersListProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (allUsers) {
                  if (allUsers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No users registered',
                      description: 'No users were found in the database.',
                    );
                  }

                  if (filteredUsers.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching users',
                      description: 'No accounts matched "$searchQuery".',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: filteredUsers.length,
                    separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return _UserCard(user: user);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final BackendUser user;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          AppAvatar(
            name: user.name,
            size: 44,
            type: AppAvatarType.user,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '#${user.id}',
                      style: AppTextStyles.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: AppTextStyles.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: user.isEmailVerified
                  ? colors.success.withValues(alpha: 0.12)
                  : colors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  user.isEmailVerified
                      ? Icons.check_circle_outline_rounded
                      : Icons.pending_outlined,
                  size: 13,
                  color: user.isEmailVerified ? colors.success : colors.error,
                ),
                const SizedBox(width: 3),
                Text(
                  user.isEmailVerified ? 'Verified' : 'Unverified',
                  style: AppTextStyles.micro.copyWith(
                    color: user.isEmailVerified ? colors.success : colors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
