import 'package:appgastos/core/utils/brand_marks.dart';
import 'package:appgastos/core/utils/subscriptions.dart';
import 'package:appgastos/widgets/service_logo.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/recurring.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const subs = Category(
  id: 'subs',
  name: 'Suscripciones',
  icon: 'subscriptions',
  type: TransactionType.expense,
  isDefault: false,
);

RecurringRule rule(
  String id,
  double amount,
  RecurrenceFrequency frequency, {
  bool active = true,
  DateTime? next,
  String service = 'netflix',
}) => RecurringRule(
  id: id,
  title: id,
  amount: amount,
  type: TransactionType.expense,
  category: subs,
  frequency: frequency,
  nextDate: next ?? DateTime(2026, 10, 15),
  active: active,
  service: service,
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  test('the catalog has unique keys and finds them', () {
    final keys = subscriptionCatalog.map((s) => s.key).toSet();
    expect(keys, hasLength(subscriptionCatalog.length));
    expect(keys, isNot(contains(otherServiceKey)));
    expect(serviceFor('chatgpt')!.name, 'ChatGPT');
    expect(serviceFor(otherServiceKey), isNull);
    expect(serviceFor(null), isNull);
  });

  test('monthly cost normalizes frequencies and skips paused ones', () {
    final total = monthlySubscriptionCost([
      rule('netflix', 10, RecurrenceFrequency.monthly),
      rule('icloud', 120, RecurrenceFrequency.yearly),
      rule('gym', 3, RecurrenceFrequency.weekly),
      rule('paused', 50, RecurrenceFrequency.monthly, active: false),
    ]);
    expect(total, closeTo(10 + 10 + 3 * 52 / 12, 1e-9));
  });

  test('upcoming charges come soonest first, without paused ones', () {
    final list = upcomingCharges([
      rule('b', 1, RecurrenceFrequency.monthly, next: DateTime(2026, 10, 20)),
      rule('a', 1, RecurrenceFrequency.monthly, next: DateTime(2026, 10, 9)),
      rule('p', 1, RecurrenceFrequency.monthly, active: false),
    ]);
    expect(list.map((r) => r.id), ['a', 'b']);
  });

  test('monograms and colors for services outside the catalog', () {
    expect(monogramFor('Mi Gimnasio Local'), 'MGL');
    expect(monogramFor('crunchyroll'), 'CR');
    expect(monogramFor('  '), '?');
    expect(colorsFor('Crunchyroll'), colorsFor('crunchyroll'));
  });

  test('chargeLabel says when it charges', () {
    final now = DateTime(2026, 10, 7, 20);
    expect(chargeLabel(DateTime(2026, 10, 7, 12), now: now), 'Cobra hoy');
    expect(chargeLabel(DateTime(2026, 10, 8, 12), now: now), 'Mañana');
    expect(chargeLabel(DateTime(2026, 10, 12, 12), now: now), 'En 5 días');
    expect(chargeLabel(DateTime(2026, 11, 20, 12), now: now), '20 nov');
  });

  test('every brand mark belongs to a catalog service and parses', () {
    for (final key in brandMarks.keys) {
      expect(serviceFor(key), isNotNull, reason: key);
      final bounds = ServiceLogo.markFor(key)!.getBounds();
      // About the 24×24 box (bounds include curve control points).
      expect(bounds.width, greaterThan(10), reason: key);
      expect(bounds.left, greaterThanOrEqualTo(-1), reason: key);
      expect(bounds.right, lessThanOrEqualTo(25), reason: key);
    }
    expect(ServiceLogo.markFor('chatgpt'), isNull, reason: 'monogram');
  });
}
