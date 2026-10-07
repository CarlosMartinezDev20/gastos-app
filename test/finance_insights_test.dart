import 'package:appgastos/core/utils/finance_insights.dart';
import 'package:appgastos/core/utils/mascot_insights.dart';
import 'package:appgastos/models/budget.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/metrics.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

Transaction tx(
  double amount,
  DateTime date, {
  Category category = food,
  String? goalId,
}) => Transaction(
  id: '$amount$date',
  title: 't',
  amount: amount,
  type: category.type,
  date: date,
  category: category,
  goalId: goalId,
);

void main() {
  final now = DateTime(2026, 10, 15, 18);

  test('30-day summary separates spending from goal contributions', () {
    final summary = recentSummary([
      tx(300, DateTime(2026, 9, 16), category: salary), // first day included
      tx(20, DateTime(2026, 10, 3)),
      tx(50, DateTime(2026, 10, 4), category: savingsCategory, goalId: 'g'),
      tx(99, DateTime(2026, 9, 15, 23)), // 31 days ago
    ], now);
    expect(summary.income, 300);
    expect(summary.spent, 20);
    expect(summary.saved, 50);
  });

  test('last seven days ends today and ignores income and savings', () {
    final days = lastSevenDays([
      tx(5, DateTime(2026, 10, 15, 9)),
      tx(7, DateTime(2026, 10, 15, 20)),
      tx(3, DateTime(2026, 10, 9, 12)),
      tx(100, DateTime(2026, 10, 8, 12)), // 8 days ago
      tx(40, DateTime(2026, 10, 14), category: salary),
      tx(40, DateTime(2026, 10, 14), category: savingsCategory, goalId: 'g'),
    ], now);
    expect(days, hasLength(7));
    expect(days.first.day, DateTime(2026, 10, 9));
    expect(days.first.amount, 3);
    expect(days.last.day, DateTime(2026, 10, 15));
    expect(days.last.amount, 12);
    expect(days[5].amount, 0);
  });

  test('flow buckets split income and spending per period', () {
    final items = [
      tx(5, DateTime(2026, 10, 15, 9)),
      tx(40, DateTime(2026, 10, 14), category: salary),
      tx(40, DateTime(2026, 10, 14), category: savingsCategory, goalId: 'g'),
      tx(9, DateTime(2026, 9, 20)),
      tx(70, DateTime(2025, 11, 2), category: salary),
      tx(1, DateTime(2025, 10, 31)), // 13 months ago
    ];

    final week = flowBuckets(items, now, FlowPeriod.week);
    expect(week, hasLength(7));
    expect(week.last.spent, 5);
    expect(week[5].income, 40);
    expect(week[5].spent, 0);

    final month = flowBuckets(items, now, FlowPeriod.month);
    expect(month, hasLength(4));
    expect(month.first.start, DateTime(2026, 9, 18));
    expect(month.first.spent, 9);
    expect(month.last.start, DateTime(2026, 10, 9));
    expect(month.last.income, 40);

    final year = flowBuckets(items, now, FlowPeriod.year);
    expect(year, hasLength(12));
    expect(year.first.start, DateTime(2025, 11));
    expect(year.first.income, 70);
    expect(year.fold(0.0, (s, b) => s + b.spent), 14);
  });

  group('mascot', () {
    PeriodSummary month(double income, double spent, double saved) =>
        PeriodSummary(income: income, spent: spent, saved: saved);

    MascotMood mood(PeriodSummary m, {double balance = 100, bool any = true}) =>
        homeTip(
          month: m,
          balance: balance,
          hasActivity: any,
          goalCount: 1,
        ).mood;

    test('home mood follows the last 30 days', () {
      expect(mood(month(0, 0, 0), any: false), MascotMood.sleepy);
      expect(mood(month(100, 10, 0), balance: -5), MascotMood.worried);
      expect(mood(month(100, 120, 0)), MascotMood.worried);
      expect(mood(month(100, 50, 20)), MascotMood.excited);
      expect(mood(month(100, 60, 0)), MascotMood.happy);
      expect(mood(month(100, 90, 0)), MascotMood.calm);
    });

    test('analysis names the biggest category', () {
      const expenses = [
        CategoryExpense(
          categoryId: 'a',
          categoryName: 'Transporte',
          icon: 'directions_bus',
          total: 20,
          percentage: 25,
        ),
        CategoryExpense(
          categoryId: 'b',
          categoryName: 'Comida',
          icon: 'lunch_dining',
          total: 60,
          percentage: 75,
        ),
      ];
      const efficiency = SavingsEfficiency(
        totalIncome: 200,
        totalSaved: 60,
        efficiencyPercent: 30,
      );
      final tip = analysisTip(expenses, efficiency);
      expect(tip.mood, MascotMood.excited);
      expect(tip.messages.first, contains('Comida'));
      expect(tip.messages, contains(contains('Transporte')));
    });

    test('budgets: exceeded ones worry Michi, near ones get a warning', () {
      Budget budget(String name, double amount, double spent) => Budget(
        category: Category(
          id: name,
          name: name,
          icon: 'x',
          type: TransactionType.expense,
          isDefault: true,
        ),
        amount: amount,
        spent: spent,
      );
      final budgets = [
        budget('Comida', 100, 130),
        budget('Transporte', 50, 45),
        budget('Ropa', 80, 10),
      ];
      expect(budgetMessages(budgets), [
        r'Te pasaste del presupuesto de Comida por $30.00.',
        'Ojo: ya usaste el 90% del presupuesto de Transporte.',
      ]);
      final tip = homeTip(
        month: month(100, 50, 20),
        balance: 100,
        hasActivity: true,
        goalCount: 1,
        budgets: budgets,
      );
      expect(tip.mood, MascotMood.worried);
      expect(tip.messages.first, contains('Comida'));

      const efficiency = SavingsEfficiency(
        totalIncome: 200,
        totalSaved: 60,
        efficiencyPercent: 30,
      );
      final analysis = analysisTip(const [], efficiency, budgets: budgets);
      expect(analysis.mood, MascotMood.worried);
      expect(analysis.messages.first, contains('Te pasaste'));
    });
  });
}
