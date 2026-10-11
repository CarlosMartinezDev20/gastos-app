import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/secure_session_storage.dart';
import 'core/config/env.dart';
import 'core/licenses.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'providers/payment_reminders_provider.dart';
import 'providers/phone_widget_provider.dart';
import 'providers/storage_provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/theme_crossfade.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Building ThemeData is not free; do it once instead of on every rebuild.
  static final _light = AppTheme.light();
  static final _dark = AppTheme.dark();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeControllerProvider);
    ref.watch(phoneWidgetSyncProvider);
    ref.watch(paymentRemindersSyncProvider);
    return MaterialApp.router(
      title: 'Finanzas M3',
      debugShowCheckedModeBanner: false,
      theme: _light,
      darkTheme: _dark,
      themeMode: themeMode,
      // The theme switches at once under ThemeCrossfade's fading snapshot;
      // lerping it would rebuild every widget on every frame.
      themeAnimationDuration: Duration.zero,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: router,
      builder: (context, child) => ThemeCrossfade(child: child!),
    );
  }
}
