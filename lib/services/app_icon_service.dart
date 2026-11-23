import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_accent.dart';

/// Switches the launcher icon to the accent's (Android activity-aliases in
/// `MainActivity.kt`, iOS alternate icons in `AppDelegate.swift`; the icons
/// come from `branding/accent_icons.sh`).
class AppIconService {
  const AppIconService();

  static const _channel = MethodChannel('miaunero/app_icon');

  /// Android's alias name for the default icon; iOS calls it nil.
  static const _defaultName = 'Lima';

  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Android launchers may close the app when its launcher entry changes, so
  /// there the switch waits until the app goes to the background. iOS only
  /// allows it in the foreground (and shows its own alert).
  bool get switchesInBackground =>
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> apply(AppAccent accent) async {
    if (!supported) return;
    try {
      final current = await _channel.invokeMethod<String>('current');
      final wanted = accent.iconName;
      if ((current ?? _defaultName) == (wanted ?? _defaultName)) return;
      await _channel.invokeMethod<void>('set', wanted);
    } on PlatformException catch (e) {
      debugPrint('No se pudo cambiar el ícono: $e');
    } on MissingPluginException {
      // Tests and platforms without the channel.
    }
  }
}
