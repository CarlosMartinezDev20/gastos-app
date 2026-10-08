import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../core/utils/finance_insights.dart';
import '../core/utils/formatters.dart';
import '../core/utils/mascot_insights.dart';
import '../models/metrics.dart';
import '../providers/finance_providers.dart';
import '../widgets/animated_progress.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../core/theme/app_palette.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import 'budgets_section.dart';
import '../core/theme/motion.dart';

// Paleta de colores para categorías (se rota cíclicamente)
const _kCategoryColors = [
  Color(0xFF67AD78),
  Color(0xFF649DBD),
  Color(0xFF9A86CF),
  Color(0xFFC58F72),
  Color(0xFFB87B98),
  Color(0xFF6AADA2),
  Color(0xFF8B91BD),
  Color(0xFF96A36D),
];

Color _colorFor(int index) => _kCategoryColors[index % _kCategoryColors.length];

class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(categoryExpensesProvider);
    final efficiency = ref.watch(savingsEfficiencyProvider);
    final budgets = ref.watch(budgetsProvider).value ?? const [];

    return CollapsingTitle(
      title: 'Análisis',
      child: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.refresh(categoryExpensesProvider.future),
          ref.refresh(savingsEfficiencyProvider.future),
          ref.refresh(transactionsProvider(null).future),
          ref.refresh(budgetsProvider.future),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, dockClearance(context)),
          children: [
            LargeTitle(
              title: 'Análisis',
              subtitle: 'Cómo se reparte tu dinero',
              trailing: [
                CircleButton(
                  icon: CupertinoIcons.tag,
                  tooltip: 'Categorías',
                  onPressed: () => context.push('/categories'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const _FlowCard(),
            const SizedBox(height: 24),
            const BudgetsSection(),
            const SizedBox(height: 24),
            efficiency.when(
              loading: () => const _MetricsLoadingCard(height: 180),
              error: (error, _) => AppErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(savingsEfficiencyProvider),
              ),
              data: (data) => _EfficiencyCard(data: data),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Gastos por categoría'),
            const SizedBox(height: 8),
            expenses.when(
              loading: () => const _MetricsLoadingCard(height: 400),
              error: (error, _) => AppErrorState(
                message: error.toString(),
                onRetry: () => ref.invalidate(categoryExpensesProvider),
              ),
              data: (items) => _CategoryExpensesCard(items: items),
            ),
            if (expenses.hasValue && efficiency.hasValue) ...[
              const SizedBox(height: 20),
              _AnalyzeButton(
                tip: analysisTip(
                  expenses.requireValue,
                  efficiency.requireValue,
                  budgets: budgets,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────── Cash-flow card
class _FlowCard extends ConsumerStatefulWidget {
  const _FlowCard();

  @override
  ConsumerState<_FlowCard> createState() => _FlowCardState();
}

class _FlowCardState extends ConsumerState<_FlowCard> {
  FlowPeriod _period = FlowPeriod.week;

  static const _labels = {
    FlowPeriod.week: 'Semana',
    FlowPeriod.month: 'Mes',
    FlowPeriod.year: 'Año',
  };

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider(null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedTabs(
          segments: _labels,
          selected: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Flujo de dinero'),
        const SizedBox(height: 8),
        transactions.when(
          loading: () => const _MetricsLoadingCard(height: 260),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(transactionsProvider(null)),
          ),
          data: (items) => _FlowChart(
            period: _period,
            buckets: flowBuckets(items, DateTime.now(), _period),
          ),
        ),
      ],
    );
  }
}

class _FlowChart extends StatelessWidget {
  const _FlowChart({required this.period, required this.buckets});

  final FlowPeriod period;
  final List<FlowBucket> buckets;

  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _months = [
    'E', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D', //
  ];

  String _label(FlowBucket b) => switch (period) {
    FlowPeriod.week => _weekdays[b.start.weekday - 1],
    FlowPeriod.month => '${b.start.day}/${b.start.month}',
    FlowPeriod.year => _months[b.start.month - 1],
  };

  String _tooltipTitle(FlowBucket b) => switch (period) {
    FlowPeriod.week => Formatters.shortDate.format(b.start),
    FlowPeriod.month => 'Semana del ${Formatters.shortDate.format(b.start)}',
    FlowPeriod.year => DateFormat('MMMM yyyy', 'es').format(b.start),
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final spent = buckets.fold(0.0, (sum, b) => sum + b.spent);
    final maxY = buckets.fold(
      0.0,
      (m, b) => [m, b.income, b.spent].reduce((a, c) => a > c ? a : c),
    );
    final averageLabel = switch (period) {
      FlowPeriod.week => 'Promedio diario',
      FlowPeriod.month => 'Promedio semanal',
      FlowPeriod.year => 'Promedio mensual',
    };
    Widget stat(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(label, style: TextStyle(color: palette.muted, fontSize: 13)),
        ],
      ),
    );
    Widget legend(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: palette.muted, fontSize: 12)),
      ],
    );

    return BentoCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              stat(Formatters.compactMoney(spent), 'Total gastado'),
              const SizedBox(width: 12),
              stat(
                Formatters.compactMoney(spent / buckets.length),
                averageLabel,
              ),
            ],
          ),
          // Nothing to chart: a short note instead of an empty plot.
          if (maxY == 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(CupertinoIcons.chart_bar, color: palette.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sin movimientos en este periodo',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              children: [
                legend(palette.chartIncome, 'Ingresos'),
                legend(palette.chartExpense, 'Gastos'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: BarChart(
                duration: Motion.of(context, Motion.medium),
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY == 0 ? 1 : maxY * 1.1,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: maxY == 0 ? 1 : maxY / 3,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.onSurface.withValues(alpha: .06),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _label(buckets[i]),
                              style: TextStyle(
                                fontSize: 12,
                                color: i == buckets.length - 1
                                    ? scheme.onSurface
                                    : palette.muted,
                                fontWeight: i == buckets.length - 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => palette.pill,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (rodIndex != 0) return null;
                        final b = buckets[groupIndex];
                        final style = TextStyle(
                          color: palette.onPill,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        );
                        return BarTooltipItem(
                          '${_tooltipTitle(b)}\n',
                          style.copyWith(fontWeight: FontWeight.w700),
                          children: [
                            TextSpan(
                              text:
                                  'Ingresos ${Formatters.compactMoney(b.income)}\n'
                                  'Gastos ${Formatters.compactMoney(b.spent)}',
                              style: style,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < buckets.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 2,
                        barRods: [
                          for (final (value, color) in [
                            (buckets[i].income, palette.chartIncome),
                            (buckets[i].spent, palette.chartExpense),
                          ])
                            BarChartRodData(
                              toY: value,
                              color: color,
                              width: period == FlowPeriod.year ? 7 : 12,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────── Mascot analysis
class _AnalyzeButton extends StatelessWidget {
  const _AnalyzeButton({required this.tip});

  final MascotTip tip;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(shape: const StadiumBorder()),
      onPressed: () => showModalBottomSheet<void>(
        sheetAnimationStyle: Motion.sheet,
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        builder: (_) => _AnalysisSheet(tip: tip),
      ),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Analizar con $mascotName'),
    );
  }
}

class _AnalysisSheet extends StatelessWidget {
  const _AnalysisSheet({required this.tip});

  final MascotTip tip;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Mascot(mood: tip.mood, size: 130, onTap: () {}),
          ),
          const SizedBox(height: 8),
          Text(
            '$mascotName analizó tus finanzas',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          for (final (i, message) in tip.messages.indexed) ...[
            FadeSlideIn(
              index: i + 1,
              child: BentoCard(
                color: [
                  palette.mint,
                  palette.lilac,
                  palette.ink,
                  palette.blush,
                ][i % 4],
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: [
                        palette.onMint,
                        palette.onLilac,
                        palette.onInk,
                        palette.onBlush,
                      ][i % 4],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: [
                            palette.onMint,
                            palette.onLilac,
                            palette.onInk,
                            palette.onBlush,
                          ][i % 4],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────── Efficiency card
class _EfficiencyCard extends StatelessWidget {
  const _EfficiencyCard({required this.data});

  final SavingsEfficiency data;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effVal = (data.efficiencyPercent / 100).clamp(0, 1).toDouble();

    return BentoCard(
      color: palette.ink,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PillTag(label: 'Eficiencia de ahorro', color: palette.onInk),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: effVal),
                  duration: Motion.of(context, Motion.emphasis),
                  curve: Motion.standard,
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          color: palette.accent,
                          backgroundColor: palette.onInk.withValues(alpha: .14),
                        ),
                      ),
                      Text(
                        '${data.efficiencyPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: palette.onInk),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.message,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: palette.onInk,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _EfficiencyStat(
                      label: 'Ingresos',
                      value: Formatters.compactMoney(data.totalIncome),
                    ),
                    const SizedBox(height: 8),
                    _EfficiencyStat(
                      label: 'Ahorrado',
                      value: Formatters.compactMoney(data.totalSaved),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EfficiencyStat extends StatelessWidget {
  const _EfficiencyStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.inkMuted),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: TextStyle(
                color: palette.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────── Category expenses card
class _CategoryExpensesCard extends StatelessWidget {
  const _CategoryExpensesCard({required this.items});

  final List<CategoryExpense> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final totalGasto = items.fold(0.0, (sum, e) => sum + e.total);

    return BentoCard(
      border: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL GASTADO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: .52),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .8,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      items.isEmpty ? '—' : Formatters.compactMoney(totalGasto),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600, height: 1),
                    ),
                  ],
                ),
              ),
              if (items.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.mint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${items.length} ${items.length == 1 ? 'categoría' : 'categorías'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.onMint,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const Gap(20),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AppEmptyState(
                title: 'Sin gastos registrados',
                subtitle:
                    'Registra egresos para activar el análisis por categoría.',
              ),
            )
          else ...[
            _BarsChart(items: items),
            const Gap(24),
            // Divider sutil antes de la lista
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.onSurface.withValues(alpha: .07),
            ),
            const Gap(16),
            // Lista de filas
            for (int i = 0; i < items.length; i++) ...[
              _CategoryExpenseRow(
                item: items[i],
                index: i,
                color: _colorFor(i),
              ),
              if (i < items.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.onSurface.withValues(alpha: .055),
                  ),
                )
              else
                const Gap(4),
            ],
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────────────────── Bar chart
class _BarsChart extends StatelessWidget {
  const _BarsChart({required this.items});

  final List<CategoryExpense> items;

  @override
  Widget build(BuildContext context) {
    final topItems = items.take(6).toList();
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 148,
      child: Column(
        children: [
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    topItems.fold(0.0, (m, e) => e.total > m ? e.total : m) *
                    1.22,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: topItems.isEmpty
                      ? 1
                      : topItems.fold(
                              0.0,
                              (m, e) => e.total > m ? e.total : m,
                            ) /
                            3,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: scheme.onSurface.withValues(alpha: .06),
                    strokeWidth: 1,
                    dashArray: [4, 6],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= topItems.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(
                            iconFromApi(topItems[idx].icon),
                            size: 16,
                            color: _colorFor(idx),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => scheme.surfaceContainerHighest,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = topItems[groupIndex];
                      return BarTooltipItem(
                        '${item.categoryName}\n',
                        TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: Formatters.compactMoney(item.total),
                            style: TextStyle(
                              color: _colorFor(groupIndex),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: topItems.asMap().entries.map((entry) {
                  final color = _colorFor(entry.key);
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.total,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                          bottom: Radius.circular(4),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color, color.withValues(alpha: .55)],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────── Category row
class _CategoryExpenseRow extends StatelessWidget {
  const _CategoryExpenseRow({
    required this.item,
    required this.index,
    required this.color,
  });

  final CategoryExpense item;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FadeSlideIn(
      index: index,
      child: Row(
        children: [
          // Número de ranking
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: .32),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const Gap(10),
          // Icono con color de la categoría
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconFromApi(item.icon), size: 20, color: color),
          ),
          const Gap(12),
          // Nombre + barra de progreso
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Gap(8),
                    // Shrinks instead of being cut: a truncated amount
                    // would be misleading.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          Formatters.compactMoney(item.total),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(7),
                AnimatedProgressBar(
                  value: item.percentage / 100,
                  height: 6,
                  color: color,
                ),
              ],
            ),
          ),
          const Gap(10),
          // Porcentaje
          SizedBox(
            width: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${item.percentage.toStringAsFixed(0)}%',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────── Loading skeleton
class _MetricsLoadingCard extends StatelessWidget {
  const _MetricsLoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      border: false,
      child: SizedBox(
        height: height,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
