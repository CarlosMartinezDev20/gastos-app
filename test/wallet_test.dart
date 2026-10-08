import 'package:appgastos/core/utils/wallet.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/payment_method.dart';
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

const visa = PaymentMethod(
  id: 'visa',
  name: 'Visa',
  kind: PaymentMethodKind.creditCard,
  color: 'ink',
  last4: '4821',
  creditLimit: 500,
  statementDay: 15,
  dueDay: 5,
  // Every purchase (99 + 120 + 30) minus the refund (10), as the API sums it.
  chargedTotal: 239,
);

const cash = PaymentMethod(
  id: 'cash',
  name: 'Efectivo',
  kind: PaymentMethodKind.cash,
  color: 'mint',
);

Transaction tx(
  String id,
  DateTime date,
  double amount, {
  String? method,
  TransactionType type = TransactionType.expense,
}) => Transaction(
  id: id,
  title: id,
  amount: amount,
  type: type,
  date: date,
  category: food,
  paymentMethodId: method,
);

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('statementPeriod', () {
    test('runs from the day after the last closing to the next one', () {
      final period = statementPeriod(15, DateTime(2026, 10, 6));
      expect(period.start, DateTime(2026, 9, 16));
      expect(period.end, DateTime(2026, 10, 16));
    });

    test('the closing day still belongs to the statement', () {
      expect(
        statementPeriod(15, DateTime(2026, 10, 15, 23)).end,
        DateTime(2026, 10, 16),
      );
      expect(
        statementPeriod(15, DateTime(2026, 10, 16)).start,
        DateTime(2026, 10, 16),
      );
    });

    test('clamps a closing day to short months and crosses the year', () {
      final feb = statementPeriod(31, DateTime(2026, 2, 10));
      expect(feb.start, DateTime(2026, 2, 1));
      expect(feb.end, DateTime(2026, 3, 1));
      final jan = statementPeriod(20, DateTime(2027, 1, 3));
      expect(jan.start, DateTime(2026, 12, 21));
    });
  });

  test('nextDueDate is today or the next month', () {
    expect(nextDueDate(5, DateTime(2026, 10, 5, 20)), DateTime(2026, 10, 5));
    expect(nextDueDate(5, DateTime(2026, 10, 6)), DateTime(2026, 11, 5));
    expect(nextDueDate(31, DateTime(2026, 11, 2)), DateTime(2026, 11, 30));
    expect(daysUntil(DateTime(2026, 11, 5), DateTime(2026, 10, 6, 22)), 30);
  });

  test('summarizes a credit card by statement', () {
    final now = DateTime(2026, 10, 6);
    final summary = summarizeMethod(visa, [
      tx('before', DateTime(2026, 9, 15), 99, method: 'visa'),
      tx('a', DateTime(2026, 9, 20), 120, method: 'visa'),
      tx('b', DateTime(2026, 10, 2), 30, method: 'visa'),
      tx(
        'refund',
        DateTime(2026, 10, 3),
        10,
        method: 'visa',
        type: TransactionType.income,
      ),
      tx('other', DateTime(2026, 10, 2), 40, method: 'cash'),
    ], now);
    expect(summary.spent, 150);
    expect(summary.movements.map((t) => t.id), ['refund', 'b', 'a']);
    expect(summary.debt, 239);
    expect(summary.available, 261);
    expect(summary.utilization, closeTo(.478, 1e-9));
    expect(summary.lastStatementSpent, 99, reason: 'Aug 16 – Sep 15');
    expect(summary.closesOn, DateTime(2026, 10, 15));
    expect(summary.periodLabel, 'Corte del 15 oct');
    expect(summary.dueDate, DateTime(2026, 11, 5));
  });

  test('summarizes other methods by calendar month', () {
    final summary = summarizeMethod(cash, [
      tx('sept', DateTime(2026, 9, 30), 5, method: 'cash'),
      tx('oct', DateTime(2026, 10, 1), 7, method: 'cash'),
    ], DateTime(2026, 10, 6));
    expect(summary.spent, 7);
    expect(summary.limit, isNull);
    expect(summary.periodLabel, 'En octubre');
  });

  test('the form starts with the last method used for that type', () {
    final transactions = [
      tx('old', DateTime(2026, 10, 1), 1, method: 'cash'),
      tx('new', DateTime(2026, 10, 3), 1, method: 'visa'),
      tx('deleted', DateTime(2026, 10, 4), 1, method: 'gone'),
      tx(
        'income',
        DateTime(2026, 10, 5),
        1,
        method: 'cash',
        type: TransactionType.income,
      ),
    ];
    expect(
      lastUsedPaymentMethodId(transactions, [
        visa,
        cash,
      ], TransactionType.expense),
      'visa',
    );
    expect(
      lastUsedPaymentMethodId(transactions, [
        visa,
        cash,
      ], TransactionType.income),
      'cash',
    );
    expect(
      lastUsedPaymentMethodId(transactions, const [], TransactionType.expense),
      isNull,
    );
  });

  test('payments lower the debt, not the spending', () {
    const paid = PaymentMethod(
      id: 'visa',
      name: 'Visa',
      kind: PaymentMethodKind.creditCard,
      color: 'ink',
      creditLimit: 500,
      paidTotal: 300,
      chargedTotal: 250,
    );
    final summary = summarizeMethod(paid, [
      tx('a', DateTime(2026, 10, 1), 200, method: 'visa'),
      tx('b', DateTime(2026, 10, 2), 50, method: 'visa'),
    ], DateTime(2026, 10, 6));
    expect(summary.spent, 250, reason: 'no closing day: the month');
    expect(summary.debt, -50, reason: 'paid more than owed');
    expect(summary.available, 550);
    expect(summary.utilization, 0);
    expect(summary.lastStatementSpent, isNull);
  });

  test('the debt counts purchases older than the loaded movements', () {
    const old = PaymentMethod(
      id: 'visa',
      name: 'Visa',
      kind: PaymentMethodKind.creditCard,
      color: 'ink',
      creditLimit: 500,
      chargedTotal: 400.1,
      paidTotal: 100,
    );
    final summary = summarizeMethod(old, const [], DateTime(2026, 10, 6));
    expect(summary.spent, 0);
    expect(summary.debt, 300.1);
  });
}
