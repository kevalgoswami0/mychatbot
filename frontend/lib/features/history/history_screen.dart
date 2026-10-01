import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/conversation.dart';
import 'providers/history_provider.dart';
import 'widgets/conversation_list_item.dart';
import 'widgets/rename_dialog.dart';

/// Conversation history screen with real-time search, swipe-to-delete with undo, and rename modal.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openConversation(String id) {
    ref.read(activeConversationIdProvider.notifier).setActiveId(id);
    context.go('${AppRoutes.chatPath}?id=$id');
  }

  void _handleNewChat() {
    ref.read(activeConversationIdProvider.notifier).setActiveId(null);
    context.go(AppRoutes.chatPath);
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
    final activeId = ref.watch(activeConversationIdProvider);
    final conversationsAsync = ref.watch(conversationsProvider);
    final filteredConversations = ref.watch(filteredConversationsProvider);
    final searchQuery = ref.watch(historySearchQueryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'History',
          style: AppTextStyles.titleLarge.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: AppTextField(
                controller: _searchController,
                hint: 'Search conversations...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: colors.textSecondary,
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
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
            ),

            // Conversation List or States
            Expanded(
              child: conversationsAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, _) => EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No conversations yet',
                  description: 'Start a new conversation to begin chatting with Nova Chat.',
                  actionText: 'Start New Chat',
                  onAction: _handleNewChat,
                ),
                data: (allConversations) {
                  if (allConversations.isEmpty) {
                    return EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No conversations yet',
                      description: 'Start a new conversation to begin chatting with Nova Chat.',
                      actionText: 'Start New Chat',
                      onAction: _handleNewChat,
                    );
                  }

                  if (filteredConversations.isEmpty && searchQuery.isNotEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results found',
                      description: 'No conversations match "$searchQuery". Try another keyword.',
                    );
                  }

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
                        onTap: () => _openConversation(item.id),
                        onDelete: () => _handleDelete(item),
                        onRename: () => _showRenameSheet(item),
                      );
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
