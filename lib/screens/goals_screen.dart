import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/utils/formatters.dart';
import '../models/savings_goal.dart';
import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/animated_progress.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../core/theme/app_palette.dart';
import '../widgets/ios_ui.dart';
import 'new_goal_sheet.dart';
import '../core/theme/motion.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(savingsGoalsProvider);
    return goals.when(
      loading: () => const AppShimmer(),
      error: (error, _) => AppErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(savingsGoalsProvider),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(savingsGoalsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 20, 20, dockClearance(context)),
          children: [
            LargeTitle(
              title: 'Metas',
              subtitle: 'Ahorra para lo que de verdad quieres',
              trailing: [
                CircleButton(
                  icon: CupertinoIcons.add,
                  tooltip: 'Nueva meta',
                  filled: true,
                  onPressed: () => showNewGoalSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              BentoCard(
                color: context.palette.lilac,
                onTap: () => showNewGoalSheet(context),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.flag_fill,
                      color: context.palette.onLilac,
                      size: 28,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Aún no tienes metas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: context.palette.onLilac,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Crea una meta y aporta desde tu balance cuando puedas.',
                      style: TextStyle(color: context.palette.onLilac),
                    ),
                  ],
                ),
              )
            else ...[
              _GoalsSummary(goals: items),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Tus metas'),
              const SizedBox(height: 8),
              for (final entry in items.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GoalCard(goal: entry.$2, index: entry.$1),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dark hero card with the total saved across all goals.
class _GoalsSummary extends StatelessWidget {
  const _GoalsSummary({required this.goals});

  final List<SavingsGoal> goals;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final saved = goals.fold(0.0, (s, g) => s + g.savedAmount);
    final target = goals.fold(0.0, (s, g) => s + g.targetAmount);
    final done = goals.where((g) => g.savedAmount >= g.targetAmount).length;
    return BentoCard(
      color: palette.ink,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PillTag(label: 'Total ahorrado', color: palette.onInk),
              Text(
                '$done de ${goals.length} cumplidas',
                style: TextStyle(color: palette.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            Formatters.compactMoney(saved),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: palette.onInk,
              fontSize: 40,
            ),
          ),
          Text(
            'de ${Formatters.compactMoney(target)} en total',
            style: TextStyle(color: palette.inkMuted),
          ),
          const SizedBox(height: 14),
          AnimatedProgressBar(
            value: target == 0 ? 0 : saved / target,
            height: 8,
            color: palette.accent,
            trackColor: palette.onInk.withValues(alpha: .15),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal, required this.index});

  final SavingsGoal goal;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final completed = goal.savedAmount >= goal.targetAmount;
    final tint = completed ? palette.mint : palette.lilac;
    final onTint = completed ? palette.onMint : palette.onLilac;
    return FadeSlideIn(
      index: index,
      child: BentoCard(
        border: true,
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconFromApi(goal.icon), color: onTint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Meta ${Formatters.compactMoney(goal.targetAmount)}',
                        style: TextStyle(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${goal.progressPercent.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                PopupMenuButton<_GoalAction>(
                  tooltip: 'Opciones de la meta',
                  useRootNavigator: true,
                  icon: Icon(CupertinoIcons.ellipsis, color: palette.muted),
                  onSelected: (action) => switch (action) {
                    _GoalAction.edit => showNewGoalSheet(context, goal: goal),
                    _GoalAction.withdraw => _showAddFunds(
                      context,
                      goal,
                      withdraw: true,
                    ),
                    _GoalAction.delete => _deleteGoal(context, ref, goal),
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: _GoalAction.edit,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(CupertinoIcons.pencil),
                        title: Text('Editar'),
                      ),
                    ),
                    if (goal.savedAmount > 0)
                      const PopupMenuItem(
                        value: _GoalAction.withdraw,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(CupertinoIcons.arrow_down_circle),
                          title: Text('Retirar dinero'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: _GoalAction.delete,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(CupertinoIcons.trash),
                        title: Text('Eliminar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedProgressBar(
                value: goal.progressPercent / 100,
                height: 10,
                color: completed ? palette.onMint : null,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ahorrado ${Formatters.compactMoney(goal.savedAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (!completed)
                          Text(
                            'Faltan ${Formatters.compactMoney(goal.targetAmount - goal.savedAmount)}',
                            style: TextStyle(color: palette.muted),
                          ),
                      ],
                    ),
                  ),
                  if (completed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: palette.mint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_seal_fill,
                            size: 16,
                            color: palette.onMint,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Meta cumplida',
                            style: TextStyle(
                              color: palette.onMint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      onPressed: () => _showAddFunds(context, goal),
                      child: const Text('Aportar'),
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

enum _GoalAction { edit, withdraw, delete }

Future<void> _deleteGoal(
  BuildContext context,
  WidgetRef ref,
  SavingsGoal goal,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await confirmAction(
    context,
    title: '¿Eliminar "${goal.name}"?',
    message: goal.savedAmount > 0
        ? 'Los ${Formatters.compactMoney(goal.savedAmount)} ahorrados volverán a tu balance disponible.'
        : 'La meta se eliminará.',
    confirmLabel: 'Eliminar',
  );
  if (!confirmed) return;
  try {
    await ref.read(savingsServiceProvider).deleteGoal(goal.id);
    refreshFinance(ref);
    messenger.showSnackBar(
      SnackBar(content: Text('Meta "${goal.name}" eliminada')),
    );
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

void _showAddFunds(
  BuildContext context,
  SavingsGoal goal, {
  bool withdraw = false,
}) {
  showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    // Above the shell's floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AddFundsSheet(goal: goal, withdraw: withdraw),
  );
}

/// Adds money to a goal, or with [withdraw] takes it back to the balance.
class _AddFundsSheet extends ConsumerStatefulWidget {
  const _AddFundsSheet({required this.goal, this.withdraw = false});

  final SavingsGoal goal;
  final bool withdraw;

  @override
  ConsumerState<_AddFundsSheet> createState() => _AddFundsSheetState();
}

class _AddFundsSheetState extends ConsumerState<_AddFundsSheet> {
  final _amount = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _remaining => (widget.goal.targetAmount - widget.goal.savedAmount)
      .clamp(0, double.infinity);

  Future<void> _save(double? available) async {
    final parsed = double.tryParse(_amount.text.replaceAll(',', '.'));
    String? error;
    if (parsed == null || parsed <= 0) {
      error = 'Ingresa un monto mayor a 0';
    } else if (widget.withdraw && parsed > widget.goal.savedAmount) {
      error = 'Supera lo ahorrado en la meta';
    } else if (!widget.withdraw && available != null && parsed > available) {
      error = 'Supera tu balance disponible';
    }
    setState(() => _error = error);
    if (error != null) return;

    setState(() => _saving = true);
    try {
      final savings = ref.read(savingsServiceProvider);
      if (widget.withdraw) {
        await savings.withdraw(widget.goal.id, parsed!);
      } else {
        await savings.addFunds(widget.goal.id, parsed!);
      }
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.withdraw
                ? '${Formatters.compactMoney(parsed)} volvieron a tu balance'
                : parsed >= _remaining
                ? '¡Meta "${widget.goal.name}" cumplida! 🎉'
                : 'Aporte de ${Formatters.compactMoney(parsed)} registrado',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fill(double value) {
    _amount.text = value.toStringAsFixed(2);
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(dashboardProvider).value?.balance.balance;
    final scheme = Theme.of(context).colorScheme;
    final saved = widget.goal.savedAmount;
    final suggestions = widget.withdraw
        ? <double>{
            for (final v in [10.0, 25.0, 50.0])
              if (v < saved) v,
            saved,
          }
        : <double>{
            for (final v in [10.0, 25.0, 50.0])
              if (v < _remaining && (available == null || v <= available)) v,
            if (_remaining > 0 &&
                (available == null || _remaining <= available))
              _remaining,
          };

    return KeyboardInset(
      extra: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.withdraw
                    ? 'Retirar de ${widget.goal.name}'
                    : 'Aportar a ${widget.goal.name}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Gap(6),
              Text(
                widget.withdraw
                    ? 'Ahorrado ${Formatters.compactMoney(saved)}'
                    : [
                        'Faltan ${Formatters.compactMoney(_remaining)}',
                        if (available != null)
                          'Disponible ${Formatters.compactMoney(available)}',
                      ].join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const Gap(16),
              EntranceAutofocus(
                builder: (context, focusNode) => TextField(
                  controller: _amount,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _save(available),
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    prefixText: r'$ ',
                    errorText: _error,
                  ),
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in suggestions)
                      ActionChip(
                        label: Text(
                          widget.withdraw && value == saved
                              ? 'Todo (${Formatters.compactMoney(value)})'
                              : !widget.withdraw && value == _remaining
                              ? 'Completar (${Formatters.compactMoney(value)})'
                              : Formatters.compactMoney(value),
                        ),
                        onPressed: () => _fill(value),
                      ),
                  ],
                ),
              ],
              const Gap(18),
              Text(
                widget.withdraw
                    ? 'El dinero vuelve a tu balance disponible.'
                    : 'El aporte se descuenta de tu balance disponible.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const Gap(10),
              FilledButton(
                onPressed: _saving ? null : () => _save(available),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.withdraw ? 'Retirar' : 'Aportar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
