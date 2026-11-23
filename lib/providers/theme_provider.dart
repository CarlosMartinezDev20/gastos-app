import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_accent.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'storage_provider.dart';

/// Light, dark or automatic (Perfil → Apariencia). Local first: it applies at
/// once and is saved on the device, then synced to the profile.
final themeControllerProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

/// The accent color (Perfil → Apariencia), saved and synced like the mode.
final accentControllerProvider = NotifierProvider<AccentController, AppAccent>(
  AccentController.new,
);

const themeModeKey = 'theme_mode';
const accentKey = 'accent';

/// Older versions only saved this bool; read once if [themeModeKey] is missing.
const legacyDarkModeKey = 'dark_mode';

ThemeMode themeModeFromApi(String? value) => switch (value) {
  'DARK' => ThemeMode.dark,
  'SYSTEM' => ThemeMode.system,
  _ => ThemeMode.light,
};

String themeModeApiValue(ThemeMode mode) => switch (mode) {
  ThemeMode.dark => 'DARK',
  ThemeMode.system => 'SYSTEM',
  ThemeMode.light => 'LIGHT',
};

/// Applies the profile's appearance after signing in or restoring a session.
Future<void> syncAppearanceFromProfile(Ref ref, UserProfile user) async {
  await ref.read(themeControllerProvider.notifier).syncFromProfile(user);
  await ref.read(accentControllerProvider.notifier).syncFromProfile(user);
}

/// Saves the appearance in the profile when someone is signed in.
Future<void> _syncToProfile(
  Ref ref, {
  String? themeMode,
  String? accent,
}) async {
  if (ref.read(currentUserIdProvider) == null) return;
  try {
    await ref
        .read(authRepositoryProvider)
        .updateProfile(themeMode: themeMode, accent: accent);
  } catch (_) {
    // Local-first: the next change or sign-in syncs it again.
  }
}

class ThemeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = ThemeMode.values.asNameMap()[prefs.getString(themeModeKey)];
    if (saved != null) return saved;
    return (prefs.getBool(legacyDarkModeKey) ?? false)
        ? ThemeMode.dark
        : ThemeMode.light;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(themeModeKey, mode.name);
    await _syncToProfile(ref, themeMode: themeModeApiValue(mode));
  }

  /// The headers' sun/moon button: always an explicit light or dark.
  Future<void> setDarkMode(bool value) =>
      setMode(value ? ThemeMode.dark : ThemeMode.light);

  Future<void> syncFromProfile(UserProfile user) async {
    state = themeModeFromApi(user.themeMode);
    await ref
        .read(sharedPreferencesProvider)
        .setString(themeModeKey, state.name);
  }
}

class AccentController extends Notifier<AppAccent> {
  @override
  AppAccent build() => AppAccent.fromName(
    ref.read(sharedPreferencesProvider).getString(accentKey),
  );

  Future<void> set(AppAccent accent) async {
    state = accent;
    await ref.read(sharedPreferencesProvider).setString(accentKey, accent.name);
    await _syncToProfile(ref, accent: accent.apiValue);
  }

  Future<void> syncFromProfile(UserProfile user) async {
    state = AppAccent.fromApi(user.accent);
    await ref.read(sharedPreferencesProvider).setString(accentKey, state.name);
  }
}
