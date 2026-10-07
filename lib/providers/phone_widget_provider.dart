import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/phone_widget.dart';
import '../services/phone_widget_service.dart';
import 'auth_provider.dart';
import 'finance_providers.dart';
import 'storage_provider.dart';

final phoneWidgetServiceProvider = Provider<PhoneWidgetService>(
  (ref) => const PhoneWidgetService(),
);

typedef PhoneWidgetSettings = ({
  PhoneWidgetContent content,
  PhoneWidgetTheme theme,
});

/// What the phone widget shows and its colors, chosen in "Tu inicio".
final phoneWidgetSettingsProvider =
    NotifierProvider<PhoneWidgetSettingsController, PhoneWidgetSettings>(
      PhoneWidgetSettingsController.new,
    );

class PhoneWidgetSettingsController extends Notifier<PhoneWidgetSettings> {
  @override
  PhoneWidgetSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return (
      content:
          PhoneWidgetContent.values.asNameMap()[prefs.getString(
            phoneWidgetContentKey,
          )] ??
          PhoneWidgetContent.balance,
      theme:
          PhoneWidgetTheme.values.asNameMap()[prefs.getString(
            phoneWidgetThemeKey,
          )] ??
          PhoneWidgetTheme.dark,
    );
  }

  void setContent(PhoneWidgetContent content) {
    state = (content: content, theme: state.theme);
    ref
        .read(sharedPreferencesProvider)
        .setString(phoneWidgetContentKey, content.name);
  }

  void setTheme(PhoneWidgetTheme theme) {
    state = (content: state.content, theme: theme);
    ref
        .read(sharedPreferencesProvider)
        .setString(phoneWidgetThemeKey, theme.name);
  }
}

/// What the phone widget should show now; null while the data loads.
final phoneWidgetPayloadProvider = Provider<PhoneWidgetPayload?>((ref) {
  final settings = ref.watch(phoneWidgetSettingsProvider);
  if (ref.watch(currentUserIdProvider) == null) return loggedOutPhoneWidget;
  final data = ref.watch(dashboardProvider).value;
  if (data == null) return null;
  return phoneWidgetPayload(
    data,
    content: settings.content,
    theme: settings.theme,
    balanceHidden:
        ref.watch(sharedPreferencesProvider).getBool(balanceHiddenKey) ?? false,
    now: DateTime.now(),
  );
});

/// Keeps the native widget up to date. Watched by the app's root widget.
final phoneWidgetSyncProvider = Provider<void>((ref) {
  final service = ref.watch(phoneWidgetServiceProvider);
  if (!service.supported) return;
  final payload = ref.watch(phoneWidgetPayloadProvider);
  if (payload != null) unawaited(service.publish(payload));
});
