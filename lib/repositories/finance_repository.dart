import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/metrics.dart';
import '../models/recurring.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/transaction_page.dart';
import '../models/user_profile.dart';
import '../models/payment_method.dart';
import 'auth_repository.dart';

/// Where the movements the app keeps in memory start: this month and the
/// twelve before it, enough for every chart, average and statement.
/// Historial pages through the rest.
DateTime recentWindowStart(DateTime now) => DateTime(now.year - 1, now.month);

class FinanceRepository {
  const FinanceRepository(this._api, this._auth);

  final ApiClient _api;
  final AuthRepository _auth;

  Future<DashboardData> dashboard() async {
    final results = await Future.wait<dynamic>([
      _auth.profile(),
      balance(),
      savingsGoals(),
      transactions(from: recentWindowStart(DateTime.now())),
    ]);
    return DashboardData(
      user: results[0] as UserProfile,
      balance: results[1] as BalanceSummary,
      goals: results[2] as List<SavingsGoal>,
      transactions: results[3] as List<Transaction>,
    );
  }

  Future<List<Category>> categories() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.categories);
      return (response.data as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<Category> createCategory({
    required String name,
    required String icon,
    required TransactionType type,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.categories,
        data: {'name': name, 'icon': icon, 'type': type.apiValue},
      );
      return Category.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<Category> updateCategory(
    String id, {
    required String name,
    required String icon,
    required TransactionType type,
  }) async {
    try {
      final response = await _api.dio.patch(
        ApiEndpoints.category(id),
        data: {'name': name, 'icon': icon, 'type': type.apiValue},
      );
      return Category.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _api.dio.delete(ApiEndpoints.category(id));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  /// Budgets with what was spent since [monthStart] (local start of month).
  Future<List<Budget>> budgets(DateTime monthStart) async {
    try {
      final response = await _api.dio.get(
        ApiEndpoints.budgets,
        queryParameters: {'from': monthStart.toUtc().toIso8601String()},
      );
      return (response.data as List)
          .map((e) => Budget.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> setBudget(String categoryId, double amount) async {
    try {
      await _api.dio.put(
        ApiEndpoints.budget(categoryId),
        data: {'amount': amount},
      );
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> deleteBudget(String categoryId) async {
    try {
      await _api.dio.delete(ApiEndpoints.budget(categoryId));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<List<RecurringRule>> recurring() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.recurring);
      return (response.data as List)
          .map((e) => RecurringRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<RecurringRule> createRecurring({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required RecurrenceFrequency frequency,
    required DateTime startDate,
    String? paymentMethodId,
    String? service,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.recurring,
        data: {
          'title': title,
          'amount': amount,
          'type': type.apiValue,
          'categoryId': categoryId,
          'frequency': frequency.apiValue,
          'startDate': startDate.toUtc().toIso8601String(),
          'paymentMethodId': ?paymentMethodId,
          'service': ?service,
        },
      );
      return RecurringRule.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<RecurringRule> updateRecurring(
    String id, {
    String? title,
    double? amount,
    RecurrenceFrequency? frequency,
    bool? active,
    // Sent (null clears it) only when true; other fields skip nulls.
    bool setPaymentMethod = false,
    String? paymentMethodId,
  }) async {
    try {
      final response = await _api.dio.patch(
        ApiEndpoints.recurringRule(id),
        data: {
          'title': ?title,
          'amount': ?amount,
          'frequency': ?frequency?.apiValue,
          'active': ?active,
          if (setPaymentMethod) 'paymentMethodId': paymentMethodId,
        },
      );
      return RecurringRule.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> deleteRecurring(String id) async {
    try {
      await _api.dio.delete(ApiEndpoints.recurringRule(id));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  /// Movements newest first; [from]/[to] are instants. Without [from] it
  /// brings all of them, so screens pass [recentWindowStart].
  Future<List<Transaction>> transactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiEndpoints.transactions,
        queryParameters: {
          if (type != null) 'type': type.apiValue,
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
        },
      );
      return (response.data as List)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  /// One page of Historial; pass the previous page's `nextCursor` for the
  /// next one.
  Future<TransactionPage> transactionPage(
    HistoryQuery query, {
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final response = await _api.dio.get(
        ApiEndpoints.transactionPage,
        queryParameters: {
          ...query.apiParams,
          'limit': limit,
          'cursor': ?cursor,
        },
      );
      return TransactionPage.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<BalanceSummary> balance() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.balance);
      return BalanceSummary.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<Transaction> createTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
    String? paymentMethodId,
    String? reference,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.transactions,
        data: {
          'title': title,
          'amount': amount,
          'type': type.apiValue,
          'categoryId': categoryId,
          'date': date.toUtc().toIso8601String(),
          'paymentMethodId': ?paymentMethodId,
          'reference': ?reference,
        },
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<Transaction> updateTransaction(
    String id, {
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
    String? paymentMethodId,
    String? reference,
  }) async {
    try {
      final response = await _api.dio.patch(
        ApiEndpoints.transaction(id),
        data: {
          'title': title,
          'amount': amount,
          'type': type.apiValue,
          'categoryId': categoryId,
          'date': date.toUtc().toIso8601String(),
          // Sent even when null: the form shows them, so null clears them.
          'paymentMethodId': paymentMethodId,
          'reference': reference,
        },
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await _api.dio.delete(ApiEndpoints.transaction(id));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<List<PaymentMethod>> paymentMethods() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.paymentMethods);
      return (response.data as List)
          .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<PaymentMethod> createPaymentMethod(PaymentMethodInput input) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.paymentMethods,
        data: input.toJson(),
      );
      return PaymentMethod.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<PaymentMethod> updatePaymentMethod(
    String id,
    PaymentMethodInput input,
  ) async {
    try {
      final response = await _api.dio.patch(
        ApiEndpoints.paymentMethod(id),
        data: input.toJson(),
      );
      return PaymentMethod.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<List<CardPayment>> cardPayments(String methodId) async {
    try {
      final response = await _api.dio.get(ApiEndpoints.cardPayments(methodId));
      return (response.data as List)
          .map((e) => CardPayment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  /// A payment to a credit card: lowers what's owed, not the balance.
  Future<CardPayment> addCardPayment(
    String methodId, {
    required double amount,
    required DateTime date,
    String? fromMethodId,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.cardPayments(methodId),
        data: {
          'amount': amount,
          'date': date.toUtc().toIso8601String(),
          'fromMethodId': ?fromMethodId,
        },
      );
      return CardPayment.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> deleteCardPayment(String id) async {
    try {
      await _api.dio.delete(ApiEndpoints.cardPayment(id));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  /// Its movements stay, without a payment method.
  Future<void> deletePaymentMethod(String id) async {
    try {
      await _api.dio.delete(ApiEndpoints.paymentMethod(id));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<List<SavingsGoal>> savingsGoals() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.savingsGoals);
      return (response.data as List)
          .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<SavingsGoal> createGoal({
    required String name,
    required double targetAmount,
    required String icon,
    required String bgColor,
    required String iconColor,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.savingsGoals,
        data: {
          'name': name,
          'targetAmount': targetAmount,
          'icon': icon,
          'bgColor': bgColor,
          'iconColor': iconColor,
        },
      );
      return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<SavingsGoal> updateGoal(
    String id, {
    required String name,
    required double targetAmount,
    required String icon,
  }) async {
    try {
      final response = await _api.dio.patch(
        ApiEndpoints.savingsGoal(id),
        data: {'name': name, 'targetAmount': targetAmount, 'icon': icon},
      );
      return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> deleteGoal(String id) async {
    try {
      await _api.dio.delete(ApiEndpoints.savingsGoal(id));
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<SavingsGoal> addFunds(String goalId, double amount) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.addGoalFunds(goalId),
        data: {'amount': amount},
      );
      return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<SavingsGoal> withdrawFromGoal(String goalId, double amount) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.withdrawGoalFunds(goalId),
        data: {'amount': amount},
      );
      return SavingsGoal.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<List<CategoryExpense>> categoryExpenses() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.categoryExpenses);
      return (response.data as List)
          .map((e) => CategoryExpense.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<SavingsEfficiency> savingsEfficiency() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.savingsEfficiency);
      return SavingsEfficiency.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }
}
