import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/models/conversation.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';
import '../../history/widgets/conversation_list_item.dart';
import '../../history/widgets/rename_dialog.dart';
import '../../subscription/providers/subscription_provider.dart';

/// Top-right menu drawer replacing bottom navigation.
/// Shows Profile and New Chat buttons at the top, followed by full chat history with search.
class ChatMenuDrawer extends ConsumerStatefulWidget {
  const ChatMenuDrawer({
    super.key,
    required this.onSelectConversation,
    required this.onNewChat,
  });

  final ValueChanged<String> onSelectConversation;
  final VoidCallback onNewChat;

  @override
  ConsumerState<ChatMenuDrawer> createState() => _ChatMenuDrawerState();
}

class _ChatMenuDrawerState extends ConsumerState<ChatMenuDrawer> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Conversation>> _groupConversations(List<Conversation> items) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final last7DaysStart = todayStart.subtract(const Duration(days: 7));

    final Map<String, List<Conversation>> groups = {
      'Today': [],
      'Yesterday': [],
      'Previous 7 Days': [],
      'Older': [],
    };

    for (final item in items) {
      if (item.updatedAt.isAfter(todayStart)) {
        groups['Today']!.add(item);
      } else if (item.updatedAt.isAfter(yesterdayStart)) {
        groups['Yesterday']!.add(item);
      } else if (item.updatedAt.isAfter(last7DaysStart)) {
        groups['Previous 7 Days']!.add(item);
      } else {
        groups['Older']!.add(item);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  void _showRenameSheet(Conversation conversation) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (ctx) => RenameBottomSheet(
        initialTitle: conversation.title,
        onRename: (newTitle) {
          ref.read(conversationsProvider.notifier).renameConversation(conversation.id, newTitle);
        },
      ),
    );
  }

  void _handleDelete(Conversation conversation) {
    ref.read(conversationsProvider.notifier).deleteConversation(conversation.id);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${conversation.title}"'),
        duration: const Duration(milliseconds: 2000),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: context.appColors.primary,
          onPressed: () {
            ref.read(conversationsProvider.notifier).restoreConversation(conversation);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final user = ref.watch(authProvider).value;
    final activeId = ref.watch(activeConversationIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);
    final filteredConversations = ref.watch(filteredConversationsProvider);
    final searchQuery = ref.watch(historySearchQueryProvider);
    final currentPlan = ref.watch(subscriptionProvider);
    final userSubAsync = ref.watch(userSubscriptionProvider);
    final hasActiveSub = userSubAsync.value?.hasSubscription ?? false;
    final planDisplayName = userSubAsync.value?.planName != null && userSubAsync.value!.planName.isNotEmpty
        ? (userSubAsync.value!.planName.toLowerCase().contains('plan') 
            ? userSubAsync.value!.planName 
            : '${userSubAsync.value!.planName} Plan')
        : currentPlan.name;

    final isAuthenticated = user != null;
    final userName = (user?.name != null && user!.name.trim().isNotEmpty) ? user.name : 'User';
    final userEmail = user?.email ?? '';

    return Drawer(
      backgroundColor: colors.background,
      elevation: 0,
      width: context.screenWidth * 0.85 > 340 ? 340 : context.screenWidth * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(AppSpacing.radiusLg)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar with Close icon
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(Icons.menu_open_rounded, size: 18, color: colors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Menu',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: 'Close Menu',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border.withValues(alpha: 0.6), height: 1),

            // Top Primary Action: New Chat Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: AppButton(
                text: 'New Chat',
                icon: Icons.add_rounded,
                variant: AppButtonVariant.primary,
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onNewChat();
                },
              ),
            ),

            // History Section Header with prominent RECENT CHATS label & Search toggle icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'RECENT CHATS',
                        style: AppTextStyles.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 11,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _isSearchExpanded ? Icons.close_rounded : Icons.search_rounded,
                          size: 20,
                          color: _isSearchExpanded ? colors.primary : colors.textSecondary,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: _isSearchExpanded ? 'Close Search' : 'Search Chats',
                        onPressed: () {
                          setState(() {
                            _isSearchExpanded = !_isSearchExpanded;
                            if (!_isSearchExpanded) {
                              _searchController.clear();
                              ref.read(historySearchQueryProvider.notifier).clear();
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_isSearchExpanded) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppTextField(
                      controller: _searchController,
                      hint: 'Search history...',
                      autofocus: true,
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(historySearchQueryProvider.notifier).clear();
                              },
                            )
                          : null,
                      onChanged: (val) {
                        ref.read(historySearchQueryProvider.notifier).setQuery(val);
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Organized Scrollable List of Chats with Section Grouping
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, _) => const EmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No chats yet',
                  description: 'Start a conversation to see your history here.',
                ),
                data: (allConversations) {
                  if (allConversations.isEmpty) {
                    return const EmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'No chats yet',
                      description: 'Start a conversation to see your history here.',
                    );
                  }

                  if (filteredConversations.isEmpty && searchQuery.isNotEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results',
                      description: 'No chats match "$searchQuery".',
                    );
                  }

                  // If search is active, show flat matching results
                  if (searchQuery.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      itemCount: filteredConversations.length,
                      itemBuilder: (context, index) {
                        final item = filteredConversations[index];
                        return ConversationListItem(
                          conversation: item,
                          isSelected: item.id == activeId,
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onSelectConversation(item.id);
                          },
                          onDelete: () => _handleDelete(item),
                          onRename: () => _showRenameSheet(item),
                        );
                      },
                    );
                  }

                  // Otherwise show cleanly arranged date-grouped history
                  final grouped = _groupConversations(filteredConversations);

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSpacing.sm,
                            bottom: AppSpacing.xs,
                            left: AppSpacing.xs,
                          ),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: AppTextStyles.micro.copyWith(
                              color: colors.textSecondary.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        for (final item in entry.value)
                          ConversationListItem(
                            conversation: item,
                            isSelected: item.id == activeId,
                            onTap: () {
                              Navigator.of(context).pop();
                              widget.onSelectConversation(item.id);
                            },
                            onDelete: () => _handleDelete(item),
                            onRename: () => _showRenameSheet(item),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),

            // Bottom Footer: User Profile, Subscription Status & Settings
            Container(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                context.bottomPadding > 0 ? context.bottomPadding : AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                  top: BorderSide(
                    color: colors.border.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Tile
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        if (isAuthenticated) {
                          context.push(AppRoutes.profilePath);
                        } else {
                          context.go(AppRoutes.authPath);
                        }
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs + 2,
                        ),
                        child: Row(
                          children: [
                            AppAvatar(name: userName, size: 36),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAuthenticated ? userName : 'Not Signed In',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    isAuthenticated ? userEmail : 'Tap to sign in',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.micro.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Divider(
                    color: colors.border.withValues(alpha: 0.5),
                    height: 1,
                  ),

                  // Bottom Utilities: Subscription Badge
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.subscriptionPath);
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 16, color: colors.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                planDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (hasActiveSub ? colors.success : colors.primary)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                hasActiveSub ? 'ACTIVE' : 'UPGRADE',
                                style: AppTextStyles.micro.copyWith(
                                  color: hasActiveSub ? colors.success : colors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
