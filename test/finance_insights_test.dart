import 'package:appgastos/core/utils/finance_insights.dart';
import 'package:appgastos/core/utils/mascot_insights.dart';
import 'package:appgastos/models/budget.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/metrics.dart';
import 'package:appgastos/models/savings_goal.dart';
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

  test('month to date compares with the previous month at the same day', () {
    final month = monthToDate([
      tx(300, DateTime(2026, 10, 1), category: salary),
      tx(30, DateTime(2026, 10, 15, 20)),
      tx(20, DateTime(2026, 9, 30, 23)), // last month, after its day 15
      tx(40, DateTime(2026, 9, 15, 23)), // last month, up to its day 15
    ], now);
    expect(month.current.income, 300);
    expect(month.current.spent, 30);
    expect(month.previous.spent, 40);

    // March 31 compares with all of February.
    final march = monthToDate([
      tx(10, DateTime(2026, 2, 28, 12)),
      tx(5, DateTime(2026, 3, 1)),
    ], DateTime(2026, 3, 31));
    expect(march.previous.spent, 10);
    expect(march.current.spent, 5);
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
      // A quiet month isn't "0% of your income".
      expect(mood(month(0, 0, 0)), MascotMood.calm);
      expect(
        homeTip(
          month: month(0, 0, 0),
          balance: 100,
          hasActivity: true,
          goalCount: 1,
        ).messages.join(),
        isNot(contains('%')),
      );
    });

    test('goals that are late or behind join the home messages', () {
      SavingsGoal goal(String name, DateTime date) => SavingsGoal(
        id: name,
        name: name,
        targetAmount: 600,
        savedAmount: 0,
        icon: 'x',
        bgColor: '',
        iconColor: '',
        progressPercent: 0,
        targetDate: date,
      );
      final now = DateTime(2026, 10, 24);
      final contribution = Transaction(
        id: 't',
        title: 'Ahorro: Viaje',
        amount: 50,
        type: TransactionType.expense,
        date: DateTime(2026, 10, 1),
        category: const Category(
          id: 's',
          name: 'Ahorro',
          icon: 'x',
          type: TransactionType.expense,
          isDefault: true,
        ),
        goalId: 'Viaje',
      );
      final alerts = goalMessages(
        [
          goal('Viaje', DateTime(2027, 4, 30)), // 50/month, needs 100
          goal('Laptop', DateTime(2026, 10, 1)), // date passed
          goal('Moto', DateTime(2027, 4, 30)), // no contributions yet
        ],
        [contribution],
        now: now,
      );
      expect(alerts, [
        r'Para llegar a "Viaje" a tiempo aparta $100.00 al mes.',
        'Se pasó la fecha de "Laptop". ¿Le ponemos una nueva?',
      ]);
      final tip = homeTip(
        month: month(100, 60, 0),
        balance: 100,
        hasActivity: true,
        goalCount: 3,
        goalAlerts: alerts,
      );
      expect(tip.mood, MascotMood.happy);
      expect(tip.messages.skip(1).take(2), alerts);
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

  test('niceAxisStep picks round steps that reach the top in about 3', () {
    expect(niceAxisStep(0), 1);
    expect(niceAxisStep(73.17), 25);
    expect(niceAxisStep(296), 100);
    expect(niceAxisStep(30), 10);
    expect(niceAxisStep(5.4), 2);
    expect(niceAxisStep(1200), 500);
    for (final max in [3.0, 47.0, 180.0, 999.0, 12345.0]) {
      final step = niceAxisStep(max);
      expect(max / step, inInclusiveRange(1.2, 3.0001));
    }
  });
}
