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

    final userName = user?.name ?? 'Guest User';
    final userEmail = user?.email ?? 'guest@novachat.ai';

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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Menu',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border, height: 1),

            // Top Buttons Section (Profile and New Chat)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Button 1: Profile Button
                  Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      side: BorderSide(color: colors.border, width: 1),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.profilePath);
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm + 2),
                        child: Row(
                          children: [
                            AppAvatar(name: userName, size: 36),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    userEmail,
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
                              size: 20,
                              color: colors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Button 2: New Chat Button
                  AppButton(
                    text: 'New Chat',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onNewChat();
                    },
                  ),
                ],
              ),
            ),

            // History Section Header with prominent CHATS label & Search toggle icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CHATS',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.6,
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
                error: (err, _) => Center(
                  child: Text(
                    'Failed to load history',
                    style: AppTextStyles.caption.copyWith(color: colors.error),
                  ),
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

            // Bottom Utility Links (Subscriptions & Settings)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border, width: 1)),
              ),
              child: Row(
                children: [
                  // Subscription pill button
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(AppRoutes.subscriptionPath);
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 18, color: colors.primary),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                currentPlan.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.caption.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Settings icon button
                  IconButton(
                    icon: Icon(Icons.settings_outlined, size: 20, color: colors.textSecondary),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(AppRoutes.settingsPath);
                    },
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
