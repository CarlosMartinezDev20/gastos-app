import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/savings_goal.dart';
import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/animated_progress.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/soft_card.dart';
import 'new_goal_sheet.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    return Scaffold(
      body: SafeArea(
        child: goals.when(
          loading: () => const _GoalsSkeleton(),
          error: (error, _) => AppErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(savingsGoalsProvider),
          ),
          data: (items) => RefreshIndicator(
            onRefresh: () async => ref.refresh(savingsGoalsProvider.future),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 124),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _GoalsHeader(onCreate: () => showNewGoalSheet(context)),
                  const Gap(22),
                  if (items.isEmpty)
                    const AppEmptyState(
                      title: 'Aún no tienes metas',
                      subtitle:
                          'Crea una meta y empieza a aportar desde tu balance.',
                    )
                  else
                    for (final entry in items.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _GoalCard(goal: entry.$2, index: entry.$1),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalsSkeleton extends StatelessWidget {
  const _GoalsSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 124),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBox(width: 190, height: 30, color: base),
                    const Gap(8),
                    _SkeletonBox(width: 240, height: 18, color: base),
                  ],
                ),
              ),
              _SkeletonBox(width: 92, height: 46, color: base),
            ],
          ),
          const Gap(22),
          for (var i = 0; i < 3; i++) ...[
            _SkeletonBox(height: 168, color: base),
            const Gap(16),
          ],
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, required this.color});

  final double? width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _GoalsHeader extends StatelessWidget {
  const _GoalsHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Metas de Ahorro',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Gap(4),
              const Text('Organiza tus proyectos financieros'),
            ],
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(104, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Nueva'),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.index});

  final SavingsGoal goal;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 50).clamp(0, 250)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - value)),
            child: child,
          ),
        );
      },
      child: SoftCard(
        color: Theme.of(context).colorScheme.surface,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 380;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? AppColors.primary.withValues(alpha: .16)
                          : AppColors.blush,
                      child: Icon(
                        iconFromApi(goal.icon),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Meta total ${Formatters.compactMoney(goal.targetAmount)}',
                          ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Text(
                        '${goal.progressPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const Gap(18),
                AnimatedProgressBar(
                  value: goal.progressPercent / 100,
                  height: 12,
                ),
                const Gap(12),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Ahorrado ${Formatters.compactMoney(goal.savedAmount)}',
                    ),
                    if (compact)
                      Text(
                        '${goal.progressPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(104, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _showAddFunds(context, goal),
                      child: const Text('Aportar'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

void _showAddFunds(BuildContext context, SavingsGoal goal) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddFundsSheet(goal: goal),
  );
}

class _AddFundsSheet extends ConsumerStatefulWidget {
  const _AddFundsSheet({required this.goal});

  final SavingsGoal goal;

  @override
  ConsumerState<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends ConsumerState<_AddFundsSheet> {
  final _amount = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsed = double.tryParse(_amount.text.replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) return;

    setState(() => _saving = true);
    try {
      await ref.read(savingsServiceProvider).addFunds(widget.goal.id, parsed);
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Aporte registrado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aportar a ${widget.goal.name}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Gap(16),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: r'$ ',
              ),
            ),
            const Gap(18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Aportar'),
            ),
          ],
        ),
      ),
    );
  }
}
