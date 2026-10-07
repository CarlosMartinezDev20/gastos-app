import 'dart:convert';

import '../../models/category.dart';
import '../../models/transaction.dart';

/// How to split a monthly income between needs, wants and savings (percent).
class BudgetSplit {
  const BudgetSplit(
    this.label,
    this.needs,
    this.wants,
    this.savings,
    this.hint,
  );

  final String label;
  final int needs;
  final int wants;
  final int savings;
  final String hint;
}

const budgetSplits = [
  BudgetSplit(
    '50/30/20',
    50,
    30,
    20,
    'El clásico: equilibrio entre vivir y ahorrar.',
  ),
  BudgetSplit(
    '70/20/10',
    70,
    20,
    10,
    'Para meses justos, cuando lo básico pesa más.',
  ),
  BudgetSplit('60/20/20', 60, 20, 20, 'Ahorro firme sin renunciar a todo.'),
];

/// How often an income arrives.
enum IncomeFrequency { monthly, biweekly, weekly }

extension IncomeFrequencyInfo on IncomeFrequency {
  /// Times it arrives in an average month.
  double get perMonth => switch (this) {
    IncomeFrequency.monthly => 1,
    IncomeFrequency.biweekly => 2,
    IncomeFrequency.weekly => 52 / 12,
  };

  String get label => switch (this) {
    IncomeFrequency.monthly => 'Al mes',
    IncomeFrequency.biweekly => 'Quincenal',
    IncomeFrequency.weekly => 'Semanal',
  };
}

/// One income: a salary, an allowance, a scholarship…
class IncomeSource {
  const IncomeSource(
    this.name,
    this.amount, [
    this.frequency = IncomeFrequency.monthly,
  ]);

  final String name;

  /// What arrives each time, at [frequency].
  final double amount;
  final IncomeFrequency frequency;

  double get monthly => amount * frequency.perMonth;

  IncomeSource copyWith({
    String? name,
    double? amount,
    IncomeFrequency? frequency,
  }) => IncomeSource(
    name ?? this.name,
    amount ?? this.amount,
    frequency ?? this.frequency,
  );

  Map<String, Object> toJson() => {
    'name': name,
    'amount': amount,
    'frequency': frequency.name,
  };

  factory IncomeSource.fromJson(Map<String, dynamic> json) => IncomeSource(
    json['name'] as String,
    (json['amount'] as num).toDouble(),
    IncomeFrequency.values.asNameMap()[json['frequency']] ??
        IncomeFrequency.monthly,
  );
}

/// SharedPreferences key of the incomes set up in the calculator.
const plannerIncomeKey = 'planner_income';

String encodeIncomeSources(List<IncomeSource> sources) =>
    jsonEncode([for (final s in sources) s.toJson()]);

/// The saved incomes, or null when there are none or they are unreadable.
List<IncomeSource>? decodeIncomeSources(String? json) {
  if (json == null) return null;
  try {
    return [
      for (final item in jsonDecode(json) as List)
        IncomeSource.fromJson(item as Map<String, dynamic>),
    ];
  } on FormatException {
    return null;
  }
}

double monthlyIncome(Iterable<IncomeSource> sources) =>
    sources.fold(0.0, (sum, s) => sum + s.monthly);

/// Category icons that usually are needs (food, transport, home, health,
/// study…); everything else starts as a want. The user can flip any.
const _needIcons = {
  'lunch_dining',
  'shopping_cart',
  'directions_bus',
  'directions_car',
  'local_gas_station',
  'home',
  'bolt',
  'wifi',
  'phone_iphone',
  'medical_services',
  'school',
  'print',
  'menu_book',
  'pets',
};

bool isLikelyNeed(Category category) => _needIcons.contains(category.icon);

class CategoryAverage {
  const CategoryAverage(this.category, this.monthly);

  final Category category;
  final double monthly;
}

/// Months (of the last [months] plus the current one) that have movements,
/// used to turn totals into monthly averages. At least 1.
int _activeMonths(Iterable<Transaction> txs) =>
    txs.map((t) => (t.date.year, t.date.month)).toSet().length.clamp(1, 99);

Iterable<Transaction> _window(List<Transaction> txs, DateTime now, int months) {
  final from = DateTime(now.year, now.month - months);
  return txs.where((t) => !t.date.toLocal().isBefore(from));
}

/// Average monthly income (goal withdrawals excluded) over the last
/// [months] months plus the current one.
double averageMonthlyIncome(
  List<Transaction> txs,
  DateTime now, {
  int months = 3,
}) {
  final window = _window(txs, now, months).toList();
  final income = window.where(
    (t) => t.type == TransactionType.income && !t.isGoalContribution,
  );
  final total = income.fold(0.0, (sum, t) => sum + t.amount);
  return total / _activeMonths(window);
}

