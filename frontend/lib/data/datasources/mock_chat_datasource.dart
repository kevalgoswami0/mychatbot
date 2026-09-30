import 'dart:async';
import 'dart:math';
import '../../core/config/api_config.dart';
import '../../core/utils/logger.dart';

/// Dynamic mock data source simulating a real LLM backend streaming response.
class MockChatDatasource {
  final Random _random = Random();
  bool _isCancelled = false;

  /// Dynamic templates for AI responses.
  /// Includes markdown formatting, code blocks, lists, and contextual echoing.
  final List<String Function(String query)> _responseTemplates = [
    (q) =>
        'I understand you are asking about **"$q"**.\n\nHere is a structured overview:\n\n'
        '1. **Core Concept**: Analyzing key components related to your inquiry.\n'
        '2. **Practical Application**: Implementing modular and reliable strategies.\n'
        '3. **Key Benefit**: Maximizes performance with zero visual clutter.\n\n'
        'Let me know if you would like me to dive deeper into any of these areas!',

    (q) =>
        'Certainly! Here is an efficient implementation tailored for **"$q"**:\n\n'
        '```dart\n'
        '// Streamlined high-performance function\n'
        'Future<void> executeTask() async {\n'
        '  final result = await processData("$q");\n'
        '  print("Processed successfully: \$result");\n'
        '}\n'
        '```\n\n'
        'This pattern ensures clean separation of concerns and immediate responsiveness.',

    (q) =>
        'Great question regarding **"$q"**!\n\n'
        'Here are three primary recommendations to consider:\n\n'
        '- **Simplicity first**: Keep interfaces clean and state predictable.\n'
        '- **Responsive execution**: Optimize token rendering and network calls.\n'
        '- **Graceful degradation**: Always handle loading, empty, and error boundaries.\n\n'
        'Would you like a concrete example or further details on this?',

    (q) =>
        'Regarding **"$q"**:\n\n'
        'In production architectures, this is handled through decoupled layers:\n\n'
        '| Layer | Responsibility | Status |\n'
        '| :--- | :--- | :--- |\n'
        '| **UI** | Material 3 widgets | Ready |\n'
        '| **Domain** | Business contracts | Verified |\n'
        '| **Data** | Dynamic Mock / Live API | Swappable |\n\n'
        'Feel free to ask for specific refinements or adjustments!',

    (q) =>
        'I have analyzed **"$q"**.\n\n'
        'Everything is set up following modern design principles: flat surfaces, 1px subtle borders, no gradients, and high contrast typography. If you have follow-up questions or want to explore variations, just tell me!',
  ];

  /// Stop any active generation stream.
  void stopGeneration() {
    AppLogger.info('Stopping mock streaming generation');
    _isCancelled = true;
  }

  /// Streams tokens word-by-word with initial latency simulation and cancel support.
  // TODO(backend): In production, replace this with an SSE (Server-Sent Events) or WebSocket client:
  // e.g. using `http.Request` with `client.send(request)` or `web_socket_channel`.
  Stream<String> streamReply(String userMessage) async* {
    _isCancelled = false;

    // 1. Simulate network latency (400-1100ms)
    final latency = _random.nextInt(ApiConfig.mockLatencyMaxMs - ApiConfig.mockLatencyMinMs) +
        ApiConfig.mockLatencyMinMs;
    await Future.delayed(Duration(milliseconds: latency));

    if (_isCancelled) return;

    // 2. Select response template and inject user query
    final cleanQuery = userMessage.trim().isEmpty ? 'your question' : userMessage.trim();
    final template = _responseTemplates[_random.nextInt(_responseTemplates.length)];
    final fullResponse = template(cleanQuery);

    // 3. Tokenize by words and spaces
    final tokens = _tokenize(fullResponse);

    // 4. Stream tokens sequentially
    for (final token in tokens) {
      if (_isCancelled) {
        AppLogger.info('Stream generation aborted by user request');
        break;
      }
      yield token;
      await Future.delayed(const Duration(milliseconds: ApiConfig.mockTokenIntervalMs));
    }
  }

  /// Split string into individual tokens while preserving formatting
  List<String> _tokenize(String text) {
    final List<String> tokens = [];
    final pattern = RegExp(r'(\s+|[^\s]+)');
    for (final match in pattern.allMatches(text)) {
      tokens.add(match.group(0)!);
    }
    return tokens;
  }
}
