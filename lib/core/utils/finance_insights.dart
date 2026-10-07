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
  var income = 0.0, spent = 0.0, saved = 0.0;
  for (final t in items) {
    if (t.date.toLocal().isBefore(start)) continue;
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
