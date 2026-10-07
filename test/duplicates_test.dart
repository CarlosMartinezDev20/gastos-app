import 'package:appgastos/core/utils/duplicates.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

const food = Category(
  id: 'food',
  name: 'Comida',
  icon: 'lunch_dining',
  type: TransactionType.expense,
  isDefault: true,
);

final saved = Transaction(
  id: 't1',
  title: 'Farmacias SR',
  amount: 3.40,
  type: TransactionType.expense,
  date: DateTime(2026, 10, 2, 15, 54),
  category: food,
  reference: 'ABC',
);

Transaction? check({
  double amount = 3.40,
  DateTime? date,
  String title = 'Farmacias SR',
  String? reference,
  TransactionType type = TransactionType.expense,
}) => findLikelyDuplicate(
  existing: [saved],
  type: type,
  amount: amount,
  date: date ?? DateTime(2026, 10, 2, 20),
  title: title,
  reference: reference,
);

void main() {
  test('flags the same receipt saved twice', () {
    expect(check(), saved);
    expect(check(title: 'farmacias sr '), saved, reason: 'case and spaces');
    expect(check(title: 'Farmacias'), saved, reason: 'shorter name');
    expect(check(reference: 'ABC', title: 'Otro nombre'), saved);
  });

  test('lets genuinely different movements through', () {
    expect(check(amount: 3.45), isNull);
    expect(check(date: DateTime(2026, 10, 3)), isNull);
    expect(check(title: 'Super Selectos'), isNull);
    expect(check(type: TransactionType.income), isNull);
    // Another invoice for the same amount, same day.
    expect(check(reference: 'XYZ'), isNull);
  });
}
