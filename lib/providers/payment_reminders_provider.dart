import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/payment_reminders.dart';
import '../core/utils/wallet.dart';
import '../services/payment_reminder_service.dart';
import 'auth_provider.dart';
import 'finance_providers.dart';
import 'storage_provider.dart';

/// Overridden in tests (no notifications there).
final paymentReminderServiceProvider = Provider<PaymentReminderService>((ref) {
  final service = LocalPaymentReminderService();
  return service.supported ? service : const NoPaymentReminders();
});

const paymentRemindersKey = 'payment_reminders';

/// The Perfil switch "Recordatorios de pago" (off until turned on).
final paymentRemindersEnabledProvider =
    NotifierProvider<PaymentRemindersController, bool>(
      PaymentRemindersController.new,
    );

class PaymentRemindersController extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(paymentRemindersKey) ?? false;

  /// Turning it on asks for permission; denied leaves it off. Returns the
  /// resulting value.
  Future<bool> set(bool enabled) async {
    if (enabled) {
      enabled = await ref
          .read(paymentReminderServiceProvider)
          .requestPermission();
    }
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(paymentRemindersKey, enabled);
    return enabled;
  }
}

/// Reschedules the reminders whenever the cards, the movements or the
/// switch change. Watched by the app's root widget.
final paymentRemindersSyncProvider = Provider<void>((ref) {
  final service = ref.watch(paymentReminderServiceProvider);
  if (!service.supported) return;
  final enabled = ref.watch(paymentRemindersEnabledProvider);
  if (!enabled || ref.watch(currentUserIdProvider) == null) {
    unawaited(service.cancelAll());
    return;
  }
  final methods = ref.watch(paymentMethodsProvider).value;
  final transactions = ref.watch(transactionsProvider(null)).value;
  if (methods == null || transactions == null) return;
  final now = DateTime.now();
  unawaited(
    service.schedule(
      planPaymentReminders([
        for (final m in methods) summarizeMethod(m, transactions, now),
      ], now),
    ),
  );
});
