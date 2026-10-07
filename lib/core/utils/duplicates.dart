import '../../models/category.dart';
import '../../models/transaction.dart';

String _fold(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úù]'), 'u')
    .replaceAll(RegExp(r'[^a-z0-9ñ ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _sameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// An existing movement that looks like the one about to be saved — e.g.
/// the same receipt scanned twice: same type, amount and day, and the same
/// invoice reference or merchant. Null when nothing matches.
Transaction? findLikelyDuplicate({
  required List<Transaction> existing,
  required TransactionType type,
  required double amount,
  required DateTime date,
  required String title,
  String? reference,
}) {
  final name = _fold(title);
  for (final t in existing) {
    if (t.type != type || t.isGoalContribution) continue;
    if ((t.amount - amount).abs() >= .005 || !_sameDay(t.date, date)) {
      continue;
    }
    if (reference != null && t.reference != null) {
      // Two different invoices can share an amount and a day.
      if (t.reference == reference) return t;
      continue;
    }
    final other = _fold(t.title);
    if (name.isEmpty || other.isEmpty) continue;
    if (name == other || name.contains(other) || other.contains(name)) {
      return t;
    }
  }
  return null;
}
