import '../widgets/money_privacy.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
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
    return _ActionCard(
      icon: CupertinoIcons.slider_horizontal_3,
      title: 'Calcular mis presupuestos',
      subtitle: 'Reparte tu ingreso con la regla 50/30/20',
      onTap: () => context.push('/budget-planner'),
    );
  }
}

/// A tappable card with a lime icon tile, a title and a line of detail:
/// the empty state and the calculator link share it so they line up.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final muted = palette.muted;
    return BentoCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: ShapeDecoration(
              color: palette.fill,
              shape: AppTheme.continuous(12),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurface,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: muted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.chevron_right, size: 16, color: muted),
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
        ? (scheme.error, 'Te pasaste por ${context.money(-budget.remaining)}')
        : budget.nearLimit
        ? (const Color(0xFFF29D38), 'Quedan ${context.money(budget.remaining)}')
        : (palette.chartIncome, 'Quedan ${context.money(budget.remaining)}');
    return InkWell(
      onTap: () => showBudgetSheet(context, budget: budget),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: ShapeDecoration(
                color: palette.fill,
                shape: AppTheme.continuous(12),
              ),
              child: Icon(
                iconFromApi(budget.category.icon),
                color: scheme.onSurface,
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
                    '$status · ${context.money(budget.spent)} de '
                    '${context.money(budget.amount)}',
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
  Widget build(BuildContext context) => _ActionCard(
    icon: CupertinoIcons.gauge,
    title: 'Ponle un límite a tus gastos',
    subtitle: 'Define un límite mensual para una categoría.',
    onTap: () => showBudgetSheet(context),
  );
}
