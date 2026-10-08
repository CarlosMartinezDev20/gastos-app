import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/payment_method.dart';
import '../../models/transaction.dart';

/// [day] of a month, clamped to its length (the 31st of a 30-day month is
/// the 30th). Month overflow rolls into the next or previous year.
DateTime dayOfMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(day, lastDay));
}

/// A span of local days: [start] inclusive, [end] exclusive.
typedef Period = ({DateTime start, DateTime end});

/// The open statement of a credit card that closes on [statementDay]: from
/// the day after its last closing through its next closing (inclusive).
Period statementPeriod(int statementDay, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var close = dayOfMonth(today.year, today.month, statementDay);
  if (today.isAfter(close)) {
    close = dayOfMonth(today.year, today.month + 1, statementDay);
  }
  final previous = dayOfMonth(close.year, close.month - 1, statementDay);
  return (
    start: DateTime(previous.year, previous.month, previous.day + 1),
    end: DateTime(close.year, close.month, close.day + 1),
  );
}

/// The calendar month of [now].
Period monthPeriod(DateTime now) => (
  start: DateTime(now.year, now.month),
  end: DateTime(now.year, now.month + 1),
);

/// The next date (today or later) that falls on [dueDay].
DateTime nextDueDate(int dueDay, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final due = dayOfMonth(today.year, today.month, dueDay);
  return today.isAfter(due)
      ? dayOfMonth(today.year, today.month + 1, dueDay)
      : due;
}

/// Whole days from [now]'s date to [date] (calendar days, DST-safe).
int daysUntil(DateTime date, DateTime now) => DateTime.utc(
  date.year,
  date.month,
  date.day,
).difference(DateTime.utc(now.year, now.month, now.day)).inDays;

/// What a wallet card shows: spending in its current period (the open
/// statement for credit cards with a closing day, the month otherwise),
/// how much of the limit that uses, and when the payment is due.
class WalletSummary {
  const WalletSummary({
    required this.method,
    required this.period,
    required this.spent,
    required this.movements,
    this.dueDate,
    this.debt,
    this.lastStatementSpent,
  });

  final PaymentMethod method;
  final Period period;

  /// Expenses paid with it in [period].
  final double spent;

  /// Its movements in [period], newest first.
  final List<Transaction> movements;
  final DateTime? dueDate;

  /// Credit cards: what is owed now — every purchase with it, minus refunds
  /// to it and payments made to it. Negative is money in your favor.
  final double? debt;

  /// Credit cards with a closing day: spending in the last closed
  /// statement (what the next payment is usually about).
  final double? lastStatementSpent;

  bool get byStatement => method.kind.isCredit && method.statementDay != null;

  double? get limit => method.kind.isCredit ? method.creditLimit : null;

  /// Limit left after what is owed (can go negative).
  double? get available => limit == null ? null : limit! - (debt ?? spent);

  /// Share of the limit in use (can pass 1).
  double? get utilization => limit == null || limit! <= 0
      ? null
      : ((debt ?? spent) / limit!).clamp(0, double.infinity).toDouble();

  /// The statement's closing date (its last day).
  DateTime? get closesOn =>
      byStatement ? period.end.subtract(const Duration(days: 1)) : null;

  /// "Corte del 15 oct" or "En octubre".
  String get periodLabel {
    if (closesOn case final close?) {
      return 'Corte del ${DateFormat("d MMM", 'es').format(close)}';
    }
    return 'En ${DateFormat('MMMM', 'es').format(period.start)}';
  }
}

WalletSummary summarizeMethod(
  PaymentMethod method,
  List<Transaction> transactions,
  DateTime now,
) {
  final period = method.kind.isCredit && method.statementDay != null
      ? statementPeriod(method.statementDay!, now)
      : monthPeriod(now);
  final movements = transactions.where((t) {
    if (t.paymentMethodId != method.id) return false;
    final date = t.date.toLocal();
    return !date.isBefore(period.start) && date.isBefore(period.end);
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
  final spent = _expensesIn(transactions, method.id, period);
  final credit = method.kind.isCredit;
  // All-time totals from the API: [transactions] are only the recent ones.
  // Rounded so cents from subtracting doubles don't show as a debt.
  final debt = credit
      ? ((method.chargedTotal - method.paidTotal) * 100).roundToDouble() / 100
      : null;
  return WalletSummary(
    method: method,
    period: period,
    spent: spent,
    movements: movements,
    dueDate: credit && method.dueDay != null
        ? nextDueDate(method.dueDay!, now)
        : null,
    debt: debt,
    lastStatementSpent: credit && method.statementDay != null
        ? _expensesIn(
            transactions,
            method.id,
            statementPeriod(
              method.statementDay!,
              period.start.subtract(const Duration(days: 1)),
            ),
          )
        : null,
  );
}

double _expensesIn(
  List<Transaction> transactions,
  String methodId,
  Period period,
) {
  var total = 0.0;
  for (final t in transactions) {
    if (t.paymentMethodId != methodId || t.type != TransactionType.expense) {
      continue;
    }
    final date = t.date.toLocal();
    if (!date.isBefore(period.start) && date.isBefore(period.end)) {
      total += t.amount;
    }
  }
  return total;
}

/// The method used in the newest movement of [type] that has one, if it is
/// still in the wallet: the movement form starts with it.
String? lastUsedPaymentMethodId(
  List<Transaction> transactions,
  List<PaymentMethod> methods,
  TransactionType type,
) {
  final ids = {for (final m in methods) m.id};
  final paid =
      transactions
          .where(
            (t) =>
                t.type == type &&
                t.paymentMethodId != null &&
                ids.contains(t.paymentMethodId),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  return paid.isEmpty ? null : paid.first.paymentMethodId;
}
