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
  static const budgets = '/budgets';
  static const recurring = '/recurring';
  static const paymentMethods = '/payment-methods';

  static String category(String id) => '/categories/$id';
  static String budget(String categoryId) => '/budgets/$categoryId';
  static String recurringRule(String id) => '/recurring/$id';
  static String paymentMethod(String id) => '/payment-methods/$id';
  static String cardPayments(String methodId) =>
      '/payment-methods/$methodId/payments';
  static String cardPayment(String id) => '/payment-methods/payments/$id';
  static String transaction(String id) => '/transactions/$id';
  static String savingsGoal(String id) => '/savings-goals/$id';
  static String addGoalFunds(String id) => '/savings-goals/$id/add-funds';
  static String withdrawGoalFunds(String id) => '/savings-goals/$id/withdraw';
}
