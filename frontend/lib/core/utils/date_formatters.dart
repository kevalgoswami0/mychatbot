import 'package:intl/intl.dart';

/// Clean date and relative time formatting helpers.
class AppDateFormatters {
  AppDateFormatters._();

  /// Returns friendly relative time string, e.g. "Just now", "12m ago", "3h ago", "Yesterday", or "Oct 12".
  static String formatRelative(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      return 'Just now';
    }

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '${mins}m ago';
    } else if (difference.inHours < 24 && dateTime.day == now.day) {
      final hours = difference.inHours;
      return '${hours}h ago';
    } else if (difference.inDays < 2 || (difference.inHours < 48 && dateTime.day == now.day - 1)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime); // e.g. "Mon"
    } else if (dateTime.year == now.year) {
      return DateFormat('MMM d').format(dateTime); // e.g. "Oct 12"
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  /// Formats exact time for chat messages, e.g. "10:45 AM"
  static String formatMessageTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  /// Formats date divider in chat, e.g. "Today", "Yesterday", "October 14, 2026"
  static String formatDateDivider(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(dateTime);
  }
}
