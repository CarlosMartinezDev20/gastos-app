import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import 'storage_provider.dart';

final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeControllerProvider) == ThemeMode.dark;
});

class ThemeController extends Notifier<ThemeMode> {
  static const _darkModeKey = 'dark_mode';

  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return (prefs.getBool(_darkModeKey) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = value ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool(_darkModeKey, value);
    await _syncWithApi(value);
  }

  Future<void> syncFromProfile(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    state = value ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool(_darkModeKey, value);
  }

  Future<void> _syncWithApi(bool value) async {
    final api = ref.read(apiClientProvider);
    if (api.token == null) return;

    try {
      await api.dio.patch(ApiEndpoints.profile, data: {'darkMode': value});
    } catch (_) {
      // The visual theme is local-first; API sync can recover on the next toggle.
    }
  }
}
