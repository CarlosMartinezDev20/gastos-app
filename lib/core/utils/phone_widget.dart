import 'dart:math' as math;

import '../../models/dashboard.dart';
import 'finance_insights.dart';
import 'formatters.dart';
import 'home_layout.dart';

/// What the phone's home-screen widget shows.
enum PhoneWidgetContent {
  balance('Balance'),
  week('Semana'),
  goal('Meta');

  const PhoneWidgetContent(this.label);

  final String label;
}

/// Colors of the phone widget. The native widgets (Android
/// `FinanceWidgetProvider.kt`, iOS `FinanceWidget.swift`) use the same values.
enum PhoneWidgetTheme {
  light('Claro', 0xFFFFFFFF, 0xFF1C1C1E, 0xFF64646D, 0xFF8DBF1F),
  dark('Oscuro', 0xFF1C1C1E, 0xFFF7F7F8, 0xFFA1A1A8, 0xFFC8F04B),
  lime('Lima', 0xFFC8F04B, 0xFF1A2006, 0xFF4A5A1C, 0xFF1A2006),
  lilac('Lila', 0xFFE2DDFF, 0xFF514578, 0xFF7A6FA3, 0xFF514578);

  const PhoneWidgetTheme(
    this.label,
    this.background,
    this.foreground,
    this.muted,
    this.highlight,
  );

  final String label;
  final int background;
  final int foreground;
  final int muted;

  /// Today's bar and the goal's progress.
  final int highlight;
}

const phoneWidgetContentKey = 'phone_widget_content';
const phoneWidgetThemeKey = 'phone_widget_theme';

/// Everything the native widget draws, already formatted, so the Android and
/// iOS code only lays it out. Keys are shared with the native code.
class PhoneWidgetPayload {
  const PhoneWidgetPayload({
    required this.theme,
    required this.title,
    required this.amount,
    required this.caption,
    this.progress,
    this.bars = const [],
  });

  final PhoneWidgetTheme theme;
  final String title;
  final String amount;
  final String caption;

  /// 0–100 for a goal; null hides the progress bar.
  final int? progress;

  /// Heights 0–1, oldest first; the last one is today. Empty hides the chart.
  final List<double> bars;

  Map<String, Object> toData() => {
    'theme': theme.name,
    'title': title,
    'amount': amount,
    'caption': caption,
    'progress': progress ?? -1,
    'bars': bars.map((b) => b.toStringAsFixed(3)).join(','),
  };
}

/// Shown while nobody is logged in.
const loggedOutPhoneWidget = PhoneWidgetPayload(
  theme: PhoneWidgetTheme.light,
  title: 'Finanzas',
  amount: '—',
  caption: 'Inicia sesión para ver tus datos',
);

PhoneWidgetPayload phoneWidgetPayload(
  DashboardData data, {
  required PhoneWidgetContent content,
  required PhoneWidgetTheme theme,
  required bool balanceHidden,
  required DateTime now,
}) {
  final week = lastSevenDays(data.transactions, now);
  final max = week.fold(0.0, (m, d) => math.max(m, d.amount));
  final bars = [for (final d in week) max <= 0 ? 0.0 : d.amount / max];
  switch (content) {
    case PhoneWidgetContent.balance:
      final spent = recentSummary(data.transactions, now).spent;
      return PhoneWidgetPayload(
        theme: theme,
        title: 'Balance disponible',
        amount: balanceHidden
            ? '••••••'
            : Formatters.compactMoney(data.balance.balance),
        caption: 'Gastos 30 días: ${Formatters.compactMoney(spent)}',
        bars: bars,
      );
    case PhoneWidgetContent.week:
      return PhoneWidgetPayload(
        theme: theme,
        title: 'Gastado esta semana',
        amount: Formatters.compactMoney(
          week.fold(0.0, (sum, d) => sum + d.amount),
        ),
        caption: 'Hoy: ${Formatters.compactMoney(week.last.amount)}',
        bars: bars,
      );
    case PhoneWidgetContent.goal:
      final index = featuredGoalIndex([
        for (final g in data.goals)
          (saved: g.savedAmount, target: g.targetAmount),
      ]);
      if (index == null) {
        return PhoneWidgetPayload(
          theme: theme,
          title: 'Metas',
          amount: '—',
          caption: 'Crea tu primera meta',
        );
      }
      final goal = data.goals[index];
      return PhoneWidgetPayload(
        theme: theme,
        title: goal.name,
        amount: '${goal.progressPercent.clamp(0, 100).round()}%',
        caption:
            '${Formatters.compactMoney(goal.savedAmount)} de '
            '${Formatters.compactMoney(goal.targetAmount)}',
        progress: goal.progressPercent.clamp(0, 100).round(),
      );
  }
}
