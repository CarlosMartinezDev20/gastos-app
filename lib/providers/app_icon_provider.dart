import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/app_icon_service.dart';
import 'theme_provider.dart';

final appIconServiceProvider = Provider<AppIconService>(
  (ref) => const AppIconService(),
);

/// Keeps the launcher icon in the chosen accent. Watched by the app's root
/// widget. On Android the switch waits for the app to go to the background
/// (see [AppIconService.switchesInBackground]); an accent synced from another
/// device is applied the same way.
final appIconSyncProvider = Provider<void>((ref) {
  final service = ref.watch(appIconServiceProvider);
  if (!service.supported) return;
  final accent = ref.watch(accentControllerProvider);
  if (!service.switchesInBackground) {
    unawaited(service.apply(accent));
    return;
  }
  final listener = AppLifecycleListener(
    onHide: () => unawaited(service.apply(accent)),
  );
  ref.onDispose(listener.dispose);
});
