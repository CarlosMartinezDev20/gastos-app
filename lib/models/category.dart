enum TransactionType { income, expense }

extension TransactionTypeApi on TransactionType {
  String get apiValue => this == TransactionType.income ? 'INCOME' : 'EXPENSE';
  String get label => this == TransactionType.income ? 'Ingreso' : 'Gasto';

  static TransactionType fromApi(String value) {
    return value == 'INCOME' ? TransactionType.income : TransactionType.expense;
  }
}

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.isDefault,
    this.transactionCount = 0,
  });

  final String id;
  final String name;
  final String icon;
  final TransactionType type;
  final bool isDefault;

  /// How many of the user's movements use it (from `GET /categories`).
  final int transactionCount;

  /// System categories are shared and read-only.
  bool get editable => !isDefault;

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    type: TransactionTypeApi.fromApi(json['type'] as String),
    isDefault: json['isDefault'] as bool? ?? false,
    transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
  );
}
