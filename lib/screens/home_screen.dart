import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/category.dart';
import '../models/dashboard.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/animated_progress.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/soft_card.dart';
import 'new_goal_sheet.dart';
import 'new_transaction_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);
    return dashboard.when(
      loading: () => const AppShimmer(),
      error: (error, _) => AppErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(dashboardProvider),
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 124),
          children: [
            _Header(data: data),
            const Gap(26),
            _BalanceCard(data: data),
            const Gap(28),
            const _QuickActions(),
            const Gap(28),
            _GoalsStrip(goals: data.goals),
            const Gap(28),
            const _CategoryOverview(),
            const Gap(28),
            _RecentActivity(transactions: data.transactions),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkMode = ref.watch(isDarkModeProvider);
    final parts = data.user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? 'U'
        : parts.take(2).map((part) => part[0]).join().toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: isDark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : AppColors.blush,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, ${data.user.name}! 👋',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .68),
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Finanzas M3',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : AppColors.iconBubble,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            fixedSize: const Size.square(46),
          ),
          onPressed: () =>
              ref.read(themeControllerProvider.notifier).setDarkMode(!darkMode),
          icon: Icon(
            darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : AppColors.blush,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            bottom: -52,
            child: Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                color: AppColors.blushDeep.withValues(alpha: .32),
                borderRadius: BorderRadius.circular(46),
              ),
            ),
          ),
          Positioned(
            right: 38,
            top: -44,
            child: Transform.rotate(
              angle: .78,
              child: Container(
                width: 94,
                height: 94,
                decoration: BoxDecoration(
                  color: AppColors.blushDeep.withValues(alpha: .42),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BALANCE DISPONIBLE',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8,
                ),
              ),
              const Gap(6),
              Text(
                Formatters.compactMoney(data.balance.balance),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: isDark
                      ? Theme.of(context).colorScheme.onSurface
                      : const Color(0xFF4B001F),
                  fontWeight: FontWeight.w900,
                  height: .95,
                ),
              ),
              const Gap(24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: .72)
                      : Colors.white.withValues(alpha: .52),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _MiniBalance(
                      title: 'Ingresos',
                      amount: data.balance.totalIncome,
                      icon: Icons.arrow_downward_rounded,
                      color: AppColors.income,
                    ),
                    Container(
                      width: 1,
                      height: 38,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .12),
                    ),
                    _MiniBalance(
                      title: 'Egresos',
                      amount: data.balance.totalExpense,
                      icon: Icons.arrow_upward_rounded,
                      color: AppColors.primary,
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

class _MiniBalance extends StatelessWidget {
  const _MiniBalance({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: .13),
            child: Icon(icon, color: color, size: 18),
          ),
          const Gap(10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                FittedBox(
                  child: Text(
                    Formatters.compactMoney(amount),
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w900,
              letterSpacing: .35,
            ),
          ),
        ),
        if (action != null)
          TextButton.icon(
            onPressed: onAction,
            label: Text(action!),
            icon: const Icon(Icons.chevron_right_rounded),
            iconAlignment: IconAlignment.end,
          ),
      ],
    );
  }
}

