import 'dart:math' as math;

import '../../models/savings_goal.dart';
import '../../models/transaction.dart';

enum GoalStatus {
  /// Saved the whole target.
  done,

  /// No target date.
  open,

  /// Has a date but no recent contributions to judge the pace by.
  notStarted,

  /// At the recent pace it's reached by the date.
  onTrack,

  /// At the recent pace it's reached after the date.
  behind,

  /// The date passed without reaching it.
  overdue,
}

/// How a goal is going: what's left, what it takes per month to arrive by
/// its date and, at the pace of recent contributions, when it's reached.
class GoalPlan {
  const GoalPlan({
    required this.status,
    required this.remaining,
    required this.monthlyPace,
    this.monthsLeft,
    this.perMonth,
    this.projectedDate,
  });

  final GoalStatus status;
  final double remaining;

  /// Net contributions per month over the last [paceWindowDays] days.
  final double monthlyPace;

  /// Whole months until the target date (at least 1 while it's ahead).
  final int? monthsLeft;

  /// What to save each month from now to arrive by the target date.
  final double? perMonth;

  /// When it's reached at [monthlyPace]; null without a pace.
  final DateTime? projectedDate;
}

const paceWindowDays = 90;

GoalPlan goalPlan(
  SavingsGoal goal,
  List<Transaction> transactions, {
  required DateTime now,
}) {
  final remaining = math.max(0.0, goal.targetAmount - goal.savedAmount);
  final today = DateTime(now.year, now.month, now.day);
  final pace = _monthlyPace(goal.id, transactions, today);
  final projected = remaining > 0 && pace > 0
      ? today.add(Duration(days: (remaining / pace * 30).ceil()))
      : null;
  final target = goal.targetDate;

  if (remaining <= 0) {
    return GoalPlan(status: GoalStatus.done, remaining: 0, monthlyPace: pace);
  }
  if (target == null) {
    return GoalPlan(
      status: GoalStatus.open,
      remaining: remaining,
      monthlyPace: pace,
      projectedDate: projected,
    );
  }
  if (target.isBefore(today)) {
    return GoalPlan(
      status: GoalStatus.overdue,
      remaining: remaining,
      monthlyPace: pace,
      projectedDate: projected,
    );
  }
  final months = math.max(1, _wholeMonthsBetween(today, target));
  return GoalPlan(
    status: projected == null
        ? GoalStatus.notStarted
        : projected.isAfter(target)
        ? GoalStatus.behind
        : GoalStatus.onTrack,
    remaining: remaining,
    monthlyPace: pace,
    monthsLeft: months,
    perMonth: remaining / months,
    projectedDate: projected,
  );
}

/// Contributions minus withdrawals in the window, per 30 days. A goal whose
/// first contribution in the window is recent is measured from that day (but
/// over at least 30 days, so one deposit today isn't an infinite pace).
double _monthlyPace(String goalId, List<Transaction> all, DateTime today) {
  final start = today.subtract(const Duration(days: paceWindowDays));
  final end = today.add(const Duration(days: 1));
  var sum = 0.0;
  DateTime? first;
  for (final t in all) {
    if (t.goalId != goalId || t.date.isBefore(start) || !t.date.isBefore(end)) {
      continue;
    }
    sum += t.amount;
    if (first == null || t.date.isBefore(first)) first = t.date;
  }
  if (first == null || sum <= 0) return 0;
  final days = math.max(30, today.difference(first).inDays + 1);
  return sum / days * 30;
}

/// Full calendar months from [from] to [to] (Oct 24 → Dec 23 is 1).
int _wholeMonthsBetween(DateTime from, DateTime to) {
  var months = (to.year - from.year) * 12 + to.month - from.month;
  if (to.day < from.day) months--;
  return months;
}
