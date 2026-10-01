import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/logger.dart';
import '../../../data/models/message.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../history/providers/history_provider.dart';
import '../../subscription/providers/subscription_provider.dart';

/// Provider tracking whether the AI is currently streaming a response.
class IsGeneratingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setGenerating(bool value) => state = value;
}

final isGeneratingProvider = NotifierProvider<IsGeneratingNotifier, bool>(
  IsGeneratingNotifier.new,
);

/// Provider tracking messages for the currently active conversation.
class MessagesNotifier extends AsyncNotifier<List<Message>> {
  static const _uuid = Uuid();
  late final ChatRepository _chatRepository;
  StreamSubscription<String>? _streamSub;
  Throttler? _uiThrottler;

  @override
  Future<List<Message>> build() async {
    _chatRepository = ref.watch(chatRepositoryProvider);
    _uiThrottler = Throttler(duration: const Duration(milliseconds: 16));

    ref.onDispose(() {
      _streamSub?.cancel();
      _uiThrottler?.dispose();
    });

    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null || activeId.isEmpty) {
      return const [];
    }

    try {
      return await _chatRepository.getMessages(activeId);
    } catch (e, st) {
      AppLogger.warning('Failed to load messages for conversation $activeId: $e', stackTrace: st);
      return const [];
    }
  }

  /// Instantly resets message state to empty list for new chat creation
  void resetToEmpty() {
    _streamSub?.cancel();
    _streamSub = null;
    ref.read(isGeneratingProvider.notifier).setGenerating(false);
    state = const AsyncData([]);
  }

  /// When user upgrades, update any limit-exceeded failure messages so they are ready for retry
  void markLimitErrorsReady() {
    final current = state.value ?? [];
    bool changed = false;
    final updated = current.map((m) {
      if (m.isFailed && m.errorMessage != null) {
        final err = m.errorMessage!.toLowerCase();
        if (err.contains('limit') ||
            err.contains('2 min') ||
            err.contains('10 min') ||
            err.contains('upgrade')) {
          changed = true;
          return m.copyWith(errorMessage: 'Subscription active. Tap Retry to send.');
        }
      }
      return m;
    }).toList();

    if (changed) {
      state = AsyncData(updated);
      final activeId = ref.read(activeConversationIdProvider);
      if (activeId != null && activeId.isNotEmpty) {
        _chatRepository.saveMessages(activeId, updated);
      }
    }
  }

  /// Alias for backward compatibility
  void clearLimitErrors() => markLimitErrorsReady();

  /// Explicitly load a conversation's messages and switch state
  Future<void> loadConversation(String id) async {
    _streamSub?.cancel();
    _streamSub = null;
    ref.read(isGeneratingProvider.notifier).setGenerating(false);
    state = const AsyncLoading();
    try {
      final messages = await _chatRepository.getMessages(id);
      state = AsyncData(messages);
    } catch (e, st) {
      AppLogger.warning('Failed to load messages for conversation $id: $e', stackTrace: st);
      state = const AsyncData([]);
    }
  }

  /// Edit a user's prompt, truncate following messages, and regenerate the bot's response.
  Future<void> editUserMessageAndRegenerate(String messageId, String newText) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null || newText.trim().isEmpty) return;

    await _streamSub?.cancel();
    _streamSub = null;

    List<Message> currentMessages = [];
    if (state.hasValue && state.value != null) {
      currentMessages = List<Message>.from(state.value!);
    } else {
      currentMessages = await _chatRepository.getMessages(activeId);
    }

    final targetIndex = currentMessages.indexWhere((m) => m.id == messageId);
    if (targetIndex == -1) {
      await sendMessage(newText);
      return;
    }

    // Keep messages strictly before the edited prompt
    final keptMessages = currentMessages.sublist(0, targetIndex);
    await _chatRepository.saveMessages(activeId, keptMessages);
    state = AsyncData(keptMessages);

    // Send the updated prompt
    await sendMessage(newText.trim());
  }

  /// Send user message and begin token-by-token streaming.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    var activeId = ref.read(activeConversationIdProvider);

    // If starting from a new chat, create the conversation entity
    if (activeId == null || activeId.isEmpty) {
      final clean = text.trim();
      final initialTitle = clean.length > 30 ? '${clean.substring(0, 30)}...' : clean;
      try {
        final newConv = await _chatRepository.createConversation(initialTitle: initialTitle);
        activeId = newConv.id;
        ref.read(activeConversationIdProvider.notifier).state = activeId;
        ref.read(conversationsProvider.notifier).reload();
      } catch (_) {
        activeId = DateTime.now().millisecondsSinceEpoch.toString();
        ref.read(activeConversationIdProvider.notifier).state = activeId;
      }
    }

    ref.read(isGeneratingProvider.notifier).setGenerating(true);

    try {
      // 1. Retrieve current message list (from state or repository)
      List<Message> currentMessages = [];
      if (state.hasValue && state.value != null) {
        currentMessages = List<Message>.from(state.value!);
      } else {
        currentMessages = await _chatRepository.getMessages(activeId);
      }

      // Finalize any previously streaming message if present
      for (int i = 0; i < currentMessages.length; i++) {
        if (currentMessages[i].isStreaming) {
          currentMessages[i] = currentMessages[i].copyWith(status: MessageStatus.sent);
        }
      }

      // 2. Generate matching UUIDs for user and assistant messages
      final now = DateTime.now();
      final userMessageId = _uuid.v4();
      final assistantMessageId = _uuid.v4();

      final userMessage = Message(
        id: userMessageId,
        conversationId: activeId,
        role: MessageRole.user,
        content: text.trim(),
        createdAt: now,
        status: MessageStatus.sent,
      );

      final assistantPlaceholder = Message(
        id: assistantMessageId,
        conversationId: activeId,
        role: MessageRole.assistant,
        content: '',
        createdAt: now.add(const Duration(milliseconds: 1)),
        status: MessageStatus.streaming,
      );

      // 3. IMMEDIATELY update UI state so user message and typing bubble appear with 0ms delay
      state = AsyncData([...currentMessages, userMessage, assistantPlaceholder]);

      // 4. Start repository stream passing the exact same IDs
      final stream = _chatRepository.sendMessage(
        activeId,
        text,
        userMessageId: userMessageId,
        assistantMessageId: assistantMessageId,
      );
      final StringBuffer streamedBuffer = StringBuffer();

      _streamSub?.cancel();
      _streamSub = stream.listen(
        (token) {
          streamedBuffer.write(token);

          // Throttle UI state updates to maintain fluid 60/120fps
          _uiThrottler?.run(() {
            _updateMessageById(
              assistantMessageId,
              streamedBuffer.toString(),
              MessageStatus.streaming,
            );
          });
        },
        onError: (err) {
          AppLogger.error('Stream error encountered', error: err);
          final errStr = err.toString().toLowerCase();
          final isLimit = errStr.contains('free chat limit') ||
              errStr.contains('daily limit') ||
              errStr.contains('limit_exceeded') ||
              errStr.contains('2 min/day') ||
              errStr.contains('10 min/day') ||
              errStr.contains('upgrade for unlimited');
          _updateMessageById(
            assistantMessageId,
            streamedBuffer.toString(),
            MessageStatus.failed,
            errorMessage: isLimit
                ? 'Daily limit reached. Upgrade to continue.'
                : 'Unable to get response. Tap Retry.',
          );
          ref.read(isGeneratingProvider.notifier).setGenerating(false);
          ref.read(conversationsProvider.notifier).reload();
          if (isLimit) {
            ref.read(userSubscriptionProvider.notifier).refresh();
          }
        },
        onDone: () async {
          _updateMessageById(
            assistantMessageId,
            streamedBuffer.toString(),
            MessageStatus.sent,
          );
          ref.read(isGeneratingProvider.notifier).setGenerating(false);
          ref.read(conversationsProvider.notifier).reload();

          // Ensure local state and persistent storage are strictly aligned
          if (activeId != null) {
            try {
              final persistedMessages = await _chatRepository.getMessages(activeId);
              if (persistedMessages.isNotEmpty) {
                state = AsyncData(persistedMessages);
              }
            } catch (_) {}
          }
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      AppLogger.error('Failed to initiate send message', error: e, stackTrace: st);
      ref.read(isGeneratingProvider.notifier).setGenerating(false);
    }
  }

  /// Stop the active generation stream immediately.
  Future<void> stopGeneration() async {
    await _streamSub?.cancel();
    _streamSub = null;
    await _chatRepository.stopGeneration();
    ref.read(isGeneratingProvider.notifier).setGenerating(false);

    final current = state.value ?? [];
    if (current.isNotEmpty && current.last.isStreaming) {
      final finalized = current.last.copyWith(status: MessageStatus.sent);
      final updated = List<Message>.from(current)..[current.length - 1] = finalized;
      state = AsyncData(updated);
    }
    ref.read(conversationsProvider.notifier).reload();
  }

  /// Delete a single message from the current conversation.
  Future<void> deleteMessage(String messageId) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    final current = state.value ?? [];
    state = AsyncData(current.where((m) => m.id != messageId).toList());
    await _chatRepository.deleteMessage(activeId, messageId);
    ref.read(conversationsProvider.notifier).reload();
  }

  /// Regenerate a bot response.
  Future<void> regenerateMessage(String messageId) async {
    final activeId = ref.read(activeConversationIdProvider);
    if (activeId == null) return;

    ref.read(isGeneratingProvider.notifier).setGenerating(true);
    _updateMessageById(messageId, '', MessageStatus.streaming, errorMessage: null);

    try {
      final stream = _chatRepository.regenerateMessage(activeId, messageId);
      final StringBuffer streamedBuffer = StringBuffer();

      _streamSub?.cancel();
      _streamSub = stream.listen(
        (token) {
          streamedBuffer.write(token);
          _uiThrottler?.run(() {
            _updateMessageById(messageId, streamedBuffer.toString(), MessageStatus.streaming);
          });
        },
        onError: (err) {
          AppLogger.error('Stream error during regenerate', error: err);
          final errStr = err.toString().toLowerCase();
          final isLimit = errStr.contains('limit') ||
              errStr.contains('2 min') ||
              errStr.contains('10 min') ||
              errStr.contains('upgrade');
          _updateMessageById(
            messageId,
            streamedBuffer.toString(),
            MessageStatus.failed,
            errorMessage: isLimit
                ? 'Daily limit reached. Upgrade to continue.'
                : 'Unable to get response. Tap Retry.',
          );
          ref.read(isGeneratingProvider.notifier).setGenerating(false);
          ref.read(conversationsProvider.notifier).reload();
          if (isLimit) {
            ref.read(userSubscriptionProvider.notifier).refresh();
          }
        },
        onDone: () {
          _updateMessageById(messageId, streamedBuffer.toString(), MessageStatus.sent);
          ref.read(isGeneratingProvider.notifier).setGenerating(false);
          ref.read(conversationsProvider.notifier).reload();
        },
      );
    } catch (e) {
      ref.read(isGeneratingProvider.notifier).setGenerating(false);
    }
  }

  /// Retry sending a failed message
  Future<void> retryMessage(String messageId) async {
    final current = state.value ?? [];
    final idx = current.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final targetMessage = current[idx];
    if (targetMessage.isAssistant) {
      await regenerateMessage(messageId);
    } else {
      // It's a user message, re-trigger sendMessage
      await deleteMessage(messageId);
      await sendMessage(targetMessage.content);
    }
  }

  void _updateMessageById(
    String id,
    String content,
    MessageStatus status, {
    String? errorMessage,
  }) {
    final current = state.value ?? [];
    final idx = current.indexWhere((m) => m.id == id);
    if (idx == -1) return;

    final updated = current[idx].copyWith(
      content: content,
      status: status,
      errorMessage: errorMessage,
    );
    final newList = List<Message>.from(current)..[idx] = updated;
    state = AsyncData(newList);
  }
}

final messagesProvider = AsyncNotifierProvider<MessagesNotifier, List<Message>>(
  MessagesNotifier.new,
);
