import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/utils/extensions.dart';

/// Renders Markdown content with custom typography, tables, styled code blocks,
/// and complete elimination of raw Markdown '#' heading markers during or after text streaming.
class MarkdownMessageBody extends StatelessWidget {
  const MarkdownMessageBody({
    super.key,
    required this.data,
    required this.textColor,
    this.isStreaming = false,
  });

  final String data;
  final Color textColor;
  final bool isStreaming;

  /// Robust markdown sanitizer that converts all `#` heading markers into clean bold text,
  /// normalizes bold asterisks, auto-closes streaming markdown tags, and prevents raw asterisks
  /// from being visible on screen during or after streaming.
  static String sanitizeMarkdown(String raw, {bool isStreaming = false}) {
    if (raw.isEmpty) return '';

    // If there are fenced code blocks, only sanitize non-code parts to preserve code syntax
    final codeBlockRegex = RegExp(r'(```[\s\S]*?```)');
    if (raw.contains('```')) {
      final parts = raw.split(codeBlockRegex);
      final matches = codeBlockRegex.allMatches(raw).map((m) => m.group(0)!).toList();
      final sb = StringBuffer();
      for (int i = 0; i < parts.length; i++) {
        sb.write(_cleanNonCodeMarkdown(parts[i], isStreaming: isStreaming));
        if (i < matches.length) {
          sb.write(matches[i]);
        }
      }
      return sb.toString().trimLeft();
    }

    return _cleanNonCodeMarkdown(raw, isStreaming: isStreaming).trimLeft();
  }

  static String _cleanNonCodeMarkdown(String text, {bool isStreaming = false}) {
    if (text.isEmpty) return '';

    // 1. Remove dangling trailing hash markers typed in real-time (e.g. "###", "\n###", "### ")
    String cleaned = text.replaceAllMapped(
      RegExp(r'(^|\n|\s)#{1,6}\s*$'),
      (m) => m.group(1) ?? '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'#{1,6}\s*$'), '');

    // 2. Convert list items with hashes (e.g. "- ### Title", "1. ## Subtitle")
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(^|\n)(\s*(?:[-*+]|\d+\.)\s*)#{1,6}\s*(.+?)(?=\n|$)'),
      (match) {
        final prefix = match.group(1) ?? '';
        final bullet = match.group(2) ?? '';
        final title = match.group(3)!.trim().replaceAll('**', '').replaceAll('*', '');
        if (title.isEmpty) return '$prefix$bullet';
        return '$prefix$bullet**$title**';
      },
    );

    // 3. Convert ATX headings at line start into clean bold headings
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(^|\n)\s*#{1,6}\s*(.+?)(?=\n|$)'),
      (match) {
        final prefix = match.group(1) ?? '';
        final title = match.group(2)!.trim().replaceAll('**', '').replaceAll('*', '');
        if (title.isEmpty) return prefix;
        return '$prefix\n**$title**\n';
      },
    );

