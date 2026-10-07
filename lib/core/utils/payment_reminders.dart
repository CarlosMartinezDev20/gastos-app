import 'package:intl/intl.dart';

import '../../models/payment_method.dart';
import '../../models/recurring.dart';
import 'formatters.dart';
import 'wallet.dart';

/// A local notification to schedule.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.when,
    required this.title,
    required this.body,
  });

  /// Stable per card and kind, so rescheduling replaces it.
  final int id;
  final DateTime when;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.when == when &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode => Object.hash(id, when, title, body);
}

/// How long before the due date the first reminder comes.
const reminderDaysBefore = 3;

/// The hour (local) reminders arrive at.
const reminderHour = 9;

/// Reminders for each credit card with a due day and money owed: a few
/// days before and on the day. Only future ones; cards that are paid up
/// get none.
List<PlannedReminder> planPaymentReminders(
  List<WalletSummary> summaries,
  DateTime now,
) {
  final day = DateFormat("d 'de' MMMM", 'es');
  final reminders = <PlannedReminder>[];
  for (final summary in summaries) {
    final due = summary.dueDate;
    final debt = summary.debt;
    if (due == null || debt == null || debt <= 0) continue;
    final name = summary.method.shortLabel;
    final owed = Formatters.compactMoney(debt);
    // Notification ids are 32-bit: cards below 2^29, subscriptions above.
    final slot = (summary.method.id.hashCode & 0x0fffffff) * 2;
    final dueAt = DateTime(due.year, due.month, due.day, reminderHour);
    final early = DateTime(
      due.year,
      due.month,
      due.day - reminderDaysBefore,
      reminderHour,
    );
    if (early.isAfter(now)) {
      reminders.add(
        PlannedReminder(
          id: slot,
          when: early,
          title: 'Tu $name vence en $reminderDaysBefore días',
          body: 'Debes $owed. Fecha de pago: ${day.format(due)}.',
        ),
      );
    }
    if (dueAt.isAfter(now)) {
      reminders.add(
        PlannedReminder(
          id: slot + 1,
          when: dueAt,
          title: 'Hoy vence tu $name',
          body: 'Debes $owed. Págala hoy para evitar intereses.',
        ),
      );
    }
  }
  return reminders;
}

/// A reminder the day before each active subscription charges, at 9:00.
List<PlannedReminder> planSubscriptionReminders(
  List<RecurringRule> subscriptions,
  List<PaymentMethod> methods,
  DateTime now,
) {
  final reminders = <PlannedReminder>[];
  for (final s in subscriptions) {
    if (!s.active || !s.isSubscription) continue;
    final charge = s.nextDate.toLocal();
    final when = DateTime(
      charge.year,
      charge.month,
      charge.day - 1,
      reminderHour,
    );
    if (!when.isAfter(now)) continue;
    final method = methods.where((m) => m.id == s.paymentMethodId).firstOrNull;
    reminders.add(
      PlannedReminder(
        id: 0x40000000 + (s.id.hashCode & 0x0fffffff),
        when: when,
        title: 'Mañana se cobra ${s.title}',
        body: [
          Formatters.compactMoney(s.amount),
          if (method != null) 'con ${method.shortLabel}',
        ].join(' '),
      ),
    );
  }
  return reminders;
}
