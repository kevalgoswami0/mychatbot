import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/conversation.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../chat/providers/chat_providers.dart';

/// Provider holding the currently active conversation ID.
class ActiveConversationIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setActiveId(String? id) {
    state = id;
  }
}

final activeConversationIdProvider =
    NotifierProvider<ActiveConversationIdNotifier, String?>(
  ActiveConversationIdNotifier.new,
);

/// Provider holding the search query filter string on the History screen.
class HistorySearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final historySearchQueryProvider =
    NotifierProvider<HistorySearchQueryNotifier, String>(
  HistorySearchQueryNotifier.new,
);

/// Notifier managing the list of all conversations.
class ConversationsNotifier extends AsyncNotifier<List<Conversation>> {
  late final ChatRepository _chatRepository;

  @override
  Future<List<Conversation>> build() async {
    _chatRepository = ref.watch(chatRepositoryProvider);
    return _chatRepository.getConversations();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _chatRepository.getConversations());
  }

  Future<Conversation> createConversation({String? initialTitle}) async {
    final newConv = await _chatRepository.createConversation(initialTitle: initialTitle);
    final currentList = state.value ?? [];
    state = AsyncData([newConv, ...currentList.where((c) => c.id != newConv.id)]);
    ref.read(activeConversationIdProvider.notifier).setActiveId(newConv.id);
    ref.read(messagesProvider.notifier).resetToEmpty();
    return newConv;
  }

  Future<void> deleteConversation(String id) async {
    final previousList = state.value ?? [];
    // Optimistic update
    state = AsyncData(previousList.where((c) => c.id != id).toList());

    try {
      await _chatRepository.deleteConversation(id);
      if (ref.read(activeConversationIdProvider) == id) {
        final remaining = state.value ?? [];
        ref.read(activeConversationIdProvider.notifier).setActiveId(
          remaining.isNotEmpty ? remaining.first.id : null,
        );
      }
    } catch (e) {
      // Revert if error
      state = AsyncData(previousList);
      rethrow;
    }
  }

  Future<void> restoreConversation(Conversation conversation) async {
    final currentList = state.value ?? [];
    state = AsyncData([conversation, ...currentList]);
    await _chatRepository.renameConversation(conversation.id, conversation.title);
  }

  Future<void> renameConversation(String id, String newTitle) async {
    final currentList = state.value ?? [];
    state = AsyncData(
      currentList.map((c) {
        if (c.id == id) {
          return c.copyWith(title: newTitle, updatedAt: DateTime.now());
        }
        return c;
      }).toList(),
    );
    await _chatRepository.renameConversation(id, newTitle);
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    ref.read(activeConversationIdProvider.notifier).setActiveId(null);
    await _chatRepository.clearAllConversations();
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<Conversation>>(
  ConversationsNotifier.new,
);

/// Filtered conversations based on search input.
final filteredConversationsProvider = Provider<List<Conversation>>((ref) {
  final conversationsAsync = ref.watch(conversationsProvider);
  final query = ref.watch(historySearchQueryProvider).trim().toLowerCase();

  final list = conversationsAsync.value ?? [];
  if (query.isEmpty) return list;

  return list.where((c) {
    final titleMatch = c.title.toLowerCase().contains(query);
    final lastMsgMatch = c.lastMessage?.toLowerCase().contains(query) ?? false;
    return titleMatch || lastMsgMatch;
  }).toList();
});
