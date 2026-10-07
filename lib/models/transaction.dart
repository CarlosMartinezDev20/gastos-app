import 'category.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    this.goalId,
    this.recurringId,
    this.paymentMethodId,
    this.reference,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final Category category;

  /// Set when this is a contribution to a savings goal (managed from Metas).
  final String? goalId;

  /// Set when a recurring rule created it.
  final String? recurringId;

  /// How it was paid (a method in the user's wallet).
  final String? paymentMethodId;

  /// Free reference, e.g. the generation code of a scanned invoice.
  final String? reference;

  bool get isGoalContribution => goalId != null;
  bool get isRecurring => recurringId != null;

  /// Money taken out of a goal: stored as a negative contribution.
  bool get isGoalWithdrawal => isGoalContribution && amount < 0;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: TransactionTypeApi.fromApi(json['type'] as String),
    date: DateTime.parse(json['date'] as String),
    category: Category.fromJson(json['category'] as Map<String, dynamic>),
    goalId: json['goalId'] as String?,
    recurringId: json['recurringId'] as String?,
    paymentMethodId: json['paymentMethodId'] as String?,
    reference: json['reference'] as String?,
  );
}

class BalanceSummary {
  const BalanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  final double totalIncome;
  final double totalExpense;
  final double balance;

  factory BalanceSummary.fromJson(Map<String, dynamic> json) => BalanceSummary(
    totalIncome: (json['totalIncome'] as num).toDouble(),
    totalExpense: (json['totalExpense'] as num).toDouble(),
    balance: (json['balance'] as num).toDouble(),
  );
}
