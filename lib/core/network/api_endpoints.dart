class ApiEndpoints {
  const ApiEndpoints._();

  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';
  static const profile = '/users/profile';
  static const categories = '/categories';
  static const transactions = '/transactions';
  static const balance = '/transactions/balance';
  static const savingsGoals = '/savings-goals';
  static const categoryExpenses = '/metrics/category-expenses';
  static const savingsEfficiency = '/metrics/savings-efficiency';

  static String addGoalFunds(String id) => '/savings-goals/$id/add-funds';
}
