import 'savings_goal.dart';
import 'transaction.dart';
import 'user_profile.dart';

class DashboardData {
  const DashboardData({
    required this.user,
    required this.balance,
    required this.goals,
    required this.transactions,
  });

  final UserProfile user;
  final BalanceSummary balance;
  final List<SavingsGoal> goals;
  final List<Transaction> transactions;
}
