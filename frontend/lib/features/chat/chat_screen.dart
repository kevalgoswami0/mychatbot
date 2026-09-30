import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/error_state.dart';
import '../../data/models/conversation.dart';
import '../../data/models/subscription_plan.dart';
import '../history/providers/history_provider.dart';
import '../subscription/providers/subscription_provider.dart';
import 'providers/chat_providers.dart';
import 'widgets/chat_input_field.dart';
import 'widgets/chat_menu_drawer.dart';
import 'widgets/message_bubble.dart';
import 'widgets/scroll_to_bottom_button.dart';
import 'widgets/suggested_prompts.dart';

/// Highly optimized, dynamic Chat screen.
/// Features live active chat title, Groq LLaMA model indicator, quick new chat action,
/// top-right history drawer, and fluid letter-by-letter streaming.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.conversationId});

  final String? conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize or restore active conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initActiveConversation();
    });
  }

  void _initActiveConversation() {
    if (widget.conversationId != null) {
      ref.read(activeConversationIdProvider.notifier).setActiveId(widget.conversationId);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow = _scrollController.offset > 200;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _ensureActiveConversation([String? prompt]) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId != null && activeId.isNotEmpty) {
      return;
    }
    String initialTitle = 'New Chat';
    if (prompt != null && prompt.trim().isNotEmpty) {
      final clean = prompt.trim();
      initialTitle = clean.length > 30 ? '${clean.substring(0, 30)}...' : clean;
    }
    try {
      final newConv = await ref.read(conversationsProvider.notifier).createConversation(initialTitle: initialTitle);
      ref.read(activeConversationIdProvider.notifier).setActiveId(newConv.id);
    } catch (_) {
      final now = DateTime.now();
      final localConv = Conversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: initialTitle,
        createdAt: now,
        updatedAt: now,
      );
      ref.read(activeConversationIdProvider.notifier).setActiveId(localConv.id);
    }
  }

  Future<void> _handleSendMessage(String text) async {
    final userSub = ref.read(userSubscriptionProvider).value;
    if (userSub != null && !userSub.hasSubscription && userSub.limitReached) {
      context.push(AppRoutes.subscriptionPath);
      return;
    }
    await _ensureActiveConversation(text);
    _scrollToBottom();
    await ref.read(messagesProvider.notifier).sendMessage(text);
    ref.read(userSubscriptionProvider.notifier).refresh();
  }

  Future<void> _handleStopGeneration() async {
    await ref.read(messagesProvider.notifier).stopGeneration();
  }

  void _handleNewChat() {
    context.hideKeyboard();
    ref.read(activeConversationIdProvider.notifier).setActiveId(null);
    ref.read(messagesProvider.notifier).resetToEmpty();
  }

  void _handleSelectConversation(String id) {
    ref.read(activeConversationIdProvider.notifier).setActiveId(id);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isGenerating = ref.watch(isGeneratingProvider);
    final activeId = ref.watch(activeConversationIdProvider);
    final conversations = ref.watch(conversationsProvider).value ?? [];
    final activeConv = conversations.where((c) => c.id == activeId).firstOrNull;
    final activeTitle = activeConv?.title ?? 'Nova Chat';

    final userSub = ref.watch(userSubscriptionProvider).value;
    final isSubscribed = userSub?.hasSubscription == true;
    final isLimitReached = !isSubscribed && (userSub?.limitReached == true);
    final activePlanName = userSub?.planName ?? 'Free';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.background,
      endDrawerEnableOpenDragGesture: true,
      endDrawer: ChatMenuDrawer(
        onSelectConversation: _handleSelectConversation,
        onNewChat: _handleNewChat,
      ),
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: AppSpacing.md,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                activeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _SubscriptionPlanDropdown(
              activePlanName: activePlanName,
              onOpenPlans: () => context.push(AppRoutes.subscriptionPath),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.menu_rounded,
              size: 24,
              color: colors.textPrimary,
            ),
            tooltip: 'Menu & History',
            onPressed: () {
              context.hideKeyboard();
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => context.hideKeyboard(),
          behavior: HitTestBehavior.translucent,
          child: Column(
            children: [
              // Message List Area
              Expanded(
                child: Stack(
                  children: [
                    if (activeId == null)
                      SuggestedPrompts(
                        onPromptSelected: _handleSendMessage,
                      )
                    else
                      _buildMessageList(),

                    // Scroll to bottom button
                    Positioned(
                      bottom: AppSpacing.md,
                      right: AppSpacing.md,
                      child: ScrollToBottomButton(
                        visible: _showScrollToBottom,
                        onPressed: _scrollToBottom,
                      ),
                    ),
                  ],
                ),
              ),

              _buildLimitBanner(context, isLimitReached),

              // Chat Input Bar
              ChatInputField(
                isGenerating: isGenerating,
                enabled: !isLimitReached,
                disabledHint: 'Daily limit reached (10 min/day). Tap to upgrade.',
                onDisabledTap: () => context.push(AppRoutes.subscriptionPath),
                onSend: _handleSendMessage,
                onStop: _handleStopGeneration,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitBanner(BuildContext context, bool isLimitReached) {
    final colors = context.appColors;
    final messages = ref.watch(messagesProvider).value ?? [];
    final hasLimitError = messages.any((m) =>
        m.isFailed &&
        m.errorMessage != null &&
        (m.errorMessage!.toLowerCase().contains('limit') ||
            m.errorMessage!.toLowerCase().contains('subscribe') ||
            m.errorMessage!.toLowerCase().contains('upgrade')));

    if (!isLimitReached && !hasLimitError) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs + 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        border: Border(top: BorderSide(color: colors.primary.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Free chat limit reached (10 min/day). Upgrade for unlimited access.',
              style: AppTextStyles.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: 4),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            ),
            onPressed: () => context.push(AppRoutes.subscriptionPath),
            child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    final messagesAsync = ref.watch(messagesProvider);
    final messages = messagesAsync.value ?? [];

    if (messages.isEmpty) {
      if (messagesAsync.isLoading) {
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }

      if (messagesAsync.hasError && !messagesAsync.hasValue) {
        return ErrorState(
          title: 'Could not load chat',
          message: 'Unable to load conversation messages. Tap retry to reconnect.',
          onRetry: () => ref.invalidate(messagesProvider),
        );
      }

      return SuggestedPrompts(
        onPromptSelected: _handleSendMessage,
      );
    }

    // Reversed list for natural chat bottom-up layout
    final reversedMessages = messages.reversed.toList(growable: false);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      itemCount: reversedMessages.length,
      findChildIndexCallback: (Key key) {
        if (key is ValueKey<String>) {
          for (int i = 0; i < reversedMessages.length; i++) {
            if (reversedMessages[i].id == key.value) return i;
          }
        }
        return null;
      },
      itemBuilder: (context, index) {
        final message = reversedMessages[index];

        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          onDelete: () {
            ref.read(messagesProvider.notifier).deleteMessage(message.id);
          },
          onRegenerate: () {
            ref.read(messagesProvider.notifier).regenerateMessage(message.id);
          },
          onRetry: () {
            ref.read(messagesProvider.notifier).retryMessage(message.id);
          },
          onEditPrompt: (newPrompt) {
            ref.read(messagesProvider.notifier).editUserMessageAndRegenerate(message.id, newPrompt);
          },
        );
      },
    );
  }
}

/// Dropdown pill in the AppBar for viewing and switching subscription plan.
class _SubscriptionPlanDropdown extends StatelessWidget {
  const _SubscriptionPlanDropdown({
    required this.activePlanName,
    required this.onOpenPlans,
  });

  final String activePlanName;
  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isPaid = activePlanName.toLowerCase() != 'free';

    return PopupMenuButton<String>(
      tooltip: 'Subscription Tier',
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: BorderSide(color: colors.border, width: 1),
      ),
      color: colors.background,
      elevation: 2,
      onSelected: (value) {
        onOpenPlans();
      },
      itemBuilder: (context) => [
        ...SubscriptionPlan.defaultPlans.map(
          (plan) {
            final isCurrent = plan.name.toLowerCase() == activePlanName.toLowerCase();
            return PopupMenuItem<String>(
              value: plan.id,
              child: Row(
                children: [
                  Icon(
                    isCurrent
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 16,
                    color: isCurrent ? colors.primary : colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    plan.formattedPrice,
                    style: AppTextStyles.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'view_all',
          child: Row(
            children: [
              Icon(Icons.workspace_premium_rounded, size: 18, color: colors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'View All Plans & Features',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isPaid ? colors.primary.withValues(alpha: 0.12) : colors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isPaid ? colors.primary : colors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPaid) ...[
              Icon(Icons.auto_awesome_rounded, size: 12, color: colors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              activePlanName,
              style: AppTextStyles.caption.copyWith(
                color: isPaid ? colors.primary : colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isPaid ? colors.primary : colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
