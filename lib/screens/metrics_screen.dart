import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/metrics.dart';
import '../providers/finance_providers.dart';
import '../widgets/animated_progress.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/soft_card.dart';

class MetricsScreen extends ConsumerWidget {
  const MetricsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(categoryExpensesProvider);
    final efficiency = ref.watch(savingsEfficiencyProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(categoryExpensesProvider);
            ref.invalidate(savingsEfficiencyProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 124),
            children: [
              const _MetricsHeader(),
              const Gap(22),
              efficiency.when(
                loading: () => const _MetricsLoadingCard(height: 164),
                error: (error, _) => AppErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(savingsEfficiencyProvider),
                ),
                data: (data) => _EfficiencyCard(data: data),
              ),
              const Gap(18),
              expenses.when(
                loading: () => const _MetricsLoadingCard(height: 360),
                error: (error, _) => AppErrorState(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(categoryExpensesProvider),
                ),
                data: (items) => _CategoryExpensesCard(items: items),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsHeader extends StatelessWidget {
  const _MetricsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Análisis Mensual',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const Gap(6),
        Text(
          'Ingresos, gastos y ahorro en una vista clara.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .64),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EfficiencyCard extends StatelessWidget {
  const _EfficiencyCard({required this.data});

  final SavingsEfficiency data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SoftCard(
      padding: const EdgeInsets.all(20),
      color: isDark
          ? AppColors.primary.withValues(alpha: .12)
          : AppColors.blush.withValues(alpha: .72),
      child: Row(
        children: [
          SizedBox(
            width: 102,
            height: 102,
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: (data.efficiencyPercent / 100).clamp(0, 1),
              ),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 11,
                    strokeCap: StrokeCap.round,
                    color: Theme.of(context).colorScheme.primary,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: .12),
                  ),
                  Text(
                    '${data.efficiencyPercent.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Eficiencia de ahorro',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const Gap(8),
                Text(
                  data.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricPill(
                      label: 'Ahorrado',
                      value: Formatters.compactMoney(data.totalSaved),
                    ),
                    _MetricPill(
                      label: 'Ingresos',
                      value: Formatters.compactMoney(data.totalIncome),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · $value',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _CategoryExpensesCard extends StatelessWidget {
  const _CategoryExpensesCard({required this.items});

  final List<CategoryExpense> items;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gastos por categoría',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const Gap(18),
          if (items.isEmpty)
            const AppEmptyState(
              title: 'Sin gastos',
              subtitle: 'Registra egresos para activar el análisis.',
            )
          else ...[
            _MiniBarsChart(items: items),
            const Gap(20),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _CategoryExpenseRow(item: item),
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniBarsChart extends StatelessWidget {
  const _MiniBarsChart({required this.items});

  final List<CategoryExpense> items;

  @override
  Widget build(BuildContext context) {
    final topItems = items.take(6).toList();
    return SizedBox(
      height: 112,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: topItems.asMap().entries.map((entry) {
            final opacity = (1 - (entry.key * .08).clamp(0, .45)).toDouble();
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.total,
                  width: 16,
                  borderRadius: BorderRadius.circular(999),
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: opacity),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CategoryExpenseRow extends StatelessWidget {
  const _CategoryExpenseRow({required this.item});

  final CategoryExpense item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: .12),
          child: Icon(
            iconFromApi(item.icon),
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const Gap(12),
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
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    Formatters.compactMoney(item.total),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const Gap(8),
              AnimatedProgressBar(
                value: item.percentage / 100,
                height: 7,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
        const Gap(10),
        SizedBox(
          width: 42,
          child: Text(
            '${item.percentage.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .62),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricsLoadingCard extends StatelessWidget {
  const _MetricsLoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
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
