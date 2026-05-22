import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/savings_goal.dart';
import '../providers/finance_providers.dart';

final savingsServiceProvider = Provider<SavingsService>((ref) {
  return SavingsService(ref);
});

class SavingsService {
  const SavingsService(this._ref);

  final Ref _ref;

  Future<SavingsGoal> createGoal({
    required String name,
    required double targetAmount,
    required String icon,
    required String bgColor,
    required String iconColor,
  }) {
    return _ref
        .read(financeRepositoryProvider)
        .createGoal(
          name: name,
          targetAmount: targetAmount,
          icon: icon,
          bgColor: bgColor,
          iconColor: iconColor,
        );
  }

  Future<SavingsGoal> addFunds(String goalId, double amount) {
    return _ref.read(financeRepositoryProvider).addFunds(goalId, amount);
  }
}
