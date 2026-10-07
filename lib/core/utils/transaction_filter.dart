import '../../models/category.dart';
import '../../models/transaction.dart';

/// Filters calendar dates inclusively in the user's local time zone.
List<Transaction> filterTransactions(
  List<Transaction> items, {
  String query = '',
  TransactionType? type,
  DateTime? from,
  DateTime? to,
}) {
  final search = _normalize(query.trim());
  final start = from == null ? null : DateTime(from.year, from.month, from.day);
  final end = to == null ? null : DateTime(to.year, to.month, to.day + 1);
  return items.where((item) {
    final date = item.date.toLocal();
    return (type == null || item.type == type) &&
        (start == null || !date.isBefore(start)) &&
        (end == null || date.isBefore(end)) &&
        (search.isEmpty ||
            _normalize('${item.title} ${item.category.name}').contains(search));
  }).toList()..sort((a, b) => b.date.compareTo(a.date));
}

String _normalize(String value) {
  var result = value.toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  for (final entry in accents.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  return result;
}
