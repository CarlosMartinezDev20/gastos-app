import 'category.dart';

class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final DateTime date;
  final Category category;

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: TransactionTypeApi.fromApi(json['type'] as String),
    date: DateTime.parse(json['date'] as String),
    category: Category.fromJson(json['category'] as Map<String, dynamic>),
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
