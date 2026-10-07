import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/finance_insights.dart';
import '../core/utils/formatters.dart';
import '../core/utils/home_layout.dart';
import '../core/utils/mascot_insights.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../providers/phone_widget_provider.dart';
import '../providers/storage_provider.dart';
import '../screens/new_goal_sheet.dart';
import '../screens/new_transaction_sheet.dart';
import 'animated_progress.dart';
import 'app_states.dart';
import 'icon_mapper.dart';
import 'ios_ui.dart';
import 'mascot.dart';
import 'transaction_tile.dart';
import '../core/theme/motion.dart';

/// Colors a home widget is drawn with, from its [HomeWidgetStyle].
class HomeTone {
  const HomeTone({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.subtle,
    required this.action,
    required this.onAction,
    this.gradient,
  });

  factory HomeTone.of(BuildContext context, HomeWidgetStyle style) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    HomeTone tinted(Color bg, Color fg, {Gradient? gradient}) => HomeTone(
      background: bg,
      foreground: fg,
      muted: fg.withValues(alpha: .7),
      subtle: fg.withValues(alpha: .1),
      action: fg,
      onAction: bg,
      gradient: gradient,
    );
    return switch (style) {
      HomeWidgetStyle.card => HomeTone(
        background: palette.card,
        foreground: scheme.onSurface,
        muted: palette.muted,
        subtle: scheme.surfaceContainerHighest,
        action: palette.pill,
        onAction: palette.onPill,
      ),
      HomeWidgetStyle.ink => HomeTone(
        background: palette.ink,
        foreground: palette.onInk,
        muted: palette.inkMuted,
        subtle: palette.onInk.withValues(alpha: .1),
        action: palette.accent,
        onAction: palette.onAccent,
      ),
      HomeWidgetStyle.accent => tinted(palette.accent, palette.onAccent),
      HomeWidgetStyle.mint => tinted(palette.mint, palette.onMint),
      HomeWidgetStyle.blush => tinted(palette.blush, palette.onBlush),
      HomeWidgetStyle.lilac => tinted(palette.lilac, palette.onLilac),
      // Same in both modes, like the lime accent.
      HomeWidgetStyle.aurora => tinted(
        palette.accent,
        palette.onAccent,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC8F04B), Color(0xFFA8E6CF), Color(0xFFCBC3FF)],
        ),
      ),
    };
  }

  final Color background;
  final Color foreground;
  final Color muted;

  /// Tracks, bubbles and inactive bars.
  final Color subtle;

  /// Buttons on the card.
  final Color action;
  final Color onAction;
  final Gradient? gradient;
}

/// One widget of Inicio, drawn as its [config] says.
class HomeCard extends StatelessWidget {
  const HomeCard({super.key, required this.config, required this.data});

  final HomeWidgetConfig config;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tone = HomeTone.of(context, config.style);
    final compact = config.compact;
    return switch (config.type) {
      HomeWidgetType.balance => BalanceCard(data: data, tone: tone),
      HomeWidgetType.income => _AmountCard(
        label: 'Ingresos',
        icon: CupertinoIcons.arrow_down_left,
        amount: _month(data).income,
        tone: tone,
      ),
      HomeWidgetType.spending => _AmountCard(
        label: 'Gastos',
        icon: CupertinoIcons.arrow_up_right,
        amount: _month(data).spent,
        tone: tone,
      ),
      HomeWidgetType.cashflow => _CashflowCard(month: _month(data), tone: tone),
      HomeWidgetType.week => _WeekCard(
        days: lastSevenDays(data.transactions, DateTime.now()),
        compact: compact,
        tone: tone,
      ),
      HomeWidgetType.goals => _GoalsCard(
        goals: data.goals,
        compact: compact,
        tone: tone,
      ),
      HomeWidgetType.budgets => _BudgetsCard(compact: compact, tone: tone),
      HomeWidgetType.recent => _RecentActivity(transactions: data.transactions),
      HomeWidgetType.quickAdd => _QuickAddCard(compact: compact, tone: tone),
    };
  }

  static PeriodSummary _month(DashboardData data) =>
      recentSummary(data.transactions, DateTime.now());
}