    // 4. Convert any inline/mid-sentence hash headings
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'#{1,6}\s*([A-Za-z0-9][^\n#]*?)(?=(?:\s*#{1,6})|\n|$)'),
      (match) {
        final title = match.group(1)!.trim().replaceAll('**', '').replaceAll('*', '');
        if (title.isEmpty) return '';
        return '**$title**';
      },
    );

    // 5. Remove any remaining stray hashes anywhere in non-code text
    cleaned = cleaned.replaceAll(RegExp(r'#{1,6}'), '');

    // 6. Normalize triple-plus asterisks to standard bold '**'
    cleaned = cleaned.replaceAll(RegExp(r'\*{3,}'), '**');

    // 7. Fix whitespace inside bold markers that prevents markdown from parsing as bold
    // e.g. "** text **" or "** text**" or "**text **" -> "**text**"
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*\s+(.+?)\s+\*\*'),
      (m) => '**${m.group(1)}**',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*\s+(.+?)\*\*'),
      (m) => '**${m.group(1)}**',
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\*\*(.+?)\s+\*\*'),
      (m) => '**${m.group(1)}**',
    );

    // 8. Handle trailing/streaming asterisks so raw asterisks are never visible on screen
    if (isStreaming) {
      if (cleaned.endsWith('**')) {
        // Trailing double asterisk with no word yet: strip temporarily so raw asterisks never display
        cleaned = cleaned.substring(0, cleaned.length - 2);
      } else if (cleaned.endsWith('*')) {
        // Trailing single asterisk: strip temporarily
        cleaned = cleaned.substring(0, cleaned.length - 1);
      }
    }

    // 9. Auto-close unmatched opening '**' bold markers
    // When text is streaming or incomplete, an unclosed '**' causes Markdown to render literal '**'.
    // Auto-closing with '**' ensures Markdown renders it immediately as clean bold text without showing asterisks.
    final boldMatches = RegExp(r'\*\*').allMatches(cleaned).length;
    if (boldMatches % 2 != 0) {
      cleaned = '$cleaned**';
    }

    // 10. Normalize excessive consecutive newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final sanitizedData = sanitizeMarkdown(data, isStreaming: isStreaming);

    if (sanitizedData.isEmpty && !isStreaming) {
      return const SizedBox.shrink();
    }

    final markdownStyleSheet = MarkdownStyleSheet(
      p: AppTextStyles.bodyLarge.copyWith(color: textColor, height: 1.45),
      h1: AppTextStyles.titleLarge.copyWith(color: textColor, fontWeight: FontWeight.w700),
      h2: AppTextStyles.titleMedium.copyWith(color: textColor, fontWeight: FontWeight.w700),
      h3: AppTextStyles.titleMedium.copyWith(color: textColor, fontWeight: FontWeight.w600),
      em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.w700),
      blockquote: AppTextStyles.bodyMedium.copyWith(
        color: textColor.withValues(alpha: 0.85),
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      code: AppTextStyles.code.copyWith(
        fontSize: 13,
        color: textColor,
        backgroundColor: colors.border.withValues(alpha: 0.5),
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.border, width: 1),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      listBullet: AppTextStyles.bodyLarge.copyWith(color: textColor),
      tableHead: AppTextStyles.caption.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      tableBody: AppTextStyles.bodyMedium.copyWith(color: textColor),
      tableBorder: TableBorder.all(
        color: colors.border,
        width: 1,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sanitizedData.isNotEmpty)
          SelectionArea(
            child: MarkdownBody(
              data: sanitizedData,
              selectable: false,
              styleSheet: markdownStyleSheet,
              builders: {
                'code': _CodeBlockCustomBuilder(colors: colors),
              },
            ),
          ),
      ],
    );
  }
}

class _CodeBlockCustomBuilder extends MarkdownElementBuilder {
  _CodeBlockCustomBuilder({required this.colors});

  final dynamic colors;

  @override
  Widget? visitElementAfter(dynamic element, TextStyle? preferredStyle) {
    final textContent = element.textContent as String;

    // Only render custom card for multiline code blocks
    if (!textContent.contains('\n')) {
      return null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Code label & Copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusMd - 1),
              ),
              border: Border(bottom: BorderSide(color: colors.border, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Code',
                  style: AppTextStyles.micro.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                _CopyCodeButton(text: textContent),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              textContent.trimRight(),
              style: AppTextStyles.code.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyCodeButton extends StatefulWidget {
  const _CopyCodeButton({required this.text});

  final String text;

  @override
  State<_CopyCodeButton> createState() => _CopyCodeButtonState();
}

class _CopyCodeButtonState extends State<_CopyCodeButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: _copy,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 14,
              color: _copied ? colors.success : colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              _copied ? 'Copied' : 'Copy',
              style: AppTextStyles.micro.copyWith(
                color: _copied ? colors.success : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
