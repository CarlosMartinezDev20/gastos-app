import 'package:appgastos/models/budget.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/metrics.dart';
import 'package:appgastos/models/payment_method.dart';
import 'package:appgastos/models/recurring.dart';
import 'package:appgastos/models/savings_goal.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:appgastos/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses API contract models used by the app', () {
    final user = UserProfile.fromJson({
      'id': 'user-1',
      'name': 'Daniela',
      'email': 'daniela@universidad.edu',
      'avatarUrl': null,
      'darkMode': false,
      'createdAt': '2026-05-21T12:00:00.000Z',
      'updatedAt': '2026-05-21T12:00:00.000Z',
    });
    expect(user.name, 'Daniela');

    final category = Category.fromJson({
      'id': 'cat-1',
      'name': 'Mesada',
      'icon': 'savings',
      'type': 'INCOME',
      'isDefault': true,
      'userId': null,
      'transactionCount': 2,
    });
    expect(category.type, TransactionType.income);
    expect(category.transactionCount, 2);
    expect(category.editable, isFalse);

    final budget = Budget.fromJson({
      'id': 'budget-1',
      'categoryId': 'cat-2',
      'category': {
        'id': 'cat-2',
        'name': 'Comida',
        'icon': 'lunch_dining',
        'type': 'EXPENSE',
        'isDefault': true,
        'userId': null,
      },
      'amount': 100,
      'spent': 85,
      'remaining': 15,
      'percent': 85,
    });
    expect(budget.nearLimit, isTrue);
    expect(budget.remaining, 15);

    final transaction = Transaction.fromJson({
      'id': 'tx-1',
      'title': 'Mesada',
      'amount': 150,
      'type': 'INCOME',
      'date': '2026-05-21T12:00:00.000Z',
      'category': {
        'id': 'cat-1',
        'name': 'Mesada',
        'icon': 'savings',
        'type': 'INCOME',
        'isDefault': true,
      },
    });
    expect(transaction.amount, 150);

    final rule = RecurringRule.fromJson({
      'paymentMethodId': 'pm-1',
      'id': 'r1',
      'userId': 'user-1',
      'categoryId': 'cat-1',
      'title': 'Mesada',
      'amount': 150,
      'type': 'INCOME',
      'frequency': 'MONTHLY',
      'anchorDay': 1,
      'nextDate': '2026-11-01T12:00:00.000Z',
      'active': true,
      'category': {
        'id': 'cat-1',
        'name': 'Mesada',
        'icon': 'savings',
        'type': 'INCOME',
        'isDefault': true,
      },
    });
    expect(rule.frequency, RecurrenceFrequency.monthly);
    expect(rule.paymentMethodId, 'pm-1');

    final generated = Transaction.fromJson({
      'id': 'tx-2',
      'title': 'Mesada',
      'amount': 150,
      'type': 'INCOME',
      'date': '2026-10-01T12:00:00.000Z',
      'recurringId': 'r1',
      'goalId': null,
      'category': {
        'id': 'cat-1',
        'name': 'Mesada',
        'icon': 'savings',
        'type': 'INCOME',
        'isDefault': true,
      },
    });
    expect(generated.isRecurring, isTrue);

    final paid = Transaction.fromJson({
      'id': 'tx-3',
      'title': 'Super',
      'amount': 42.5,
      'type': 'EXPENSE',
      'date': '2026-10-02T12:00:00.000Z',
      'goalId': null,
      'recurringId': null,
      'paymentMethodId': 'pm-1',
      'reference': '9F3A1C2B-0D4E-4F5A-8B6C-7D8E9F0A1B2C',
      'category': {
        'id': 'cat-2',
        'name': 'Comida',
        'icon': 'lunch_dining',
        'type': 'EXPENSE',
        'isDefault': true,
      },
    });
    expect(paid.paymentMethodId, 'pm-1');
    expect(paid.reference, startsWith('9F3A'));

    // GET /payment-methods (one row as the API returns it).
    final card = PaymentMethod.fromJson({
      'id': 'pm-1',
      'userId': 'u1',
      'name': 'Visa prueba',
      'type': 'CREDIT_CARD',
      'brand': 'VISA',
      'last4': '4821',
      'bank': null,
      'color': 'ink',
      'creditLimit': 500,
      'statementDay': 15,
      'dueDay': 5,
      'createdAt': '2026-10-07T00:19:21.552Z',
      'updatedAt': '2026-10-07T00:19:21.552Z',
      'transactionCount': 3,
      'paidTotal': 120.5,
      'chargedTotal': 230.1,
    });
    expect(card.kind, PaymentMethodKind.creditCard);
    expect(card.brand, CardBrand.visa);
    expect(card.creditLimit, 500.0);
    expect(card.transactionCount, 3);
    expect(card.paidTotal, 120.5);
    expect(card.chargedTotal, 230.1);

    // POST /payment-methods/:id/payments (as the API returned it).
    final payment = CardPayment.fromJson({
      'id': 'cp-1',
      'userId': 'u1',
      'paymentMethodId': 'pm-1',
      'fromMethodId': 'pm-2',
      'amount': 120.5,
      'date': '2026-10-07T21:50:00.000Z',
      'createdAt': '2026-10-07T21:50:00.000Z',
    });
    expect(payment.amount, 120.5);
    expect(payment.fromMethodId, 'pm-2');
    expect(card.masked, '•••• 4821');

    final cash = PaymentMethod.fromJson({
      'id': 'pm-2',
      'name': 'Efectivo',
      'type': 'CASH',
      'brand': null,
      'last4': null,
      'bank': null,
      'color': 'mint',
      'creditLimit': null,
      'statementDay': null,
      'dueDay': null,
      'transactionCount': 0,
    });
    expect(cash.kind.isCard, isFalse);
    expect(cash.shortLabel, 'Efectivo');

    // The form never sends card or credit fields for cash.
    expect(
      const PaymentMethodInput(
        name: 'Efectivo',
        kind: PaymentMethodKind.cash,
        color: 'mint',
        last4: '1234',
        creditLimit: 10,
      ).toJson(),
      containsPair('last4', null),
    );

    final goal = SavingsGoal.fromJson({
      'id': 'goal-1',
      'name': 'Laptop',
      'targetAmount': 800,
      'savedAmount': 120,
      'icon': 'laptop_mac',
      'bgColor': 'bg-rose-500/10',
      'iconColor': 'text-rose-500',
      'progressPercent': 15,
    });
    expect(goal.progressPercent, 15);

    final metric = SavingsEfficiency.fromJson({
      'totalIncome': 150,
      'totalSaved': 30,
      'efficiencyPercent': 20,
    });
    expect(metric.message, contains('ahorro'));
  });
}