/// Card with a [HomeTone]'s colors.
class _ToneCard extends StatelessWidget {
  const _ToneCard({
    required this.tone,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final HomeTone tone;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => BentoCard(
    color: tone.background,
    gradient: tone.gradient,
    radius: 24,
    padding: padding,
    onTap: onTap,
    child: DefaultTextStyle.merge(
      style: TextStyle(color: tone.foreground),
      child: IconTheme.merge(
        data: IconThemeData(color: tone.foreground),
        child: child,
      ),
    ),
  );
}

/// Title row of a card: a label and an icon.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.label, this.icon, {this.trailing});

  final String label;
  final IconData icon;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      if (trailing != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(
            trailing!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      Icon(icon, size: 18),
    ],
  );
}

class _BigAmount extends StatelessWidget {
  const _BigAmount(this.value);

  final double value;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Text(
      Formatters.compactMoney(value),
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -.6,
      ),
    ),
  );
}

// ───────────────────────────── Balance

/// The balance (can be hidden), Michi with its tip and an "add" pill.
/// Tapping Michi shows its next tip.
class BalanceCard extends ConsumerStatefulWidget {
  const BalanceCard({super.key, required this.data, required this.tone});

  final DashboardData data;
  final HomeTone tone;

  @override
  ConsumerState<BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends ConsumerState<BalanceCard> {
  static const _mascotSize = 84.0;

  int _tip = 0;

  /// Remembered across sessions, like a banking app's privacy toggle.
  late bool _hidden =
      ref.read(sharedPreferencesProvider).getBool(balanceHiddenKey) ?? false;

  void _toggleHidden() {
    setState(() => _hidden = !_hidden);
    ref.read(sharedPreferencesProvider).setBool(balanceHiddenKey, _hidden);
    ref.invalidate(phoneWidgetPayloadProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tone = widget.tone;
    final data = widget.data;
    final animations =
        Mascot.animate && !MediaQuery.disableAnimationsOf(context);
    final tip = homeTip(
      month: recentSummary(data.transactions, DateTime.now()),
      balance: data.balance.balance,
      hasActivity: data.transactions.isNotEmpty,
      goalCount: data.goals.length,
      budgets: ref.watch(budgetsProvider).value ?? const [],
    );
    final message = tip.messages[_tip % tip.messages.length];
    final amountStyle = TextStyle(
      color: tone.foreground,
      fontSize: 38,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.6,
    );
    return _ToneCard(
      tone: tone,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance disponible',
                      style: TextStyle(color: tone.muted, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _hidden
                                ? Text('••••••', style: amountStyle)
                                : TweenAnimationBuilder<double>(
                                    tween: Tween(
                                      begin: 0,
                                      end: data.balance.balance,
                                    ),
                                    duration: animations
                                        ? Motion.emphasis
                                        : Duration.zero,
                                    curve: Motion.standard,
                                    builder: (context, value, _) => Text(
                                      Formatters.compactMoney(value),
                                      style: amountStyle,
                                    ),
                                  ),
                          ),
                        ),
                        IconButton(
                          tooltip: _hidden
                              ? 'Mostrar balance'
                              : 'Ocultar balance',
                          onPressed: _toggleHidden,
                          color: tone.muted,
                          icon: Icon(
                            _hidden
                                ? CupertinoIcons.eye
                                : CupertinoIcons.eye_slash,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Mascot(
                mood: tip.mood,
                size: _mascotSize,
                onTap: () => setState(() => _tip++),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) => SpeechBubble(
              color: tone.subtle,
              // Point at Michi, above the right end of the bubble.
              tailUpAt: 1 - (_mascotSize / 2) / constraints.maxWidth,
              child: AnimatedSwitcher(
                duration: animations ? Motion.medium : Duration.zero,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .25),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previous, ?current],
                ),
                child: Text.rich(
                  key: ValueKey(message),
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$mascotName  ',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: message),
                    ],
                  ),
                  style: TextStyle(
                    color: tone.foreground,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: const StadiumBorder(),
              backgroundColor: tone.action,
              foregroundColor: tone.onAction,
            ),
            onPressed: () => showNewTransactionSheet(
              context,
              initialType: TransactionType.income,
            ),
            child: const Text('Añadir dinero'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Income / spending

/// A 30-day total over diagonal stripes, like the texture of a bank card.
class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.icon,
    required this.amount,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final double amount;
  final HomeTone tone;

  @override
  Widget build(BuildContext context) => _ToneCard(
    tone: tone,
    padding: EdgeInsets.zero,
    onTap: () => context.go('/transactions'),
    child: CustomPaint(
      painter: _StripesPainter(tone.foreground.withValues(alpha: .07)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(label, icon),
            const SizedBox(height: 22),
            _BigAmount(amount),
            Text(
              'Últimos 30 días',
              style: TextStyle(color: tone.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 10;
    for (var x = size.width * .45; x < size.width + size.height; x += 22) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter oldDelegate) => oldDelegate.color != color;
}

// ───────────────────────────── Cash flow

class _CashflowCard extends StatelessWidget {
  const _CashflowCard({required this.month, required this.tone});

  final PeriodSummary month;
  final HomeTone tone;

  @override
  Widget build(BuildContext context) {
    final left = month.income - month.spent;
    final total = month.income + month.spent;
    Widget figure(String label, double value, IconData icon) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: tone.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tone.muted, fontSize: 13),
                ),
              ),
            ],
          ),
          _BigAmount(value),
        ],
      ),
    );
    return _ToneCard(
      tone: tone,
      onTap: () => context.go('/metrics'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle(
            'Flujo del mes',
            CupertinoIcons.arrow_right_arrow_left,
          ),
          Text(
            'Últimos 30 días',
            style: TextStyle(color: tone.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              figure('Ingresos', month.income, CupertinoIcons.arrow_down_left),
              const SizedBox(width: 12),
              figure('Gastos', month.spent, CupertinoIcons.arrow_up_right),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: total <= 0
                  ? ColoredBox(color: tone.subtle)
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: math.max(
                            1,
                            (month.income / total * 100).round(),
                          ),
                          child: ColoredBox(color: tone.foreground),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          flex: math.max(
                            1,
                            (month.spent / total * 100).round(),
                          ),
                          child: ColoredBox(
                            color: tone.foreground.withValues(alpha: .3),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            left >= 0
                ? 'Te quedan ${Formatters.compactMoney(left)}'
                : 'Gastaste ${Formatters.compactMoney(-left)} más de lo que entró',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Week

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.days,
    required this.compact,
    required this.tone,
  });

  final List<DaySpending> days;
  final bool compact;
  final HomeTone tone;

  static const _initials = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];

  @override
  Widget build(BuildContext context) {
    final total = days.fold(0.0, (sum, d) => sum + d.amount);
    final max = days.fold(0.0, (m, d) => math.max(m, d.amount));
    final barGap = compact ? 3.0 : 6.0;
    return _ToneCard(
      tone: tone,
      onTap: () => context.go('/metrics'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Esta semana', CupertinoIcons.chart_bar),
          SizedBox(height: compact ? 10 : 6),
          _BigAmount(total),
          Text(
            'Gastado en 7 días',
            style: TextStyle(color: tone.muted, fontSize: 12),
          ),
          SizedBox(height: compact ? 10 : 14),
          Semantics(
            label: 'Gasto por día',
            child: SizedBox(
              height: compact ? 40 : 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, day) in days.indexed)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: barGap / 2),
                        child: FractionallySizedBox(
                          heightFactor: max <= 0
                              ? .08
                              : math.max(.08, day.amount / max),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: i == days.length - 1
                                  ? tone.foreground
                                  : tone.foreground.withValues(alpha: .3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                for (final (i, day) in days.indexed)
                  Expanded(
                    child: Text(
                      i == days.length - 1
                          ? 'Hoy'
                          : _initials[day.day.weekday % 7],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: tone.muted,
                        fontSize: 11,
                        fontWeight: i == days.length - 1
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Goals

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({
    required this.goals,
    required this.compact,
    required this.tone,
  });

  final List<SavingsGoal> goals;
  final bool compact;
  final HomeTone tone;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return _ToneCard(
        tone: tone,
        onTap: () => showNewGoalSheet(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardTitle('Metas', CupertinoIcons.flag),
            const SizedBox(height: 18),
            const Text(
              'Crea tu primera meta y empieza a ahorrar.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    final featured =
        featuredGoalIndex([
          for (final g in goals) (saved: g.savedAmount, target: g.targetAmount),
        ]) ??
        0;
    final shown = compact
        ? [goals[featured]]
        : [goals[featured], ...goals.whereIndexed(featured)].take(3);
    return _ToneCard(
      tone: tone,
      onTap: () => context.go('/goals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            compact ? 'Meta' : 'Metas de ahorro',
            CupertinoIcons.flag,
            trailing: compact || goals.length < 2 ? null : '${goals.length}',
          ),
          for (final goal in shown) ...[
            SizedBox(height: compact ? 16 : 14),
            _GoalRow(goal: goal, tone: tone, compact: compact),
          ],
        ],
      ),
    );
  }
}

extension on List<SavingsGoal> {
  /// Every goal but the one at [skip].
  Iterable<SavingsGoal> whereIndexed(int skip) =>
      indexed.where((e) => e.$1 != skip).map((e) => e.$2);
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.tone,
    required this.compact,
  });

  final SavingsGoal goal;
  final HomeTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final done = goal.savedAmount >= goal.targetAmount;
    final percent = done ? '¡Cumplida!' : '${goal.progressPercent.round()}%';
    final bar = AnimatedProgressBar(
      value: goal.progressPercent / 100,
      height: 6,
      color: tone.foreground,
      trackColor: tone.subtle,
    );
    final amounts = Text(
      '${Formatters.compactMoney(goal.savedAmount)} de '
      '${Formatters.compactMoney(goal.targetAmount)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tone.muted, fontSize: 12),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconFromApi(goal.icon), size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            percent,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
          amounts,
          const SizedBox(height: 8),
          bar,
        ],
      );
    }
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: tone.subtle, shape: BoxShape.circle),
          child: Icon(iconFromApi(goal.icon), size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    percent,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              amounts,
              const SizedBox(height: 6),
              bar,
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Budgets

class _BudgetsCard extends ConsumerWidget {
  const _BudgetsCard({required this.compact, required this.tone});

  final bool compact;
  final HomeTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = [...ref.watch(budgetsProvider).value ?? const <Budget>[]]
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final shown = budgets.take(compact ? 1 : 3);
    return _ToneCard(
      tone: tone,
      onTap: () => context.go('/metrics'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(
            compact ? 'Presupuesto' : 'Presupuestos del mes',
            CupertinoIcons.gauge,
          ),
          if (budgets.isEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Ponle un límite a tus gastos desde Análisis.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
          for (final budget in shown) ...[
            SizedBox(height: compact ? 16 : 14),
            _BudgetRow(budget: budget, tone: tone, compact: compact),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.budget,
    required this.tone,
    required this.compact,
  });

  final Budget budget;
  final HomeTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final left = budget.exceeded
        ? 'Te pasaste ${Formatters.compactMoney(-budget.remaining)}'
        : 'Quedan ${Formatters.compactMoney(budget.remaining)}';
    final percent = '${(budget.progress * 100).round()}%';
    final name = Row(
      children: [
        Icon(iconFromApi(budget.category.icon), size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            budget.category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (budget.exceeded)
          const Icon(CupertinoIcons.exclamationmark_circle_fill, size: 16),
        if (!compact) ...[
          const SizedBox(width: 6),
          Text(percent, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        name,
        if (compact) ...[
          const SizedBox(height: 4),
          Text(
            percent,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
            ),
          ),
        ],
        Text(
          left,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tone.muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        AnimatedProgressBar(
          value: budget.progress,
          height: 6,
          color: tone.foreground,
          trackColor: tone.subtle,
        ),
      ],
    );
  }
}

// ───────────────────────────── Recent activity

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final txs = transactions.take(4).toList();
    return Column(
      children: [
        SectionHeader(
          title: 'Actividad reciente',
          action: transactions.isEmpty ? null : 'Ver todo',
          onAction: () => context.go('/transactions'),
        ),
        const SizedBox(height: 8),
        if (txs.isEmpty)
          BentoCard(
            child: Column(
              children: [
                const AppEmptyState(
                  title: 'Sin movimientos',
                  subtitle: 'Registra tu primer ingreso o gasto.',
                ),
                FilledButton.icon(
                  onPressed: () => showNewTransactionSheet(
                    context,
                    initialType: TransactionType.expense,
                  ),
                  icon: const Icon(CupertinoIcons.add),
                  label: const Text('Registrar movimiento'),
                ),
              ],
            ),
          )
        else
          BentoCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final (i, transaction) in txs.indexed) ...[
                  if (i > 0) const Divider(indent: 58),
                  TransactionTile(transaction: transaction),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────── Shortcuts

class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({required this.compact, required this.tone});

  final bool compact;
  final HomeTone tone;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, IconData icon, TransactionType type) =>
        Material(
          color: tone.action,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showNewTransactionSheet(context, initialType: type),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: tone.onAction),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tone.onAction,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    final expense = button(
      'Gasto',
      CupertinoIcons.minus,
      TransactionType.expense,
    );
    final income = button(
      'Ingreso',
      CupertinoIcons.plus,
      TransactionType.income,
    );
    return _ToneCard(
      tone: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardTitle('Atajos', CupertinoIcons.bolt),
          const SizedBox(height: 12),
          if (compact) ...[
            expense,
            const SizedBox(height: 8),
            income,
          ] else
            Row(
              children: [
                Expanded(child: expense),
                const SizedBox(width: 10),
                Expanded(child: income),
              ],
            ),
        ],
      ),
    );
  }
}
