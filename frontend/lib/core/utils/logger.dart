import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

/// Clean, structured logger replacing bare print statements.
class AppLogger {
  AppLogger._();

  static void info(String message, {String tag = 'INFO', Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      dev.log('[$tag] $message', name: 'NovaChat', error: error, stackTrace: stackTrace);
    }
  }

  static void warning(String message, {String tag = 'WARN', Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      dev.log('⚠️ [$tag] $message', name: 'NovaChat', error: error, stackTrace: stackTrace);
    }
  }

  static void error(
    String message, {
    String tag = 'ERROR',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      dev.log(
        '🛑 [$tag] $message',
        name: 'NovaChat',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
