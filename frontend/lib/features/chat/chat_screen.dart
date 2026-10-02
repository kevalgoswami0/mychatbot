import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/text_styles.dart';
import '../../core/utils/extensions.dart';
import '../../core/widgets/error_state.dart';
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
  bool _isLimitDialogShowing = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Initialize or restore active conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initActiveConversation();
    });
  }

  void _showLimitReachedDialog() {
    if (_isLimitDialogShowing || !mounted) return;
    _isLimitDialogShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.workspace_premium_rounded, color: colors.primary, size: 28),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Daily Limit Reached',
                style: AppTextStyles.titleMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You\'ve used today\'s 2-minute free limit. Upgrade to continue chatting.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _isLimitDialogShowing = false;
                    },
                    child: Text(
                      'Maybe Later',
                      style: AppTextStyles.button.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _isLimitDialogShowing = false;
                      context.push(AppRoutes.subscriptionPath).then((_) {
                        ref.read(userSubscriptionProvider.notifier).refresh();
                      });
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: const Text(
                      'Upgrade',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ).then((_) => _isLimitDialogShowing = false);
  }

  void _initActiveConversation() {
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      ref.read(activeConversationIdProvider.notifier).setActiveId(widget.conversationId);
    } else {
      ref.read(activeConversationIdProvider.notifier).setActiveId(null);
      ref.read(messagesProvider.notifier).resetToEmpty();
    }
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId) {
      if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
        ref.read(activeConversationIdProvider.notifier).setActiveId(widget.conversationId);
      } else {
        ref.read(activeConversationIdProvider.notifier).setActiveId(null);
        ref.read(messagesProvider.notifier).resetToEmpty();
      }
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

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userSub = ref.read(userSubscriptionProvider).value;
    final isSubscribed = userSub != null && (userSub.hasSubscription || userSub.isSubscribedAndValid);
    final isLimitReached = !isSubscribed && (userSub?.limitReached == true);
    if (isLimitReached) {
      _showLimitReachedDialog();
      return;
    }

    _scrollToBottom();
    await ref.read(messagesProvider.notifier).sendMessage(text);
    ref.read(userSubscriptionProvider.notifier).refresh();
  }

  Future<void> _handleStopGeneration() async {
    await ref.read(messagesProvider.notifier).stopGeneration();
  }

  void _handleOpenVoiceCall() {
    context.hideKeyboard();
    final userSub = ref.read(userSubscriptionProvider).value;
    final isSubscribed = userSub != null &&
        (userSub.hasSubscription || userSub.isSubscribedAndValid);
    final isLimitReached = !isSubscribed && (userSub?.limitReached == true);
    if (isLimitReached) {
      _showLimitReachedDialog();
      return;
    }

    final activeId = ref.read(activeConversationIdProvider);
    final route = activeId != null && activeId.isNotEmpty
        ? '${AppRoutes.liveVoicePath}?id=$activeId'
        : AppRoutes.liveVoicePath;

    context.push(route).then((_) {
      final currentActiveId = ref.read(activeConversationIdProvider);
      if (currentActiveId != null && currentActiveId.isNotEmpty) {
        ref.read(messagesProvider.notifier).loadConversation(currentActiveId);
      }
      ref.read(conversationsProvider.notifier).reload();
      ref.read(userSubscriptionProvider.notifier).refresh();
    });
  }

  void _handleNewChat() {
    context.hideKeyboard();
    ref.read(activeConversationIdProvider.notifier).setActiveId(null);
    if (widget.conversationId != null) {
      context.go(AppRoutes.chatPath);
    }
  }

  void _handleSelectConversation(String id) {
    context.hideKeyboard();
    ref.read(activeConversationIdProvider.notifier).setActiveId(id);
    if (widget.conversationId != id) {
      context.go('${AppRoutes.chatPath}?id=$id');
    }
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
    final isSubscribed = userSub != null && (userSub.hasSubscription || userSub.isSubscribedAndValid);
    final messages = ref.watch(messagesProvider).value ?? [];
    final hasLimitError = messages.any((m) =>
        m.isFailed &&
        m.errorMessage != null &&
        (m.errorMessage!.toLowerCase().contains('free chat limit') ||
            m.errorMessage!.toLowerCase().contains('daily limit') ||
            m.errorMessage!.toLowerCase().contains('limit_exceeded') ||
            m.errorMessage!.toLowerCase().contains('2 min/day') ||
            m.errorMessage!.toLowerCase().contains('10 min/day')));
    final isLimitReached = !isSubscribed && ((userSub?.limitReached == true) || hasLimitError);
    final activePlanName = userSub?.planName ?? 'Free';

    ref.listen(userSubscriptionProvider, (previous, next) {
      final sub = next.value;
      if (sub != null && (sub.hasSubscription || sub.isSubscribedAndValid)) {
        ref.read(messagesProvider.notifier).markLimitErrorsReady();
      } else if (sub != null && !sub.hasSubscription && sub.limitReached) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLimitReachedDialog();
        });
      }
    });

    ref.listen(messagesProvider, (previous, next) {
      final msgs = next.value ?? [];
      final hasFailLimit = msgs.isNotEmpty &&
          msgs.last.isFailed &&
          msgs.last.errorMessage != null &&
          (msgs.last.errorMessage!.toLowerCase().contains('free chat limit') ||
              msgs.last.errorMessage!.toLowerCase().contains('daily limit') ||
              msgs.last.errorMessage!.toLowerCase().contains('limit_exceeded') ||
              msgs.last.errorMessage!.toLowerCase().contains('2 min/day') ||
              msgs.last.errorMessage!.toLowerCase().contains('10 min/day'));
      if (hasFailLimit && !isSubscribed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showLimitReachedDialog();
        });
      }
    });

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
        title: Text(
          activeTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.titleMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Center(
            child: _SubscriptionPlanDropdown(
              activePlanName: activePlanName,
              onOpenPlans: () => context.push(AppRoutes.subscriptionPath),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.menu_open_rounded,
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
                disabledHint: 'Daily limit reached. Tap to upgrade.',
                onDisabledTap: _showLimitReachedDialog,
                onSend: _handleSendMessage,
                onStop: _handleStopGeneration,
                onVoiceTap: _handleOpenVoiceCall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLimitBanner(BuildContext context, bool isLimitReached) {
    final colors = context.appColors;
    if (!isLimitReached) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.primary.withValues(alpha: 0.25)),
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.workspace_premium_rounded, size: 16, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Daily limit reached (2 min). Upgrade for unlimited chat.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4, vertical: 5),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusSm)),
            ),
            onPressed: _showLimitReachedDialog,
            child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
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
            final userSub = ref.read(userSubscriptionProvider).value;
            final isSubscribed = userSub != null && (userSub.hasSubscription || userSub.isSubscribedAndValid);
            final isLimitReached = !isSubscribed && (userSub?.limitReached == true);
            if (isLimitReached) {
              _showLimitReachedDialog();
            } else {
              ref.read(messagesProvider.notifier).retryMessage(message.id);
            }
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
      tooltip: 'Subscription Plans',
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
      ),
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      onSelected: (value) {
        onOpenPlans();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Text(
            'SUBSCRIPTION TIER',
            style: AppTextStyles.micro.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...SubscriptionPlan.defaultPlans.map(
          (plan) {
            final isCurrent = plan.name.toLowerCase() == activePlanName.toLowerCase();
            return PopupMenuItem<String>(
              value: plan.id,
              child: Row(
                children: [
                  Icon(
                    isCurrent
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isCurrent ? colors.primary : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? colors.primary : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? colors.primary.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: isCurrent
                            ? colors.primary.withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      plan.formattedPrice,
                      style: AppTextStyles.micro.copyWith(
                        color: isCurrent ? colors.primary : const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
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
              Expanded(
                child: Text(
                  'Manage & Upgrade Plans',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: colors.primary),
            ],
          ),
        ),
      ],
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isPaid ? colors.primary.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPaid ? Icons.auto_awesome_rounded : Icons.bolt_rounded,
              size: 13,
              color: isPaid ? colors.primary : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Text(
              activePlanName,
              style: AppTextStyles.caption.copyWith(
                color: isPaid ? colors.primary : const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isPaid ? colors.primary : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
