import 'category.dart';

enum RecurrenceFrequency {
  weekly('WEEKLY', 'Semanal', 'cada semana', 52 / 12),
  monthly('MONTHLY', 'Mensual', 'cada mes', 1),
  yearly('YEARLY', 'Anual', 'cada año', 1 / 12);

  const RecurrenceFrequency(
    this.apiValue,
    this.label,
    this.every,
    this.perMonth,
  );

  final String apiValue;
  final String label;

  /// "cada semana", for sentences.
  final String every;

  /// Times it happens per month, to compare costs.
  final double perMonth;
}

extension RecurrenceFrequencyApi on RecurrenceFrequency {
  static RecurrenceFrequency fromApi(String value) =>
      RecurrenceFrequency.values.firstWhere(
        (f) => f.apiValue == value,
        orElse: () => RecurrenceFrequency.monthly,
      );
}

/// A movement the API creates every week, month or year (`/recurring`).
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
    this.service,
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

  /// Catalog key when it is a subscription (see `subscriptionCatalog`).
  final String? service;

  bool get isSubscription => service != null;

  /// What it costs per month, whatever its frequency.
  double get monthlyCost => amount * frequency.perMonth;

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
    service: json['service'] as String?,
  );
}
