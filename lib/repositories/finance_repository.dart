import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/metrics.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';

class FinanceRepository {
  const FinanceRepository(this._api, this._auth);

  final ApiClient _api;
  final AuthRepository _auth;

  Future<DashboardData> dashboard() async {
    final results = await Future.wait<dynamic>([
      _auth.profile(),
      balance(),
      savingsGoals(),
      transactions(),
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

  Future<List<Transaction>> transactions({TransactionType? type}) async {
    try {
      final response = await _api.dio.get(
        ApiEndpoints.transactions,
        queryParameters: {if (type != null) 'type': type.apiValue},
      );
      return (response.data as List)
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList();
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
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.transactions,
        data: {
          'title': title,
          'amount': amount,
          'type': type.apiValue,
          'categoryId': categoryId,
          'date': date.toIso8601String(),
        },
      );
      return Transaction.fromJson(response.data as Map<String, dynamic>);
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
