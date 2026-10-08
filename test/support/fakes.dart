import 'package:appgastos/core/errors/api_exception.dart';
import 'package:appgastos/core/utils/phone_widget.dart';
import 'package:appgastos/services/phone_widget_service.dart';
import 'package:appgastos/services/payment_reminder_service.dart';
import 'package:appgastos/core/utils/payment_reminders.dart';
import 'package:appgastos/models/auth_session.dart';
import 'package:appgastos/models/budget.dart';
import 'package:appgastos/models/category.dart';
import 'package:appgastos/models/dashboard.dart';
import 'package:appgastos/models/metrics.dart';
import 'package:appgastos/models/payment_method.dart';
import 'package:appgastos/models/recurring.dart';
import 'package:appgastos/models/savings_goal.dart';
import 'package:appgastos/models/transaction.dart';
import 'package:appgastos/models/user_profile.dart';
import 'package:appgastos/repositories/auth_repository.dart';
import 'package:appgastos/repositories/finance_repository.dart';

const food = Category(
  id: 'cat-food',
  name: 'Comida',
  icon: 'lunch_dining',
  type: TransactionType.expense,
  isDefault: true,
);
const salary = Category(
  id: 'cat-work',
  name: 'Trabajo',
  icon: 'work',
  type: TransactionType.income,
  isDefault: true,
);
const savingsCategory = Category(
  id: 'cat-savings',
  name: 'Ahorro',
  icon: 'account_balance_wallet',
  type: TransactionType.expense,
  isDefault: true,
);

const daniela = UserProfile(
  id: 'u1',
  name: 'Daniela',
  email: 'daniela@universidad.edu',
  darkMode: false,
);

/// In-memory backend that mimics the API rules the app relies on.
class FakeBackend {
  /// The signed-in account's password.
  String password = 'daniela123';

  /// The user's own categories (the system ones are [food] and [salary]).
  final customCategories = <Category>[];

  List<Category> get allCategories => [food, salary, ...customCategories];

  /// Monthly limits by category id.
  final budgets = <String, double>{};

  final recurring = <RecurringRule>[];

  /// The wallet.
  final paymentMethods = <PaymentMethod>[];

  /// Payments to credit cards.
  final cardPayments = <CardPayment>[];

  Category category(String id) => allCategories.firstWhere((c) => c.id == id);

  FakeBackend({bool withData = true}) {
    if (!withData) return;
    transactions.addAll([
      Transaction(
        id: 't1',
        title: 'Tutorías',
        amount: 200,
        type: TransactionType.income,
        date: DateTime(2026, 9, 20, 12),
        category: salary,
      ),
      Transaction(
        id: 't2',
        title: 'Almuerzo facultad',
        amount: 8.5,
        type: TransactionType.expense,
        date: DateTime(2026, 9, 22, 12),
        category: food,
      ),
      Transaction(
        id: 't3',
        title: 'Ahorro: Laptop',
        amount: 50,
        type: TransactionType.expense,
        date: DateTime(2026, 9, 23, 12),
        category: savingsCategory,
        goalId: 'g1',
      ),
    ]);
    goals.add(_goal('g1', 'Laptop', 800, 50));
  }

  final transactions = <Transaction>[];
  final goals = <SavingsGoal>[];
  UserProfile user = daniela;
  String? token;
  final calls = <String>[];

  double get balance => transactions.fold(
    0.0,
    (sum, t) =>
        t.type == TransactionType.income ? sum + t.amount : sum - t.amount,
  );

  static SavingsGoal _goal(
    String id,
    String name,
    double target,
    double saved,
  ) => SavingsGoal(
    id: id,
    name: name,
    targetAmount: target,
    savedAmount: saved,
    icon: 'laptop_mac',
    bgColor: '',
    iconColor: '',
    progressPercent: target > 0 ? (saved / target * 100).clamp(0, 100) : 0,
  );

