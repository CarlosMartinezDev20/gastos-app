import '../../models/category.dart';
import '../../models/transaction.dart';

/// Totals for a recent period. Goal contributions count as [saved],
/// not as spending.
class PeriodSummary {
  const PeriodSummary({
    required this.income,
    required this.spent,
    required this.saved,
  });

  final double income;
  final double spent;
  final double saved;
}

/// Totals for the last [days] local days, today included. A rolling window
/// keeps the summary meaningful at the start of a month.
PeriodSummary recentSummary(
  List<Transaction> items,
  DateTime now, {
  int days = 30,
}) {
  final start = DateTime(now.year, now.month, now.day - (days - 1));
  return _summaryBetween(items, start, null);
}

/// This calendar month so far, and the previous month up to the same day
/// (clamped to its length), to compare how the month is going.
({PeriodSummary current, PeriodSummary previous}) monthToDate(
  List<Transaction> items,
  DateTime now,
) {
  final start = DateTime(now.year, now.month);
  final previousStart = DateTime(now.year, now.month - 1);
  final previousLength = DateTime(now.year, now.month, 0).day;
  final previousEnd = DateTime(
    now.year,
    now.month - 1,
    (now.day < previousLength ? now.day : previousLength) + 1,
  );
  return (
    current: _summaryBetween(items, start, null),
    previous: _summaryBetween(items, previousStart, previousEnd),
  );
}

/// Local [start] inclusive, [end] exclusive (null: no end).
PeriodSummary _summaryBetween(
  List<Transaction> items,
  DateTime start,
  DateTime? end,
) {
  var income = 0.0, spent = 0.0, saved = 0.0;
  for (final t in items) {
    final date = t.date.toLocal();
    if (date.isBefore(start) || (end != null && !date.isBefore(end))) {
      continue;
    }
    if (t.type == TransactionType.income) {
      income += t.amount;
    } else if (t.isGoalContribution) {
      saved += t.amount;
    } else {
      spent += t.amount;
    }
  }
  return PeriodSummary(income: income, spent: spent, saved: saved);
}

class DaySpending {
  const DaySpending(this.day, this.amount);

  /// Local midnight of the day.
  final DateTime day;
  final double amount;
}

/// Spending (expenses minus goal contributions) for the last 7 local days,
/// oldest first; the last entry is today.
List<DaySpending> lastSevenDays(List<Transaction> items, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final days = [
    for (var i = 6; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
  final totals = {for (final d in days) d: 0.0};
  for (final t in items) {
    if (t.type != TransactionType.expense || t.isGoalContribution) continue;
    final local = t.date.toLocal();
    final key = DateTime(local.year, local.month, local.day);
    if (totals.containsKey(key)) totals[key] = totals[key]! + t.amount;
  }
  return [for (final d in days) DaySpending(d, totals[d]!)];
}

/// Time span shown by the cash-flow chart.
enum FlowPeriod { week, month, year }

/// Income and spending for one bar group of the cash-flow chart.
class FlowBucket {
  const FlowBucket(this.start, this.income, this.spent);

  /// Local midnight of the first day in the bucket.
  final DateTime start;
  final double income;
  final double spent;
}

/// Income vs spending (goal contributions excluded), oldest first and ending
/// today: 7 days, the last 4 weeks of 7 days, or the last 12 months.
List<FlowBucket> flowBuckets(
  List<Transaction> items,
  DateTime now,
  FlowPeriod period,
) {
  final today = DateTime(now.year, now.month, now.day);
  final starts = switch (period) {
    FlowPeriod.week => [
      for (var i = 6; i >= 0; i--)
        DateTime(today.year, today.month, today.day - i),
    ],
    FlowPeriod.month => [
      for (var i = 3; i >= 0; i--)
        DateTime(today.year, today.month, today.day - 6 - 7 * i),
    ],
    FlowPeriod.year => [
      for (var i = 11; i >= 0; i--) DateTime(today.year, today.month - i),
    ],
  };
  final income = List.filled(starts.length, 0.0);
  final spent = List.filled(starts.length, 0.0);
  final end = DateTime(today.year, today.month, today.day + 1);
  for (final t in items) {
    if (t.isGoalContribution) continue;
    final local = t.date.toLocal();
    if (local.isBefore(starts.first) || !local.isBefore(end)) continue;
    final index = starts.lastIndexWhere((s) => !local.isBefore(s));
    if (t.type == TransactionType.income) {
      income[index] += t.amount;
    } else {
      spent[index] += t.amount;
    }
  }
  return [
    for (var i = 0; i < starts.length; i++)
      FlowBucket(starts[i], income[i], spent[i]),
  ];
}

/// A round step for a chart axis that reaches [max] in about [ticks] steps:
/// 1, 2, 2.5 or 5 times a power of ten ($10, $25, $50…).
double niceAxisStep(double max, {int ticks = 3}) {
  if (max <= 0) return 1;
  final raw = max / ticks;
  var magnitude = 1.0;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  while (magnitude > raw) {
    magnitude /= 10;
  }
  for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (magnitude * factor >= raw) return magnitude * factor;
  }
  return magnitude * 10;
}
