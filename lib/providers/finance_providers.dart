import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../core/network/api_client.dart';
import '../core/utils/budget_planner.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/metrics.dart';
import '../models/recurring.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/payment_method.dart';
import '../repositories/finance_repository.dart';
import 'auth_provider.dart';
import 'history_provider.dart';
import 'storage_provider.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    ref.watch(apiClientProvider),
    ref.watch(authRepositoryProvider),
  );
});

final dashboardProvider = FutureProvider<DashboardData>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).dashboard();
});

final categoriesProvider = FutureProvider<List<Category>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).categories();
});

/// The recent movements (see [recentWindowStart]) that charts, the wallet,
/// Michi and the forms work from. Historial pages through all of them with
/// [historyProvider].
final transactionsProvider =
    FutureProvider.family<List<Transaction>, TransactionType?>((ref, type) {
      ref.watch(currentUserIdProvider);
      return ref
          .watch(financeRepositoryProvider)
          .transactions(type: type, from: recentWindowStart(DateTime.now()));
    });

final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).savingsGoals();
});

final categoryExpensesProvider = FutureProvider<List<CategoryExpense>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).categoryExpenses();
});

final savingsEfficiencyProvider = FutureProvider<SavingsEfficiency>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).savingsEfficiency();
});

/// This calendar month's budgets, in the user's time zone.
final budgetsProvider = FutureProvider<List<Budget>>((ref) {
  ref.watch(currentUserIdProvider);
  final now = DateTime.now();
  return ref
      .watch(financeRepositoryProvider)
      .budgets(DateTime(now.year, now.month));
});

/// The user's wallet: cards and other payment methods.
final paymentMethodsProvider = FutureProvider<List<PaymentMethod>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).paymentMethods();
});

/// Payments made to one credit card, newest first.
final cardPaymentsProvider = FutureProvider.family<List<CardPayment>, String>((
  ref,
  methodId,
) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).cardPayments(methodId);
});

final recurringProvider = FutureProvider<List<RecurringRule>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(financeRepositoryProvider).recurring();
});

/// Monthly income to compute budgets from: the incomes set up in the
/// calculator, or else the average of recent income movements.
final monthlyIncomeProvider = Provider<double>((ref) {
  final saved = decodeIncomeSources(
    ref.watch(sharedPreferencesProvider).getString(plannerIncomeKey),
  );
  if (saved != null) return monthlyIncome(saved);
  final transactions = ref.watch(transactionsProvider(null)).value ?? const [];
  return averageMonthlyIncome(transactions, DateTime.now());
});

void refreshFinance(WidgetRef ref) => _refreshAll(ref.invalidate);

/// [refreshFinance] for code that outlives its widget (e.g. an undo action
/// after the sheet that started it has closed).
void refreshFinanceIn(ProviderContainer container) =>
    _refreshAll(container.invalidate);

void _refreshAll(void Function(ProviderOrFamily provider) invalidate) {
  invalidate(paymentMethodsProvider);
  invalidate(cardPaymentsProvider);
  invalidate(recurringProvider);
  invalidate(budgetsProvider);
  invalidate(dashboardProvider);
  invalidate(categoriesProvider);
  invalidate(transactionsProvider);
  invalidate(historyProvider);
  invalidate(savingsGoalsProvider);
  invalidate(categoryExpensesProvider);
  invalidate(savingsEfficiencyProvider);
}
