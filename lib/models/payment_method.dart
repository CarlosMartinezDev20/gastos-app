/// How a payment method works; maps to the API's `PaymentMethodType`.
enum PaymentMethodKind {
  creditCard('CREDIT_CARD', 'Crédito'),
  debitCard('DEBIT_CARD', 'Débito'),
  cash('CASH', 'Efectivo'),
  digital('DIGITAL', 'Digital');

  const PaymentMethodKind(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool get isCard => this == creditCard || this == debitCard;
  bool get isCredit => this == creditCard;

  /// Cards and digital wallets belong to a bank or provider; cash doesn't.
  bool get hasBank => this != cash;

  static PaymentMethodKind fromApi(String value) =>
      values.firstWhere((k) => k.apiValue == value);
}

enum CardBrand {
  visa('VISA', 'Visa'),
  mastercard('MASTERCARD', 'Mastercard'),
  amex('AMEX', 'American Express'),
  other('OTHER', 'Otra');

  const CardBrand(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static CardBrand? fromApi(String? value) => value == null
      ? null
      : values.firstWhere((b) => b.apiValue == value, orElse: () => other);
}

/// A card or other way of paying in the user's wallet. The app never asks
/// for nor stores a card number: only its last four digits.
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    this.brand,
    this.last4,
    this.bank,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
    this.transactionCount = 0,
    this.paidTotal = 0,
  });

  final String id;
  final String name;
  final PaymentMethodKind kind;

  /// Key of the card art (see `walletCardStyles`).
  final String color;
  final CardBrand? brand;
  final String? last4;
  final String? bank;

  /// Credit cards only.
  final double? creditLimit;
  final int? statementDay;
  final int? dueDay;

  /// Movements paid with it.
  final int transactionCount;

  /// Credit cards: everything paid to the card so far.
  final double paidTotal;

  /// "•••• 4821", or null without digits.
  String? get masked => last4 == null ? null : '•••• $last4';

  /// Short label for chips and rows: "Visa ··4821" or the name.
  String get shortLabel => last4 == null ? name : '$name ··$last4';

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: PaymentMethodKind.fromApi(json['type'] as String),
    color: json['color'] as String,
    brand: CardBrand.fromApi(json['brand'] as String?),
    last4: json['last4'] as String?,
    bank: json['bank'] as String?,
    creditLimit: (json['creditLimit'] as num?)?.toDouble(),
    statementDay: json['statementDay'] as int?,
    dueDay: json['dueDay'] as int?,
    transactionCount: json['transactionCount'] as int? ?? 0,
    paidTotal: (json['paidTotal'] as num?)?.toDouble() ?? 0,
  );
}

/// What the wallet form sends; fields that don't apply to [kind] are left
/// out (the API clears them too).
class PaymentMethodInput {
  const PaymentMethodInput({
    required this.name,
    required this.kind,
    required this.color,
    this.brand,
    this.last4,
    this.bank,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
  });

  final String name;
  final PaymentMethodKind kind;
  final String color;
  final CardBrand? brand;
  final String? last4;
  final String? bank;
  final double? creditLimit;
  final int? statementDay;
  final int? dueDay;

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': kind.apiValue,
    'color': color,
    'brand': kind.isCard ? brand?.apiValue : null,
    'last4': kind.isCard ? last4 : null,
    'bank': kind.hasBank ? bank : null,
    'creditLimit': kind.isCredit ? creditLimit : null,
    'statementDay': kind.isCredit ? statementDay : null,
    'dueDay': kind.isCredit ? dueDay : null,
  };
}

/// A payment to a credit card. Not an expense (the purchases were): it
/// lowers what is owed on the card, not the balance.
class CardPayment {
  const CardPayment({
    required this.id,
    required this.paymentMethodId,
    required this.amount,
    required this.date,
    this.fromMethodId,
  });

  final String id;
  final String paymentMethodId;
  final double amount;
  final DateTime date;

  /// Where the money came from (debit, cash…), if known.
  final String? fromMethodId;

  factory CardPayment.fromJson(Map<String, dynamic> json) => CardPayment(
    id: json['id'] as String,
    paymentMethodId: json['paymentMethodId'] as String,
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
    fromMethodId: json['fromMethodId'] as String?,
  );
}
