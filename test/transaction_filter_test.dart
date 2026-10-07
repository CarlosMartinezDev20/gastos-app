import 'package:appgastos/core/utils/transaction_filter.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Transaction tx(String id, String title, DateTime date, {Category? category}) =>
    Transaction(
      id: id,
      title: title,
      amount: 10,
      type: (category ?? food).type,
      date: date,
      category: category ?? food,
    );

void main() {
  final items = [
    tx('a', 'Almuerzo', DateTime(2026, 9, 1, 23, 30)),
    tx('b', 'Café', DateTime(2026, 9, 2, 8)),
    tx('c', 'Tutoría', DateTime(2026, 9, 3, 12), category: salary),
  ];

  test('search ignores accents and case, and matches the category', () {
    expect(filterTransactions(items, query: 'CAFE').map((t) => t.id), ['b']);
    expect(filterTransactions(items, query: 'trabajo').map((t) => t.id), ['c']);
  });

  test('date range includes the whole end day, newest first', () {
    final result = filterTransactions(
      items,
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 2),
    );
    expect(result.map((t) => t.id), ['b', 'a']);
  });

  test('filters by type', () {
    expect(
      filterTransactions(items, type: TransactionType.income).map((t) => t.id),
      ['c'],
    );
  });
}
