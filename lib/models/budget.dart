import 'category.dart';

/// Monthly spending limit on an expense category, with this month's spending.
class Budget {
  const Budget({
    required this.category,
    required this.amount,
    required this.spent,
  });

  final Category category;
  final double amount;
  final double spent;

  String get categoryId => category.id;
  double get remaining => amount - spent;

  /// Share of the limit already spent (can pass 1).
  double get progress => amount <= 0 ? 0 : spent / amount;
  bool get exceeded => spent > amount;

  /// 80% or more spent, still within the limit.
  bool get nearLimit => !exceeded && progress >= .8;

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    category: Category.fromJson(json['category'] as Map<String, dynamic>),
    amount: (json['amount'] as num).toDouble(),
    spent: (json['spent'] as num).toDouble(),
  );
}
