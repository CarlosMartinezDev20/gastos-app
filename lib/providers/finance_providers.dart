import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/metrics.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../repositories/finance_repository.dart';
import 'auth_provider.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
  );
});

final dashboardProvider = FutureProvider<DashboardData>((ref) {
  return ref.watch(financeRepositoryProvider).dashboard();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(financeRepositoryProvider).categories();
});

final transactionsProvider =
    FutureProvider.family<List<Transaction>, TransactionType?>((ref, type) {
      return ref.watch(financeRepositoryProvider).transactions(type: type);
    });

final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) {
  return ref.watch(financeRepositoryProvider).savingsGoals();
});

final categoryExpensesProvider = FutureProvider<List<CategoryExpense>>((ref) {
  return ref.watch(financeRepositoryProvider).categoryExpenses();
});

final savingsEfficiencyProvider = FutureProvider<SavingsEfficiency>((ref) {
  return ref.watch(financeRepositoryProvider).savingsEfficiency();
});

void refreshFinance(WidgetRef ref) {
  ref.invalidate(dashboardProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(savingsGoalsProvider);
  ref.invalidate(categoryExpensesProvider);
  ref.invalidate(savingsEfficiencyProvider);
}
