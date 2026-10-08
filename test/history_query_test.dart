import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends local calendar days as UTC instants, both days included', () {
    final HistoryQuery query = (
      search: '  café ',
      type: TransactionType.expense,
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 8),
    );
    final params = query.apiParams;
    expect(params['q'], 'café');
    expect(params['type'], 'EXPENSE');
    expect(DateTime.parse(params['from']!), DateTime(2026, 10, 1).toUtc());
    expect(
      DateTime.parse(params['to']!),
      DateTime(2026, 10, 8, 23, 59, 59, 999).toUtc(),
    );
    expect(query.hasFilters, isTrue);
    expect(noHistoryFilters.apiParams, isEmpty);
    expect(noHistoryFilters.hasFilters, isFalse);
  });

  test('parses GET /transactions/page', () {
    final first = TransactionPage.fromJson({
      'items': [
        {
          'id': 't1',
          'userId': 'u1',
          'categoryId': 'c1',
          'title': 'Café',
          'amount': 3.5,
          'type': 'EXPENSE',
          'date': '2026-09-01T12:00:00.000Z',
          'goalId': null,
          'recurringId': null,
          'paymentMethodId': null,
          'reference': null,
          'category': {
            'id': 'c1',
            'name': 'Comida',
            'icon': 'lunch_dining',
            'type': 'EXPENSE',
            'isDefault': true,
            'userId': null,
          },
        },
      ],
      'nextCursor':
          '2026-09-01T12:00:00.000Z_0b7c2a8e-1d2f-4c3b-9a8e-7f6d5c4b3a21',
      'summary': {'count': 6, 'income': 501.5, 'expense': 20.75},
    });
    expect(first.items.single.title, 'Café');
    expect(first.nextCursor, isNotNull);
    expect(first.summary!.count, 6);
    expect(first.summary!.expense, 20.75);

    final last = TransactionPage.fromJson({
      'items': <Object>[],
      'nextCursor': null,
      'summary': null,
    });
    expect(last.nextCursor, isNull);
    expect(last.summary, isNull);
  });
}