  void addContribution(String goalId, double amount) {
    final index = goals.indexWhere((g) => g.id == goalId);
    final goal = goals[index];
    goals[index] = _goal(
      goal.id,
      goal.name,
      goal.targetAmount,
      goal.savedAmount + amount,
    );
    transactions.add(
      Transaction(
        id: 't${transactions.length + 10}',
        title: '${amount < 0 ? 'Retiro' : 'Ahorro'}: ${goal.name}',
        amount: amount,
        type: TransactionType.expense,
        date: DateTime.now(),
        category: savingsCategory,
        goalId: goalId,
      ),
    );
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository(this.backend);

  final FakeBackend backend;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    backend.calls.add('login');
    if (password != backend.password) {
      throw const ApiException('Credenciales inválidas', statusCode: 401);
    }
    backend.token = 'token';
    return AuthSession(user: backend.user, accessToken: 'token');
  }

  @override
  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    backend.user = UserProfile(
      id: 'u2',
      name: name,
      email: email,
      darkMode: false,
    );
    backend.token = 'token';
    return AuthSession(user: backend.user, accessToken: 'token');
  }

  @override
  Future<UserProfile> profile() async {
    if (backend.token == null) {
      throw const ApiException('Unauthorized', statusCode: 401);
    }
    return backend.user;
  }

  @override
  Future<UserProfile> updateProfile({bool? darkMode, String? name}) async {
    backend.user = backend.user.copyWith(darkMode: darkMode, name: name);
    return backend.user;
  }

  @override
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    if (current != backend.password) {
      throw const ApiException(
        'La contraseña actual no es correcta',
        statusCode: 400,
      );
    }
    backend.calls.add('changePassword');
    backend.password = next;
  }

  @override
  Future<void> deleteAccount(String password) async {
    if (password != backend.password) {
      throw const ApiException(
        'La contraseña actual no es correcta',
        statusCode: 400,
      );
    }
    backend.calls.add('deleteAccount');
    backend.token = null;
  }

  @override
  Future<void> logout() async {
    backend.calls.add('logout');
    backend.token = null;
  }
}

class FakeFinanceRepository implements FinanceRepository {
  FakeFinanceRepository(this.backend);

  final FakeBackend backend;

  @override
  Future<DashboardData> dashboard() async => DashboardData(
    user: backend.user,
    balance: await balance(),
    goals: await savingsGoals(),
    transactions: await transactions(),
  );

  @override
  Future<List<Category>> categories() async => [
    for (final c in backend.allCategories)
      Category(
        id: c.id,
        name: c.name,
        icon: c.icon,
        type: c.type,
        isDefault: c.isDefault,
        transactionCount: backend.transactions
            .where((t) => t.category.id == c.id)
            .length,
      ),
  ];

  @override
  Future<List<Budget>> budgets(DateTime monthStart) async => [
    for (final MapEntry(key: id, value: amount) in backend.budgets.entries)
      Budget(
        category: backend.category(id),
        amount: amount,
        spent: backend.transactions
            .where(
              (t) =>
                  t.category.id == id &&
                  t.goalId == null &&
                  !t.date.isBefore(monthStart),
            )
            .fold(0.0, (sum, t) => sum + t.amount),
      ),
  ];

  @override
  Future<void> setBudget(String categoryId, double amount) async {
    backend.budgets[categoryId] = amount;
    backend.calls.add('setBudget:$categoryId:$amount');
  }

  @override
  Future<void> deleteBudget(String categoryId) async {
    backend.budgets.remove(categoryId);
    backend.calls.add('deleteBudget:$categoryId');
  }

  @override
  Future<List<RecurringRule>> recurring() async => [...backend.recurring];

