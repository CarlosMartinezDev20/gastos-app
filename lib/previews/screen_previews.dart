import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/finance_providers.dart';
import '../providers/theme_provider.dart';
import '../screens/home_screen.dart';
import '../screens/metrics_screen.dart';
import 'preview_support.dart';

const _phone = Size(390, 844);

/// Screens read server data through providers; these overrides feed them
/// the sample data instead of the API.
Widget _withSampleData(Widget screen, {bool empty = false}) => ProviderScope(
  overrides: [
    isDarkModeProvider.overrideWithValue(false),
    dashboardProvider.overrideWith(
      (ref) async => previewDashboard(empty: empty),
    ),
    transactionsProvider.overrideWith(
      (ref, type) async => empty ? const [] : previewTransactions,
    ),
    categoryExpensesProvider.overrideWith(
      (ref) async => empty ? const [] : previewCategoryExpenses,
    ),
    savingsEfficiencyProvider.overrideWith((ref) async => previewEfficiency),
  ],
  child: Scaffold(body: SafeArea(child: screen)),
);

@AppPreview(name: 'Inicio', group: 'Pantallas', size: _phone)
Widget homeScreen() => _withSampleData(const HomeScreen());

@AppPreview(name: 'Inicio (cuenta vacía)', group: 'Pantallas', size: _phone)
Widget homeScreenEmpty() => _withSampleData(const HomeScreen(), empty: true);

@AppPreview(name: 'Análisis', group: 'Pantallas', size: _phone)
Widget metricsScreen() => _withSampleData(const MetricsScreen());
