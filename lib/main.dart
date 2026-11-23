import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/secure_session_storage.dart';
import 'core/config/env.dart';
import 'core/constants/app_constants.dart';
import 'core/licenses.dart';
import 'core/monitoring/crash_reporting.dart';
import 'core/theme/app_accent.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'providers/app_icon_provider.dart';
import 'providers/payment_reminders_provider.dart';
import 'providers/phone_widget_provider.dart';
import 'providers/storage_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/money_privacy_provider.dart';
import 'widgets/money_privacy.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/theme_crossfade.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Crashes and uncaught errors from here on, scrubbed (when SENTRY_DSN is set).
  await runWithCrashReporting(_start);
}

Future<void> _start() async {
  registerBundledLicenses();
  await initializeDateFormatting('es');
  final prefs = await SharedPreferences.getInstance();
  // Restores the saved session (secure storage) and keeps it refreshed.
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(prefs),
    ),
  );
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AppGastosApp(),
    ),
  );
}

class AppGastosApp extends ConsumerWidget {
  const AppGastosApp({super.key});

  // Building ThemeData is not free: once per accent and brightness, not on
  // every rebuild.
  static final _themes = <(AppAccent, Brightness), ThemeData>{};

  static ThemeData _theme(AppAccent accent, Brightness brightness) =>
      _themes.putIfAbsent(
        (accent, brightness),
        () => brightness == Brightness.dark
            ? AppTheme.dark(accent: accent)
            : AppTheme.light(accent: accent),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    final accent = ref.watch(accentControllerProvider);
    final hideMoney = ref.watch(moneyPrivacyProvider);
    ref.watch(phoneWidgetSyncProvider);
    ref.watch(appIconSyncProvider);
    ref.watch(paymentRemindersSyncProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: _theme(accent, Brightness.light),
      darkTheme: _theme(accent, Brightness.dark),
      themeMode: themeMode,
      // The theme switches at once under ThemeCrossfade's fading snapshot;
      // lerping it would rebuild every widget on every frame.
      themeAnimationDuration: Duration.zero,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => MoneyPrivacyScope(
        hidden: hideMoney,
        child: ThemeCrossfade(child: AppLockGate(child: child!)),
      ),
    );
  }
}
