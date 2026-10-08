import 'category.dart';
import 'transaction.dart';

/// Historial's filters. A record, so equal filters share one page list.
/// [from]/[to] are calendar days in the user's time zone, both included.
typedef HistoryQuery = ({
  String search,
  TransactionType? type,
  DateTime? from,
  DateTime? to,
});

const HistoryQuery noHistoryFilters = (
  search: '',
  type: null,
  from: null,
  to: null,
);

extension HistoryQueryX on HistoryQuery {
  bool get hasFilters =>
      search.trim().isNotEmpty || type != null || from != null || to != null;

  /// The API's filters: local days become UTC instants.
  Map<String, String> get apiParams => {
    if (search.trim().isNotEmpty) 'q': search.trim(),
    if (type != null) 'type': type!.apiValue,
    if (from case final f?)
      'from': DateTime(f.year, f.month, f.day).toUtc().toIso8601String(),
    if (to case final t?)
      'to': DateTime(
        t.year,
        t.month,
        t.day + 1,
      ).subtract(const Duration(milliseconds: 1)).toUtc().toIso8601String(),
  };
}

/// Totals of everything that matches the filters, not just the loaded page.
class HistorySummary {
  const HistorySummary({
    required this.count,
    required this.income,
    required this.expense,
  });

  final int count;
  final double income;
  final double expense;

  factory HistorySummary.fromJson(Map<String, dynamic> json) => HistorySummary(
    count: json['count'] as int,
    income: (json['income'] as num).toDouble(),
    expense: (json['expense'] as num).toDouble(),
  );
}

/// One page of `GET /transactions/page`, newest first.
class TransactionPage {
  const TransactionPage({required this.items, this.nextCursor, this.summary});

  final List<Transaction> items;

  /// Null on the last page.
  final String? nextCursor;

  /// Only on the first page.
  final HistorySummary? summary;

  factory TransactionPage.fromJson(Map<String, dynamic> json) =>
      TransactionPage(
        items: (json['items'] as List)
            .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
        summary: json['summary'] == null
            ? null
            : HistorySummary.fromJson(json['summary'] as Map<String, dynamic>),
      );
}
