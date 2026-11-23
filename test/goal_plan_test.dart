import 'package:appgastos/core/utils/goal_plan.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/savings_goal.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

final now = DateTime(2026, 10, 24, 15);

SavingsGoal goal({double saved = 200, DateTime? targetDate}) => SavingsGoal(
  id: 'g1',
  name: 'Laptop',
  targetAmount: 800,
  savedAmount: saved,
  icon: 'laptop_mac',
  bgColor: '',
  iconColor: '',
  progressPercent: saved / 8,
  targetDate: targetDate,
);

Transaction contribution(
  double amount,
  DateTime date, {
  String goalId = 'g1',
}) => Transaction(
  id: '$amount-$date',
  title: 'Ahorro: Laptop',
  amount: amount,
  type: TransactionType.expense,
  date: date,
  category: savingsCategory,
  goalId: goalId,
);

void main() {
  test('parses and writes the API calendar day', () {
    expect(parseApiDay('2027-02-28'), DateTime(2027, 2, 28));
    expect(parseApiDay(null), isNull);
    expect(apiDay(DateTime(2027, 2, 8, 23)), '2027-02-08');
  });

  test('a finished goal is done', () {
    final plan = goalPlan(goal(saved: 800), const [], now: now);
    expect(plan.status, GoalStatus.done);
    expect(plan.remaining, 0);
  });

  test('without a date it projects from the recent pace', () {
    // 300 over the last 90 days → 100 a month → 600 left takes 6 months.
    final plan = goalPlan(goal(), [
      contribution(150, DateTime(2026, 7, 27)),
      contribution(150, DateTime(2026, 10, 1)),
      contribution(999, DateTime(2026, 1, 1)), // outside the window
      contribution(50, DateTime(2026, 10, 1), goalId: 'other'),
    ], now: now);
    expect(plan.status, GoalStatus.open);
    expect(plan.monthlyPace, closeToDouble(100));
    expect(
      plan.projectedDate,
      DateTime(2026, 10, 24).add(const Duration(days: 180)),
    );
  });

  test('a recent first contribution counts at least a month', () {
    final plan = goalPlan(goal(), [contribution(100, now)], now: now);
    expect(plan.monthlyPace, closeToDouble(100));
  });

  test('withdrawals lower the pace', () {
    final plan = goalPlan(goal(), [
      contribution(300, DateTime(2026, 8, 1)),
      contribution(-300, DateTime(2026, 9, 1)),
    ], now: now);
    expect(plan.monthlyPace, 0);
    expect(plan.projectedDate, isNull);
  });

  test('with a date it asks for an amount per month', () {
    // Oct 24 → Apr 30: 6 whole months for the 600 left.
    final target = DateTime(2027, 4, 30);
    final plan = goalPlan(goal(targetDate: target), const [], now: now);
    expect(plan.status, GoalStatus.notStarted);
    expect(plan.monthsLeft, 6);
    expect(plan.perMonth, 100);
  });

  test('on track or behind depending on the pace', () {
    final target = DateTime(2027, 3, 31);
    final steady = [
      contribution(150, DateTime(2026, 7, 27)),
      contribution(150, DateTime(2026, 10, 1)),
    ];
    expect(
      goalPlan(goal(targetDate: target), steady, now: now).status,
      GoalStatus.behind, // 100/month → 180 days, past Mar 31
    );
    expect(
      goalPlan(
        goal(targetDate: DateTime(2027, 6, 30)),
        steady,
        now: now,
      ).status,
      GoalStatus.onTrack,
    );
  });

  test('a close date still counts one month', () {
    final plan = goalPlan(
      goal(targetDate: DateTime(2026, 11, 2)),
      const [],
      now: now,
    );
    expect(plan.monthsLeft, 1);
    expect(plan.perMonth, 600);
  });

  test('today is still in time, yesterday is overdue', () {
    expect(
      goalPlan(
        goal(targetDate: DateTime(2026, 10, 24)),
        const [],
        now: now,
      ).status,
      GoalStatus.notStarted,
    );
    expect(
      goalPlan(
        goal(targetDate: DateTime(2026, 10, 23)),
        const [],
        now: now,
      ).status,
      GoalStatus.overdue,
    );
  });
}

Matcher closeToDouble(double value) => closeTo(value, 0.01);
