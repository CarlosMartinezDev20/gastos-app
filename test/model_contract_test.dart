import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/metrics.dart';
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
    });
    expect(category.type, TransactionType.income);

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
