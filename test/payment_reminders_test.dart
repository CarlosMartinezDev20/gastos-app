import 'package:appgastos/core/utils/payment_reminders.dart';
import 'package:appgastos/core/utils/wallet.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/payment_method.dart';
import 'package:appgastos/models/recurring.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const food = Category(
  id: 'food',
  name: 'Comida',
  icon: 'lunch_dining',
  type: TransactionType.expense,
  isDefault: true,
);

PaymentMethod card({double paid = 0, int? dueDay = 10}) => PaymentMethod(
  id: 'visa',
  name: 'Visa',
  kind: PaymentMethodKind.creditCard,
  color: 'ink',
  last4: '4821',
  dueDay: dueDay,
  paidTotal: paid,
  // The purchase below, as the API's all-time total.
  chargedTotal: 120,
);

final purchase = Transaction(
  id: 't',
  title: 'Zapatos',
  amount: 120,
  type: TransactionType.expense,
  date: DateTime(2026, 10, 1),
  category: food,
  paymentMethodId: 'visa',
);

List<PlannedReminder> plan(PaymentMethod method, DateTime now) =>
    planPaymentReminders([
      summarizeMethod(method, [purchase], now),
    ], now);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('reminds three days before and on the due day, at 9', () {
    final reminders = plan(card(), DateTime(2026, 10, 2, 12));
    expect(reminders.map((r) => r.when), [
      DateTime(2026, 10, 7, 9),
      DateTime(2026, 10, 10, 9),
    ]);
    expect(reminders.first.title, 'Tu Visa ··4821 vence en 3 días');
    expect(reminders.first.body, contains(r'Debes $120.00'));
    expect(reminders.last.title, 'Hoy vence tu Visa ··4821');
    expect(reminders.first.id + 1, reminders.last.id);
  });

  test('only future reminders; the next month after the due day', () {
    // The 8th: the early one already passed.
    expect(plan(card(), DateTime(2026, 10, 8)).map((r) => r.when), [
      DateTime(2026, 10, 10, 9),
    ]);
    // After the due day the next one is November's.
    expect(plan(card(), DateTime(2026, 10, 11)).map((r) => r.when), [
      DateTime(2026, 11, 7, 9),
      DateTime(2026, 11, 10, 9),
    ]);
  });

  test('nothing for paid-up cards or without a due day', () {
    expect(plan(card(paid: 120), DateTime(2026, 10, 2)), isEmpty);
    expect(plan(card(dueDay: null), DateTime(2026, 10, 2)), isEmpty);
  });

  test('a reminder the day before each active subscription charge', () {
    RecurringRule sub(String id, DateTime next, {bool active = true}) =>
        RecurringRule(
          id: id,
          title: 'Netflix',
          amount: 9.99,
          type: TransactionType.expense,
          category: food,
          frequency: RecurrenceFrequency.monthly,
          nextDate: next,
          active: active,
          service: 'netflix',
          paymentMethodId: 'visa',
        );
    final reminders = planSubscriptionReminders(
      [
        sub('a', DateTime(2026, 10, 15, 12)),
        sub('paused', DateTime(2026, 10, 15, 12), active: false),
        sub('tomorrow', DateTime(2026, 10, 3, 12)),
      ],
      [card()],
      DateTime(2026, 10, 2, 10),
    );
    expect(reminders, hasLength(1), reason: 'paused / already past skipped');
    expect(reminders.single.when, DateTime(2026, 10, 14, 9));
    expect(reminders.single.title, 'Mañana se cobra Netflix');
    expect(reminders.single.body, r'$9.99 con Visa ··4821');
    final cardIds = plan(card(), DateTime(2026, 10, 2)).map((r) => r.id);
    expect(cardIds, everyElement(lessThan(reminders.single.id)));
  });
}
