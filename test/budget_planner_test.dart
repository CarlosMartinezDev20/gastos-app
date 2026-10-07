import 'package:appgastos/core/utils/budget_planner.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

const fun = Category(
  id: 'cat-fun',
  name: 'Salidas',
  icon: 'celebration',
  type: TransactionType.expense,
  isDefault: true,
);

Transaction tx(
  String id,
  double amount,
  Category category,
  DateTime date, {
  TransactionType type = TransactionType.expense,
  String? goalId,
}) => Transaction(
  id: id,
  title: id,
  amount: amount,
  type: type,
  date: date,
  category: category,
  goalId: goalId,
);

void main() {
  final now = DateTime(2026, 10, 15);

  test('averages per active month, ignoring goals and old movements', () {
    final txs = [
      tx('a', 100, food, DateTime(2026, 9, 3)),
      tx('b', 60, food, DateTime(2026, 10, 2)),
      tx('c', 40, fun, DateTime(2026, 10, 5)),
      tx('d', 500, food, DateTime(2026, 3, 1)), // outside the window
      tx('e', 30, savingsCategory, DateTime(2026, 10, 6), goalId: 'g1'),
      tx('f', 300, salary, DateTime(2026, 9, 1), type: TransactionType.income),
      tx('g', 300, salary, DateTime(2026, 10, 1), type: TransactionType.income),
    ];
    final averages = categoryAverages(txs, now);
    expect(averages.map((a) => (a.category.id, a.monthly)), [
      ('cat-food', 80.0),
      ('cat-fun', 20.0),
    ]);
    expect(averageMonthlyIncome(txs, now), 300);
  });

  test('splits the income and scales a bucket that does not fit', () {
    final plan = planBudget(
      income: 400,
      split: budgetSplits.first, // 50/30/20 → 200 / 120 / 80
      averages: [
        CategoryAverage(food, 150),
        CategoryAverage(fun, 180), // wants: 180 > 120 → ×(120/180)
      ],
      needIds: {'cat-food'},
    );
    expect((plan.needs, plan.wants, plan.savings), (200.0, 120.0, 80.0));
    final byId = {for (final c in plan.categories) c.category.id: c};
    // Fits: rounded up to a friendly number.
    expect(byId['cat-food']!.suggested, 150);
    expect(plan.needsLeft, 50);
    // Scaled down to fit and rounded down: 120.
    expect(byId['cat-fun']!.suggested, 120);
    expect(plan.wantsCut, closeTo(1 / 3, 1e-9));
    expect(plan.wantsLeft, 0);
  });

  test('guesses needs from the category icon', () {
    expect(isLikelyNeed(food), isTrue);
    expect(isLikelyNeed(fun), isFalse);
  });

  test('income sources: frequencies and history', () {
    const sources = [
      IncomeSource('Sueldo', 150, IncomeFrequency.biweekly), // 300
      IncomeSource('Beca', 120), // 120
      IncomeSource('Clases', 30, IncomeFrequency.weekly), // 130
    ];
    expect(monthlyIncome(sources), closeTo(550, 1e-9));
    final restored = IncomeSource.fromJson(sources.first.toJson());
    expect(
      (restored.name, restored.amount, restored.frequency),
      ('Sueldo', 150.0, IncomeFrequency.biweekly),
    );

    final history = incomeFromHistory([
      tx('a', 200, salary, DateTime(2026, 9, 1), type: TransactionType.income),
      tx('b', 100, salary, DateTime(2026, 10, 1), type: TransactionType.income),
    ], now);
    expect(history.single.name, 'Trabajo');
    expect(history.single.amount, 150);
  });

  test('typed limits are kept and leave less room for suggestions', () {
    final plan = planBudget(
      income: 400, // wants: 120
      split: budgetSplits.first,
      averages: [
        CategoryAverage(fun, 100),
        const CategoryAverage(
          Category(
            id: 'cat-games',
            name: 'Juegos',
            icon: 'sports_esports',
            type: TransactionType.expense,
            isDefault: false,
          ),
          50,
        ),
      ],
      needIds: const {},
      overrides: {'cat-games': 60},
    );
    final byId = {for (final c in plan.categories) c.category.id: c};
    expect(byId['cat-games']!.suggested, 60);
    expect(byId['cat-games']!.custom, isTrue);
    // 120 − 60 typed = 60 left for Salidas, which usually costs 100.
    expect(byId['cat-fun']!.suggested, 60);
    expect(plan.wantsLeft, 0);
  });
}