class _ActionTile {
  const _ActionTile(this.icon, this.label, this.color, this.onTap);

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActionTile(
        Icons.attach_money_rounded,
        'Gasto',
        AppColors.primary,
        () => showNewTransactionSheet(
          context,
          initialType: TransactionType.expense,
        ),
      ),
      _ActionTile(
        Icons.savings_outlined,
        'Ingreso',
        AppColors.income,
        () => showNewTransactionSheet(
          context,
          initialType: TransactionType.income,
        ),
      ),
      _ActionTile(
        Icons.track_changes_rounded,
        'Metas',
        const Color(0xFFE06A00),
        () => showNewGoalSheet(context),
      ),
      _ActionTile(
        Icons.query_stats_rounded,
        'Métricas',
        const Color(0xFF9B00FF),
        () => context.go('/metrics'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Accesos rápidos'),
        const Gap(12),
        Row(
          children: items
              .map((item) => Expanded(child: _QuickActionButton(item: item)))
              .toList(),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.item});

  final _ActionTile item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: item.onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? item.color.withValues(alpha: .14)
                  : AppColors.iconBubble,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const Gap(8),
          FittedBox(
            child: Text(
              item.label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsStrip extends StatelessWidget {
  const _GoalsStrip({required this.goals});

  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context) {
    final preview = goals.take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Metas de ahorro',
          action: 'Ver todas',
          onAction: () => context.go('/goals'),
        ),
        const Gap(12),
        if (goals.isEmpty)
          const SoftCard(
            child: AppEmptyState(
              title: 'Sin metas todavía',
              subtitle: 'Crea tu primer proyecto de ahorro desde Metas.',
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              if (compact) {
                return Column(
                  children: preview
                      .map(
                        (goal) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SizedBox(
                            height: 156,
                            child: _GoalPreviewCard(goal: goal),
                          ),
                        ),
                      )
                      .toList(),
                );
              }
              return Row(
                children: preview
                    .map(
                      (goal) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: goal == preview.last ? 0 : 14,
                          ),
                          child: SizedBox(
                            height: 156,
                            child: _GoalPreviewCard(goal: goal),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }
}

class _GoalPreviewCard extends StatelessWidget {
  const _GoalPreviewCard({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SoftCard(
      padding: const EdgeInsets.all(18),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? AppColors.primary.withValues(alpha: .16)
                    : AppColors.blush,
                child: Icon(
                  iconFromApi(goal.icon),
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const Spacer(),
              Text(
                '${goal.progressPercent.toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const Spacer(),
          Text(
            goal.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Gap(3),
          Text(
            '${Formatters.compactMoney(goal.savedAmount)} / ${Formatters.compactMoney(goal.targetAmount)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .68),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(10),
          AnimatedProgressBar(value: goal.progressPercent / 100, height: 7),
        ],
      ),
    );
  }
}

class _CategoryOverview extends ConsumerWidget {
  const _CategoryOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return categories.when(
      loading: () => const _SmallLoadingCard(title: 'Categorías'),
      error: (error, _) => SoftCard(child: Text(error.toString())),
      data: (items) {
        final income = items
            .where((item) => item.type == TransactionType.income)
            .toList();
        final expense = items
            .where((item) => item.type == TransactionType.expense)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'Categorías'),
            const Gap(12),
            SoftCard(
              padding: const EdgeInsets.all(18),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryRail(title: 'Ingresos', items: income),
                  const Gap(14),
                  _CategoryRail(title: 'Egresos', items: expense),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.title, required this.items});

  final String title;
  final List<Category> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const Gap(9),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const Gap(8),
            itemBuilder: (context, index) {
              final category = items[index];
              final color = category.type == TransactionType.income
                  ? AppColors.income
                  : AppColors.primary;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: .12)),
                ),
                child: Row(
                  children: [
                    Icon(iconFromApi(category.icon), size: 18, color: color),
                    const Gap(7),
                    Text(
                      category.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentActivity extends StatefulWidget {
  const _RecentActivity({required this.transactions});

  final List<Transaction> transactions;

  @override
  State<_RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<_RecentActivity> {
  bool expensesOnly = false;

  @override
  Widget build(BuildContext context) {
    final txs = widget.transactions
        .where((t) => !expensesOnly || t.type == TransactionType.expense)
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _SectionHeader(title: 'Actividad reciente')),
            ChoiceChip(
              label: const Text('Todos'),
              selected: !expensesOnly,
              onSelected: (_) => setState(() => expensesOnly = false),
            ),
            const Gap(8),
            ChoiceChip(
              label: const Text('Gastos'),
              selected: expensesOnly,
              onSelected: (_) => setState(() => expensesOnly = true),
            ),
          ],
        ),
        const Gap(12),
        SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: txs.isEmpty
              ? const AppEmptyState(
                  title: 'Sin movimientos',
                  subtitle: 'Registra una transacción para verla aquí.',
                )
              : Column(
                  children: txs
                      .map(
                        (tx) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor:
                                (tx.type == TransactionType.income
                                        ? AppColors.income
                                        : AppColors.primary)
                                    .withValues(alpha: .12),
                            child: Icon(
                              iconFromApi(tx.category.icon),
                              color: tx.type == TransactionType.income
                                  ? AppColors.income
                                  : AppColors.primary,
                            ),
                          ),
                          title: Text(
                            tx.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${tx.category.name} • ${Formatters.shortDate.format(tx.date)}',
                          ),
                          trailing: Text(
                            '${tx.type == TransactionType.income ? '+' : '-'}${Formatters.compactMoney(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: tx.type == TransactionType.income
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _SmallLoadingCard extends StatelessWidget {
  const _SmallLoadingCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const Gap(12),
        SoftCard(
          child: Row(
            children: [
              CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
              const Gap(14),
              const Text('Cargando...'),
            ],
          ),
        ),
      ],
    );
  }
}