/// The user's incomes as they show in their history: one monthly source per
/// income category (Trabajo → Sueldo…), biggest first.
List<IncomeSource> incomeFromHistory(
  List<Transaction> txs,
  DateTime now, {
  int months = 3,
}) {
  final window = _window(txs, now, months).toList();
  final monthsWithData = _activeMonths(window);
  final totals = <String, (String, double)>{};
  for (final t in window) {
    if (t.type != TransactionType.income || t.isGoalContribution) continue;
    final (name, sum) = totals[t.category.id] ?? (t.category.name, 0.0);
    totals[t.category.id] = (name, sum + t.amount);
  }
  return [
    for (final (name, sum) in totals.values)
      IncomeSource(name, (sum / monthsWithData * 100).roundToDouble() / 100),
  ]..sort((a, b) => b.amount.compareTo(a.amount));
}

/// Average monthly spending per category (goal contributions excluded),
/// biggest first.
List<CategoryAverage> categoryAverages(
  List<Transaction> txs,
  DateTime now, {
  int months = 3,
}) {
  final window = _window(txs, now, months).toList();
  final monthsWithData = _activeMonths(window);
  final totals = <String, (Category, double)>{};
  for (final t in window) {
    if (t.type != TransactionType.expense || t.isGoalContribution) continue;
    final (category, sum) = totals[t.category.id] ?? (t.category, 0.0);
    totals[t.category.id] = (category, sum + t.amount);
  }
  return [
    for (final (category, sum) in totals.values)
      CategoryAverage(category, sum / monthsWithData),
  ]..sort((a, b) => b.monthly.compareTo(a.monthly));
}

class CategorySuggestion {
  const CategorySuggestion({
    required this.category,
    required this.average,
    required this.suggested,
    required this.need,
    this.custom = false,
  });

  final Category category;
  final double average;
  final double suggested;
  final bool need;

  /// The user typed this limit instead of taking the suggestion.
  final bool custom;
}

class BudgetPlan {
  const BudgetPlan({
    required this.needs,
    required this.wants,
    required this.savings,
    required this.categories,
  });

  /// Amounts for each bucket of the split.
  final double needs;
  final double wants;
  final double savings;
  final List<CategorySuggestion> categories;

  double _assigned(bool need) => categories
      .where((c) => c.need == need)
      .fold(0.0, (sum, c) => sum + c.suggested);

  double _average(bool need) => categories
      .where((c) => c.need == need)
      .fold(0.0, (sum, c) => sum + c.average);

  /// Left unassigned in each bucket (can be spent on new things or saved).
  double get needsLeft => needs - _assigned(true);
  double get wantsLeft => wants - _assigned(false);

  /// Share the usual spending of a bucket must shrink to fit (0 = fits).
  double get needsCut => _cut(_average(true), needs);
  double get wantsCut => _cut(_average(false), wants);

  static double _cut(double average, double limit) =>
      average <= limit || average == 0 ? 0 : 1 - limit / average;
}

/// Rounds a suggested limit to a friendly number: whole dollars under $20,
/// then multiples of 5. Scaled-down limits round down so the bucket fits.
double _friendly(double value, {required bool down}) {
  if (value <= 0) return 0;
  final step = value < 20 ? 1.0 : 5.0;
  final steps = down
      ? (value / step).floorToDouble()
      : (value / step).ceilToDouble();
  return (steps * step).clamp(step, double.infinity);
}

/// Splits [income] with [split] and suggests a limit per category: its usual
/// monthly spending, scaled down when the bucket (needs or wants) can't hold
/// it all. [needIds] marks which categories count as needs; [overrides] are
/// limits the user typed, which are kept and leave less room for the rest.
BudgetPlan planBudget({
  required double income,
  required BudgetSplit split,
  required List<CategoryAverage> averages,
  required Set<String> needIds,
  Map<String, double> overrides = const {},
}) {
  final needs = income * split.needs / 100;
  final wants = income * split.wants / 100;
  final savings = income * split.savings / 100;

  double bucketSum(bool need, {required bool custom}) => averages
      .where(
        (a) =>
            needIds.contains(a.category.id) == need &&
            overrides.containsKey(a.category.id) == custom,
      )
      .fold(
        0.0,
        (sum, a) => sum + (custom ? overrides[a.category.id]! : a.monthly),
      );
  // Room for suggestions = bucket minus what the user already fixed.
  final needsAvg = bucketSum(true, custom: false);
  final wantsAvg = bucketSum(false, custom: false);
  final needsRoom = (needs - bucketSum(true, custom: true)).clamp(0.0, needs);
  final wantsRoom = (wants - bucketSum(false, custom: true)).clamp(0.0, wants);

  return BudgetPlan(
    needs: needs,
    wants: wants,
    savings: savings,
    categories: [
      for (final a in averages)
        () {
          final need = needIds.contains(a.category.id);
          if (overrides[a.category.id] case final custom?) {
            return CategorySuggestion(
              category: a.category,
              average: a.monthly,
              suggested: custom,
              need: need,
              custom: true,
            );
          }
          final (limit, avg) = need
              ? (needsRoom, needsAvg)
              : (wantsRoom, wantsAvg);
          final scale = avg > limit && avg > 0 ? limit / avg : 1.0;
          return CategorySuggestion(
            category: a.category,
            average: a.monthly,
            suggested: _friendly(a.monthly * scale, down: scale < 1),
            need: need,
          );
        }(),
    ],
  );
}
