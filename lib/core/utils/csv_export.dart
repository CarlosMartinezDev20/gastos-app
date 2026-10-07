import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/transaction.dart';

/// Movements as CSV (comma separated, UTF-8 with BOM so Excel shows accents).
/// Amounts are signed: income and goal withdrawals positive, spending and
/// goal contributions negative.
String transactionsToCsv(List<Transaction> transactions) {
  final date = DateFormat('yyyy-MM-dd');
  String cell(String value) {
    final needsQuotes = value.contains(RegExp('[",\n\r]'));
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  final rows = [
    ['Fecha', 'Descripción', 'Categoría', 'Tipo', 'Monto'],
    for (final t in transactions)
      [
        date.format(t.date.toLocal()),
        t.title,
        t.category.name,
        t.isGoalContribution
            ? (t.isGoalWithdrawal ? 'Retiro de meta' : 'Aporte a meta')
            : t.type.label,
        (t.type == TransactionType.income
                ? t.amount
                : t.isGoalWithdrawal
                ? t.amount.abs()
                : -t.amount)
            .toStringAsFixed(2),
      ],
  ];
  return '﻿${rows.map((r) => r.map(cell).join(',')).join('\r\n')}\r\n';
}

/// File name like `movimientos-2026-10-03.csv`.
String csvFileName(DateTime now) =>
    'movimientos-${DateFormat('yyyy-MM-dd').format(now)}.csv';
