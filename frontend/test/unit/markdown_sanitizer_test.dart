import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot/features/chat/widgets/markdown_message_body.dart';

void main() {
  group('MarkdownMessageBody.sanitizeMarkdown Tests', () {
    test('removes trailing and dangling hashes during real-time streaming', () {
      expect(MarkdownMessageBody.sanitizeMarkdown('###'), '');
      expect(MarkdownMessageBody.sanitizeMarkdown('### '), '');
      expect(MarkdownMessageBody.sanitizeMarkdown('\n###'), '');
      expect(MarkdownMessageBody.sanitizeMarkdown('Hello\n### '), 'Hello\n');
      expect(MarkdownMessageBody.sanitizeMarkdown('Hello\n###'), 'Hello\n');
    });

    test('converts ATX headings into clean bold text without hash symbols', () {
      final input = '### Introduction to Investing\nMutual funds are great.';
      final result = MarkdownMessageBody.sanitizeMarkdown(input);
      expect(result.contains('#'), isFalse);
      expect(result.contains('**Introduction to Investing**'), isTrue);
    });

    test('converts ATX headings without space into clean bold text', () {
      final input = '###What is an Index Fund?';
      final result = MarkdownMessageBody.sanitizeMarkdown(input);
      expect(result.contains('#'), isFalse);
      expect(result.contains('**What is an Index Fund?**'), isTrue);
    });

    test('converts all levels of headers (# to ######)', () {
      final input = '# Level 1\n## Level 2\n### Level 3\n#### Level 4\n##### Level 5\n###### Level 6';
      final result = MarkdownMessageBody.sanitizeMarkdown(input);
      expect(result.contains('#'), isFalse);
      expect(result.contains('**Level 1**'), isTrue);
      expect(result.contains('**Level 2**'), isTrue);
      expect(result.contains('**Level 6**'), isTrue);
    });

    test('converts bullet items containing hash headers', () {
      final input = '- ### Diversification\n- ### Compounding';
      final result = MarkdownMessageBody.sanitizeMarkdown(input);
      expect(result.contains('#'), isFalse);
      expect(result.contains('**Diversification**'), isTrue);
      expect(result.contains('**Compounding**'), isTrue);
    });

    test('converts multiple heading lines and removes all hashes', () {
      final input = 'Key concepts:\n### 1. Compounding\n### 2. Inflation';
      final result = MarkdownMessageBody.sanitizeMarkdown(input);
      expect(result.contains('#'), isFalse);
      expect(result.contains('**1. Compounding**'), isTrue);
      expect(result.contains('**2. Inflation**'), isTrue);
    });

    test('purges stray isolated hashes in text', () {
      final input = 'Here are tips ### for investing.';
      final result = MarkdownMessageBody.sanitizeMarkdown(input);
      expect(result.contains('#'), isFalse);
    });
  });
}
