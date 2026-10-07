import 'category.dart';

enum RecurrenceFrequency { weekly, monthly }

extension RecurrenceFrequencyApi on RecurrenceFrequency {
  String get apiValue =>
      this == RecurrenceFrequency.weekly ? 'WEEKLY' : 'MONTHLY';
  String get label =>
      this == RecurrenceFrequency.weekly ? 'Semanal' : 'Mensual';

  static RecurrenceFrequency fromApi(String value) => value == 'WEEKLY'
      ? RecurrenceFrequency.weekly
      : RecurrenceFrequency.monthly;
}

/// A movement the API creates every week or month (`/recurring`).
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.frequency,
    required this.nextDate,
    required this.active,
    this.paymentMethodId,
  });

  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final Category category;
  final RecurrenceFrequency frequency;

  /// When the next movement will be created.
  final DateTime nextDate;
  final bool active;

  /// Copied to each movement it creates.
  final String? paymentMethodId;

  factory RecurringRule.fromJson(Map<String, dynamic> json) => RecurringRule(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    type: TransactionTypeApi.fromApi(json['type'] as String),
    category: Category.fromJson(json['category'] as Map<String, dynamic>),
    frequency: RecurrenceFrequencyApi.fromApi(json['frequency'] as String),
    nextDate: DateTime.parse(json['nextDate'] as String),
    active: json['active'] as bool,
    paymentMethodId: json['paymentMethodId'] as String?,
  );
}
