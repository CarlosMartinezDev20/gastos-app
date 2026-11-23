import 'dart:math' as math;

import '../../models/dashboard.dart';
import '../theme/app_accent.dart';
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

/// The phone widget's four colors, as ARGB ints.
typedef PhoneWidgetColors = ({
  int background,
  int foreground,
  int muted,
  int highlight,
});

/// Styles of the phone widget. The dark one's highlight, the light one's bars
/// and the whole «Acento» style follow the app's accent; the app sends the
/// resolved colors in the payload, so the native widgets (Android
/// `FinanceWidgetProvider.kt`, iOS `FinanceWidget.swift`) don't need a table
/// per accent (theirs is only the fallback for data saved by older versions).
enum PhoneWidgetTheme {
  light('Claro'),
  dark('Oscuro'),
  // Named `lime` since before there were accents: saved settings keep working.
  lime('Acento'),
  lilac('Lila');

  const PhoneWidgetTheme(this.label);

  final String label;

  /// The bars and the goal's progress use `highlight`.
  PhoneWidgetColors colors(AppAccent accent) => switch (this) {
    light => (
      background: 0xFFFFFFFF,
      foreground: 0xFF1C1C1E,
      muted: 0xFF64646D,
      highlight: accent.widgetHighlightLight.toARGB32(),
    ),
    dark => (
      background: 0xFF1C1C1E,
      foreground: 0xFFF7F7F8,
      muted: 0xFFA1A1A8,
      highlight: accent.accent.toARGB32(),
    ),
    lime => (
      background: accent.accent.toARGB32(),
      foreground: accent.onAccent.toARGB32(),
      muted: accent.widgetMuted.toARGB32(),
      highlight: accent.onAccent.toARGB32(),
    ),
    lilac => (
      background: 0xFFE2DDFF,
      foreground: 0xFF514578,
      muted: 0xFF7A6FA3,
      highlight: 0xFF514578,
    ),
  };
}

String _argbHex(int color) =>
    '#${color.toRadixString(16).padLeft(8, '0').toUpperCase()}';

const phoneWidgetContentKey = 'phone_widget_content';
const phoneWidgetThemeKey = 'phone_widget_theme';

/// Everything the native widget draws, already formatted, so the Android and
/// iOS code only lays it out. Keys are shared with the native code.
class PhoneWidgetPayload {
  const PhoneWidgetPayload({
    required this.theme,
    this.accent = AppAccent.lima,
    required this.title,
    required this.amount,
    required this.caption,
    this.progress,
    this.bars = const [],
  });

  final PhoneWidgetTheme theme;
  final AppAccent accent;
  final String title;
  final String amount;
  final String caption;

  /// 0–100 for a goal; null hides the progress bar.
  final int? progress;

  /// Heights 0–1, oldest first; the last one is today. Empty hides the chart.
  final List<double> bars;

  PhoneWidgetColors get colors => theme.colors(accent);

  Map<String, Object> toData() => {
    'theme': theme.name,
    'background': _argbHex(colors.background),
    'foreground': _argbHex(colors.foreground),
    'muted': _argbHex(colors.muted),
    'highlight': _argbHex(colors.highlight),
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
  AppAccent accent = AppAccent.lima,
  required bool balanceHidden,
  required DateTime now,
}) {
  String money(num value) =>
      balanceHidden ? '••••••' : Formatters.compactMoney(value);
  final week = lastSevenDays(data.transactions, now);
  final max = week.fold(0.0, (m, d) => math.max(m, d.amount));
  final bars = [for (final d in week) max <= 0 ? 0.0 : d.amount / max];
  switch (content) {
    case PhoneWidgetContent.balance:
      final spent = recentSummary(data.transactions, now).spent;
      return PhoneWidgetPayload(
        theme: theme,
        accent: accent,
        title: 'Balance disponible',
        amount: balanceHidden ? '••••••' : money(data.balance.balance),
        caption: 'Gastos 30 días: ${money(spent)}',
        bars: balanceHidden ? const [] : bars,
      );
    case PhoneWidgetContent.week:
      return PhoneWidgetPayload(
        theme: theme,
        accent: accent,
        title: 'Gastado esta semana',
        amount: money(week.fold(0.0, (sum, d) => sum + d.amount)),
        caption: 'Hoy: ${money(week.last.amount)}',
        bars: balanceHidden ? const [] : bars,
      );
    case PhoneWidgetContent.goal:
      final index = featuredGoalIndex([
        for (final g in data.goals)
          (saved: g.savedAmount, target: g.targetAmount),
      ]);
      if (index == null) {
        return PhoneWidgetPayload(
          theme: theme,
          accent: accent,
          title: 'Metas',
          amount: '—',
          caption: 'Crea tu primera meta',
        );
      }
      final goal = data.goals[index];
      return PhoneWidgetPayload(
        theme: theme,
        accent: accent,
        title: goal.name,
        amount: '${goal.progressPercent.clamp(0, 100).round()}%',
        caption:
            '${money(goal.savedAmount)} de '
            '${money(goal.targetAmount)}',
        progress: goal.progressPercent.clamp(0, 100).round(),
      );
  }
}
