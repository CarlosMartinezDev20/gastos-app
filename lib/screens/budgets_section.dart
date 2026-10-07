import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/formatters.dart';
import '../models/budget.dart';
import '../providers/finance_providers.dart';
import '../widgets/animated_progress.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import 'budget_sheet.dart';

/// This month's budgets with how much of each limit is spent.
class BudgetsSection extends ConsumerWidget {
  const BudgetsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider);
    final month = DateFormat('MMMM', 'es').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Presupuestos de $month',
          action: 'Añadir',
          onAction: () => showBudgetSheet(context),
        ),
        const SizedBox(height: 8),
        budgets.when(
          loading: () => const BentoCard(
            child: SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, _) => BentoCard(
            child: Row(
              children: [
                Expanded(child: Text(error.toString())),
                TextButton(
                  onPressed: () => ref.invalidate(budgetsProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
          data: (items) => items.isEmpty
              ? const _EmptyBudgets()
              : BentoCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      for (final (i, budget) in items.indexed) ...[
                        if (i > 0) const Divider(indent: 72, height: 1),
                        _BudgetRow(budget: budget),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 10),
        const _PlannerLink(),
      ],
    );
  }
}

/// Opens the budget calculator.
class _PlannerLink extends StatelessWidget {
  const _PlannerLink();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BentoCard(
      color: palette.ink,
      onTap: () => context.push('/budget-planner'),
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              CupertinoIcons.slider_horizontal_3,
              color: palette.onAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calcular mis presupuestos',
                  style: TextStyle(
                    color: palette.onInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Reparte tu ingreso con la regla 50/30/20',
                  style: TextStyle(color: palette.inkMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: palette.inkMuted),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (color, status) = budget.exceeded
        ? (
            scheme.error,
            'Te pasaste por ${Formatters.compactMoney(-budget.remaining)}',
          )
        : budget.nearLimit
        ? (
            const Color(0xFFF29D38),
            'Quedan ${Formatters.compactMoney(budget.remaining)}',
          )
        : (
            palette.chartIncome,
            'Quedan ${Formatters.compactMoney(budget.remaining)}',
          );
    return InkWell(
      onTap: () => showBudgetSheet(context, budget: budget),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: palette.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                iconFromApi(budget.category.icon),
                color: palette.onInk,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          budget.category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(budget.progress * 100).round()}%',
                        style: text.labelLarge?.copyWith(
                          color: budget.exceeded || budget.nearLimit
                              ? color
                              : palette.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AnimatedProgressBar(
                    value: budget.progress,
                    height: 7,
                    color: color,
                    trackColor: scheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$status · ${Formatters.compactMoney(budget.spent)} de '
                    '${Formatters.compactMoney(budget.amount)}',
                    style: text.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  const _EmptyBudgets();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BentoCard(
      onTap: () => showBudgetSheet(context),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              CupertinoIcons.gauge,
              color: palette.onAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ponle un límite a tus gastos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Por ejemplo, \$120 al mes en Comida.',
                  style: TextStyle(color: palette.muted),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_right, size: 16, color: palette.muted),
        ],
      ),
    );
  }
}
