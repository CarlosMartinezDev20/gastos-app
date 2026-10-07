import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/theme/app_theme.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/metrics.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../models/user_profile.dart';

/// Each annotated widget is shown twice: with the app's light and dark theme.
/// Run `flutter widget-preview start` to browse them.
final class AppPreview extends MultiPreview {
  const AppPreview({required this.name, required this.group, this.size});

  final String name;
  final String group;
  final Size? size;

  @override
  List<Preview> get previews => const [
    Preview(brightness: Brightness.light),
    Preview(brightness: Brightness.dark),
  ];

  @override
  List<Preview> transform() => [
    for (final preview in super.transform())
      (preview.toBuilder()
            ..name = '$name · ${preview.brightness!.name}'
            ..group = group
            ..size = size
            ..theme = appPreviewTheme
            ..wrapper = appPreviewSurface)
          .build(),
  ];
}

PreviewThemeData appPreviewTheme() => PreviewThemeData(
  materialLight: AppTheme.light(),
  materialDark: AppTheme.dark(),
);

/// Page background plus the theme's text style, as widgets get in the app.
/// Also loads the Spanish date names that main() sets up in the app.
Widget appPreviewSurface(Widget child) {
  initializeDateFormatting('es');
  return Builder(
    builder: (context) => Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      // The previewer's own (dark) ListTileTheme would otherwise win over ours.
      child: ListTileTheme(data: Theme.of(context).listTileTheme, child: child),
    ),
  );
}

// ───────────────────────────── Sample data

const previewFood = Category(
  id: 'food',
  name: 'Comida',
  icon: 'lunch_dining',
  type: TransactionType.expense,
  isDefault: true,
);
const previewBus = Category(
  id: 'bus',
  name: 'Transporte',
  icon: 'directions_bus',
  type: TransactionType.expense,
  isDefault: true,
);
const previewWork = Category(
  id: 'work',
  name: 'Trabajo',
  icon: 'work',
  type: TransactionType.income,
  isDefault: true,
);
const previewSavings = Category(
  id: 'savings',
  name: 'Ahorro',
  icon: 'account_balance_wallet',
  type: TransactionType.expense,
  isDefault: true,
);

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

final previewTransactions = [
  Transaction(
    id: 't1',
    title: 'Almuerzo facultad',
    amount: 8.5,
    type: TransactionType.expense,
    date: _daysAgo(0),
    category: previewFood,
  ),
  Transaction(
    id: 't2',
    title: 'Bus a la universidad',
    amount: 1.25,
    type: TransactionType.expense,
    date: _daysAgo(1),
    category: previewBus,
  ),
  Transaction(
    id: 't3',
    title: 'Ahorro: Laptop',
    amount: 50,
    type: TransactionType.expense,
    date: _daysAgo(2),
    category: previewSavings,
    goalId: 'g1',
  ),
  Transaction(
    id: 't4',
    title: 'Tutorías',
    amount: 200,
    type: TransactionType.income,
    date: _daysAgo(4),
    category: previewWork,
  ),
];

const previewGoals = [
  SavingsGoal(
    id: 'g1',
    name: 'Laptop',
    targetAmount: 800,
    savedAmount: 300,
    icon: 'laptop_mac',
    bgColor: '',
    iconColor: '',
    progressPercent: 37.5,
  ),
  SavingsGoal(
    id: 'g2',
    name: 'Viaje',
    targetAmount: 150,
    savedAmount: 150,
    icon: 'flight',
    bgColor: '',
    iconColor: '',
    progressPercent: 100,
  ),
];

const previewUser = UserProfile(
  id: 'u1',
  name: 'Daniela',
  email: 'daniela@universidad.edu',
  darkMode: false,
);

DashboardData previewDashboard({bool empty = false}) => DashboardData(
  user: previewUser,
  balance: empty
      ? const BalanceSummary(totalIncome: 0, totalExpense: 0, balance: 0)
      : const BalanceSummary(
          totalIncome: 200,
          totalExpense: 59.75,
          balance: 140.25,
        ),
  goals: empty ? const [] : previewGoals,
  transactions: empty ? const [] : previewTransactions,
);

const previewCategoryExpenses = [
  CategoryExpense(
    categoryId: 'food',
    categoryName: 'Comida',
    icon: 'lunch_dining',
    total: 8.5,
    percentage: 87,
  ),
  CategoryExpense(
    categoryId: 'bus',
    categoryName: 'Transporte',
    icon: 'directions_bus',
    total: 1.25,
    percentage: 13,
  ),
];

const previewEfficiency = SavingsEfficiency(
  totalIncome: 200,
  totalSaved: 50,
  efficiencyPercent: 25,
);
