import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local_storage.dart';
import '../../../data/providers/repository_providers.dart';

/// Notifier managing App ThemeMode state with disk persistence.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  late final LocalStorage _storage;

  @override
  ThemeMode build() {
    _storage = ref.watch(localStorageProvider);
    final savedMode = _storage.getThemeMode();
    switch (savedMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final modeString = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.setThemeMode(modeString);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