  @override
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
    final id = 'r${backend.recurring.length + 1}';
    final category = backend.category(categoryId);
    // Like the API: an occurrence due today is created right away.
    final due = !startDate.isAfter(DateTime.now());
    if (due) {
      backend.transactions.add(
        Transaction(
          id: 't-$id',
          title: title,
          amount: amount,
          type: type,
          date: startDate,
          category: category,
          recurringId: id,
          paymentMethodId: paymentMethodId,
        ),
      );
    }
    final rule = RecurringRule(
      id: id,
      title: title,
      amount: amount,
      type: type,
      category: category,
      frequency: frequency,
      nextDate: due
          ? (frequency == RecurrenceFrequency.weekly
                ? startDate.add(const Duration(days: 7))
                : DateTime(startDate.year, startDate.month + 1, startDate.day))
          : startDate,
      active: true,
      paymentMethodId: paymentMethodId,
      service: service,
    );
    backend.recurring.add(rule);
    backend.calls.add('createRecurring:$title:${frequency.name}');
    return rule;
  }

  @override
  Future<RecurringRule> updateRecurring(
    String id, {
    String? title,
    double? amount,
    RecurrenceFrequency? frequency,
    bool? active,
    bool setPaymentMethod = false,
    String? paymentMethodId,
  }) async {
    final index = backend.recurring.indexWhere((r) => r.id == id);
    final old = backend.recurring[index];
    final rule = RecurringRule(
      id: id,
      title: title ?? old.title,
      amount: amount ?? old.amount,
      type: old.type,
      category: old.category,
      frequency: frequency ?? old.frequency,
      nextDate: old.nextDate,
      active: active ?? old.active,
      paymentMethodId: setPaymentMethod ? paymentMethodId : old.paymentMethodId,
      service: old.service,
    );
    backend.recurring[index] = rule;
    backend.calls.add('updateRecurring:$id');
    return rule;
  }

  @override
  Future<void> deleteRecurring(String id) async {
    backend.recurring.removeWhere((r) => r.id == id);
    backend.calls.add('deleteRecurring:$id');
  }

  @override
  Future<Category> createCategory({
    required String name,
    required String icon,
    required TransactionType type,
  }) async {
    if (backend.allCategories.any(
      (c) => c.type == type && c.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw ApiException('Ya existe una categoría "$name"');
    }
    final category = Category(
      id: 'cat-${backend.customCategories.length + 1}',
      name: name,
      icon: icon,
      type: type,
      isDefault: false,
    );
    backend.customCategories.add(category);
    backend.calls.add('createCategory:$name');
    return category;
  }

  @override
  Future<Category> updateCategory(
    String id, {
    required String name,
    required String icon,
    required TransactionType type,
  }) async {
    final index = backend.customCategories.indexWhere((c) => c.id == id);
    final category = Category(
      id: id,
      name: name,
      icon: icon,
      type: type,
      isDefault: false,
    );
    backend.customCategories[index] = category;
    backend.calls.add('updateCategory:$id');
    return category;
  }

  @override
  Future<void> deleteCategory(String id) async {
    final used = backend.transactions.where((t) => t.category.id == id);
    if (used.isNotEmpty) {
      throw ApiException(
        'La categoría tiene ${used.length} movimientos. Muévelos a otra '
        'categoría o elimínalos primero.',
      );
    }
    backend.customCategories.removeWhere((c) => c.id == id);
    backend.calls.add('deleteCategory:$id');
  }

  @override
  Future<List<Transaction>> transactions({TransactionType? type}) async =>
      backend.transactions.where((t) => type == null || t.type == type).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<BalanceSummary> balance() async {
    double sum(TransactionType type) => backend.transactions
        .where((t) => t.type == type)
        .fold(0.0, (s, t) => s + t.amount);
    final income = sum(TransactionType.income);
    final expense = sum(TransactionType.expense);
    return BalanceSummary(
      totalIncome: income,
      totalExpense: expense,
      balance: income - expense,
    );
  }

  @override
  Future<Transaction> createTransaction({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
    String? paymentMethodId,
    String? reference,
  }) async {
    final tx = Transaction(
      id: 'new${backend.transactions.length}',
      title: title,
      amount: amount,
      type: type,
      date: date,
      category: backend.category(categoryId),
      paymentMethodId: paymentMethodId,
      reference: reference,
    );
    backend.transactions.add(tx);
    return tx;
  }

  @override
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
    final index = backend.transactions.indexWhere((t) => t.id == id);
    final tx = Transaction(
      id: id,
      title: title,
      amount: amount,
      type: type,
      date: date,
      category: backend.category(categoryId),
      paymentMethodId: paymentMethodId,
      reference: reference,
    );
    backend.transactions[index] = tx;
    return tx;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    backend.calls.add('deleteTransaction:$id');
    backend.transactions.removeWhere((t) => t.id == id);
  }

  @override
  Future<List<PaymentMethod>> paymentMethods() async => [
    for (final m in backend.paymentMethods)
      PaymentMethod(
        id: m.id,
        name: m.name,
        kind: m.kind,
        color: m.color,
        brand: m.brand,
        last4: m.last4,
        bank: m.bank,
        creditLimit: m.creditLimit,
        statementDay: m.statementDay,
        dueDay: m.dueDay,
        transactionCount: backend.transactions
            .where((t) => t.paymentMethodId == m.id)
            .length,
        paidTotal: backend.cardPayments
            .where((p) => p.paymentMethodId == m.id)
            .fold(0.0, (sum, p) => sum + p.amount),
      ),
  ];

  @override
  Future<List<CardPayment>> cardPayments(String methodId) async =>
      backend.cardPayments.where((p) => p.paymentMethodId == methodId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<CardPayment> addCardPayment(
    String methodId, {
    required double amount,
    required DateTime date,
    String? fromMethodId,
  }) async {
    final card = backend.paymentMethods.firstWhere((m) => m.id == methodId);
    if (!card.kind.isCredit) {
      throw const ApiException(
        'Solo las tarjetas de crédito reciben pagos',
        statusCode: 400,
      );
    }
    final payment = CardPayment(
      id: 'cp${backend.cardPayments.length + 1}',
      paymentMethodId: methodId,
      amount: amount,
      date: date,
      fromMethodId: fromMethodId,
    );
    backend.cardPayments.add(payment);
    return payment;
  }

  @override
  Future<void> deleteCardPayment(String id) async {
    backend.calls.add('deleteCardPayment:$id');
    backend.cardPayments.removeWhere((p) => p.id == id);
  }

  PaymentMethod _method(String id, PaymentMethodInput input) {
    final json = input.toJson();
    return PaymentMethod(
      id: id,
      name: input.name,
      kind: input.kind,
      color: input.color,
      brand: CardBrand.fromApi(json['brand'] as String?),
      last4: json['last4'] as String?,
      bank: json['bank'] as String?,
      creditLimit: json['creditLimit'] as double?,
      statementDay: json['statementDay'] as int?,
      dueDay: json['dueDay'] as int?,
    );
  }

  void _checkName(String name, {String? exceptId}) {
    final taken = backend.paymentMethods.any(
      (m) => m.id != exceptId && m.name.toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      throw ApiException('Ya tienes "$name" en tu wallet', statusCode: 409);
    }
  }

  @override
  Future<PaymentMethod> createPaymentMethod(PaymentMethodInput input) async {
    backend.calls.add('createPaymentMethod');
    _checkName(input.name);
    final method = _method('pm${backend.paymentMethods.length + 1}', input);
    backend.paymentMethods.add(method);
    return method;
  }

  @override
  Future<PaymentMethod> updatePaymentMethod(
    String id,
    PaymentMethodInput input,
  ) async {
    _checkName(input.name, exceptId: id);
    final method = _method(id, input);
    final index = backend.paymentMethods.indexWhere((m) => m.id == id);
    backend.paymentMethods[index] = method;
    return method;
  }

  @override
  Future<void> deletePaymentMethod(String id) async {
    backend.calls.add('deletePaymentMethod:$id');
    backend.paymentMethods.removeWhere((m) => m.id == id);
    for (final (i, t) in backend.transactions.indexed) {
      if (t.paymentMethodId != id) continue;
      backend.transactions[i] = Transaction(
        id: t.id,
        title: t.title,
        amount: t.amount,
        type: t.type,
        date: t.date,
        category: t.category,
        goalId: t.goalId,
        recurringId: t.recurringId,
        reference: t.reference,
      );
    }
  }

  @override
  Future<List<SavingsGoal>> savingsGoals() async => List.of(backend.goals);

  @override
  Future<SavingsGoal> createGoal({
    required String name,
    required double targetAmount,
    required String icon,
    required String bgColor,
    required String iconColor,
  }) async {
    final goal = SavingsGoal(
      id: 'g${backend.goals.length + 1}',
      name: name,
      targetAmount: targetAmount,
      savedAmount: 0,
      icon: icon,
      bgColor: bgColor,
      iconColor: iconColor,
      progressPercent: 0,
    );
    backend.goals.add(goal);
    return goal;
  }

  @override
  Future<SavingsGoal> updateGoal(
    String id, {
    required String name,
    required double targetAmount,
    required String icon,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteGoal(String id) async {
    backend.calls.add('deleteGoal:$id');
    backend.goals.removeWhere((g) => g.id == id);
    backend.transactions.removeWhere((t) => t.goalId == id);
  }

  @override
  Future<SavingsGoal> addFunds(String goalId, double amount) async {
    if (amount > backend.balance) {
      throw const ApiException('Fondos insuficientes');
    }
    backend.addContribution(goalId, amount);
    return backend.goals.firstWhere((g) => g.id == goalId);
  }

  @override
  Future<SavingsGoal> withdrawFromGoal(String goalId, double amount) async {
    final goal = backend.goals.firstWhere((g) => g.id == goalId);
    if (amount > goal.savedAmount) {
      throw ApiException(
        'Solo hay ${goal.savedAmount.toStringAsFixed(2)} ahorrados en esta meta',
      );
    }
    backend.calls.add('withdraw:$goalId:$amount');
    backend.addContribution(goalId, -amount);
    return backend.goals.firstWhere((g) => g.id == goalId);
  }

  @override
  Future<List<CategoryExpense>> categoryExpenses() async {
    // Like the API: expenses per category, goal contributions excluded.
    final totals = <Category, double>{};
    for (final t in backend.transactions) {
      if (t.type != TransactionType.expense || t.isGoalContribution) continue;
      totals[t.category] = (totals[t.category] ?? 0) + t.amount;
    }
    final sum = totals.values.fold(0.0, (a, b) => a + b);
    return [
      for (final MapEntry(key: c, value: total) in totals.entries)
        CategoryExpense(
          categoryId: c.id,
          categoryName: c.name,
          icon: c.icon,
          total: total,
          percentage: total / sum * 100,
        ),
    ];
  }

  @override
  Future<SavingsEfficiency> savingsEfficiency() async =>
      const SavingsEfficiency(
        totalIncome: 200,
        totalSaved: 50,
        efficiencyPercent: 25,
      );
}

/// Records what would be sent to the native home-screen widget.
class FakePhoneWidgetService extends PhoneWidgetService {
  FakePhoneWidgetService();

  final payloads = <PhoneWidgetPayload>[];

  @override
  bool get supported => true;

  @override
  bool get canPin => false;

  @override
  Future<void> publish(PhoneWidgetPayload payload) async =>
      payloads.add(payload);
}

/// Records the reminders the app would schedule; permission is configurable.
class FakePaymentReminderService implements PaymentReminderService {
  FakePaymentReminderService({this.allow = true});

  bool allow;
  List<PlannedReminder> scheduled = const [];
  int permissionRequests = 0;

  @override
  bool get supported => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return allow;
  }

  @override
  Future<void> schedule(List<PlannedReminder> reminders) async =>
      scheduled = reminders;

  @override
  Future<void> cancelAll() async => scheduled = const [];
}
