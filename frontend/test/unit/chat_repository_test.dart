import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chatbot/data/datasources/local_storage.dart';
import 'package:chatbot/data/repositories/chat_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatRepositoryImpl Tests', () {
    late LocalStorage storage;
    late ChatRepositoryImpl repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorage(prefs);
      repository = ChatRepositoryImpl(
        localStorage: storage,
      );
    });

    test('createConversation creates and persists new session', () async {
      final conv = await repository.createConversation(initialTitle: 'Test Chat');

      expect(conv.id, isNotEmpty);
      expect(conv.title, 'Test Chat');

      final list = await repository.getConversations();
      expect(list.length, 1);
      expect(list.first.id, conv.id);
    });

    test('renameConversation updates conversation title in storage', () async {
      final conv = await repository.createConversation(initialTitle: 'Initial');
      await repository.renameConversation(conv.id, 'Updated Title');

      final list = await repository.getConversations();
      expect(list.first.title, 'Updated Title');
    });

    test('deleteConversation removes session and messages', () async {
      final conv = await repository.createConversation(initialTitle: 'To Delete');
      expect((await repository.getConversations()).length, 1);

      await repository.deleteConversation(conv.id);
      expect((await repository.getConversations()).isEmpty, isTrue);
    });

    test('sendMessage appends user message and streams assistant tokens', () async {
      final conv = await repository.createConversation(initialTitle: 'Chat');

      final stream = repository.sendMessage(conv.id, 'What is Flutter?');
      final List<String> received = [];

      await for (final token in stream) {
        received.add(token);
      }

      expect(received.isNotEmpty, isTrue);

      final messages = await repository.getMessages(conv.id);
      expect(messages.length, 2);
      expect(messages.first.isUser, isTrue);
      expect(messages.first.content, 'What is Flutter?');
      expect(messages.last.isAssistant, isTrue);
      expect(messages.last.content, received.join());
    });

    test('sendMessage preserves custom userMessageId and assistantMessageId', () async {
      final conv = await repository.createConversation(initialTitle: 'Custom IDs Chat');

      final stream = repository.sendMessage(
        conv.id,
        'Hello World',
        userMessageId: 'custom-user-id-123',
        assistantMessageId: 'custom-assistant-id-456',
      );

      await for (final _ in stream) {}

      final messages = await repository.getMessages(conv.id);
      expect(messages.length, 2);
      expect(messages.first.id, 'custom-user-id-123');
      expect(messages.last.id, 'custom-assistant-id-456');
    });

    test('clearAllConversations wipes entire storage', () async {
      await repository.createConversation();
      await repository.createConversation();
      expect((await repository.getConversations()).length, 2);

      await repository.clearAllConversations();
      expect((await repository.getConversations()).isEmpty, isTrue);
    });
  });
}
