import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot/data/datasources/mock_chat_datasource.dart';

void main() {
  group('MockChatDatasource Tests', () {
    late MockChatDatasource datasource;

    setUp(() {
      datasource = MockChatDatasource();
    });

    test('streamReply streams tokens and echoes prompt context', () async {
      final stream = datasource.streamReply('Flutter Architecture');
      final List<String> receivedTokens = [];

      await for (final token in stream) {
        receivedTokens.add(token);
      }

      final fullResponse = receivedTokens.join();
      expect(receivedTokens.isNotEmpty, isTrue);
      expect(fullResponse, contains('Flutter Architecture'));
    });

    test('stopGeneration cancels ongoing token stream', () async {
      final stream = datasource.streamReply('Long running query');
      final List<String> receivedTokens = [];

      // Collect initial token then stop
      await for (final token in stream) {
        receivedTokens.add(token);
        datasource.stopGeneration();
        break;
      }

      expect(receivedTokens.length, 1);
    });
  });
}
