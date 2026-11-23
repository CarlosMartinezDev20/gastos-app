import '../../models/category.dart';
import '../../models/payment_method.dart';
import '../../models/transaction.dart';
import 'transaction_filter.dart';
import 'wallet.dart';

/// Suggestions come only from the user's own history and existing choices.
/// They never classify a movement until the user accepts the suggestion.
Category? suggestedCategory({
  required String title,
  required TransactionType type,
  required List<Category> categories,
  required List<Transaction> history,
}) {
  final allowed = {
    for (final c in categories.where((c) => c.type == type)) c.id: c,
  };
  final recent =
      history
          .where(
            (t) =>
                t.type == type &&
                !t.isGoalContribution &&
                allowed.containsKey(t.category.id),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  final name = normalizeText(title.trim());
  if (name.length >= 3) {
    final exact = recent.where((t) => normalizeText(t.title.trim()) == name);
    if (exact.isNotEmpty) return allowed[exact.first.category.id];
    // A different description is not evidence of the same category.
    return null;
  }
  return recent.isEmpty ? null : allowed[recent.first.category.id];
}

String? suggestedPaymentMethod({
  required String title,
  required TransactionType type,
  required List<PaymentMethod> methods,
  required List<Transaction> history,
}) {
  final name = normalizeText(title.trim());
  final matching = history
      .where(
        (t) => !t.isGoalContribution && normalizeText(t.title.trim()) == name,
      )
      .toList();
  return (name.length >= 3
          ? lastUsedPaymentMethodId(matching, methods, type)
          : null) ??
      lastUsedPaymentMethodId(
        history.where((t) => !t.isGoalContribution).toList(),
        methods,
        type,
      );
}
