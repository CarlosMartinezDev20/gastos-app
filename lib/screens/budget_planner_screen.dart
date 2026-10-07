import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/budget_planner.dart';
import '../core/utils/formatters.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../providers/storage_provider.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import '../core/theme/motion.dart';

/// Builds a monthly budget from the user's incomes (salary, allowance,
/// scholarship… at their frequency): splits the total with a rule
/// (50/30/20, or custom) and sets a limit per expense category, suggested
/// from the usual spending and editable. "Aplicar" saves them as budgets.
class BudgetPlannerScreen extends ConsumerWidget {
  const BudgetPlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider(null));
    final categories = ref.watch(categoriesProvider);
    final goals = ref.watch(savingsGoalsProvider).value ?? const [];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: switch ((transactions, categories)) {
              (AsyncData(value: final txs), AsyncData(value: final cats)) =>
                _Planner(transactions: txs, categories: cats, goals: goals),
              (AsyncError(:final error), _) ||
              (_, AsyncError(:final error)) => AppErrorState(
                message: error.toString(),
                onRetry: () {
                  ref.invalidate(transactionsProvider(null));
                  ref.invalidate(categoriesProvider);
                },
              ),
              _ => const AppShimmer(),
            },
          ),
        ),
      ),
    );
  }
}

class _Planner extends ConsumerStatefulWidget {
  const _Planner({
    required this.transactions,
    required this.categories,
    required this.goals,
  });

  final List<Transaction> transactions;
  final List<Category> categories;
  final List<SavingsGoal> goals;

  @override
  ConsumerState<_Planner> createState() => _PlannerState();
}

class _PlannerState extends ConsumerState<_Planner> {
  static const _customIndex = 3;

  late final _now = DateTime.now();
  late List<IncomeSource> _sources = _loadSources();

  /// Every expense category, with its usual monthly spending (0 if none).
  late final _averages = () {
    final history = {
      for (final a in categoryAverages(widget.transactions, _now))
        a.category.id: a,
    };
    return [
      ...history.values,
      for (final c in widget.categories)
        if (c.type == TransactionType.expense && !history.containsKey(c.id))
          CategoryAverage(c, 0),
    ];
  }();
  late final _needIds = {
    for (final a in _averages)
      if (isLikelyNeed(a.category)) a.category.id,
  };
  final _overrides = <String, double>{};
  int _splitIndex = 0;
  int _customNeeds = 50;
  int _customWants = 30;
  bool _applying = false;

  BudgetSplit get _split => _splitIndex == _customIndex
      ? BudgetSplit(
          'Personalizado',
          _customNeeds,
          _customWants,
          100 - _customNeeds - _customWants,
          'Elige tú cuánto va a cada parte.',
        )
      : budgetSplits[_splitIndex];

  List<IncomeSource> _loadSources() =>
      decodeIncomeSources(
        ref.read(sharedPreferencesProvider).getString(plannerIncomeKey),
      ) ??
      incomeFromHistory(widget.transactions, _now);

  void _setSources(List<IncomeSource> sources) {
    setState(() => _sources = sources);
    ref
        .read(sharedPreferencesProvider)
        .setString(plannerIncomeKey, encodeIncomeSources(sources));
    ref.invalidate(monthlyIncomeProvider);
  }

  Future<void> _editSource([int? index]) async {
    final result = await showModalBottomSheet<_SourceResult>(
      sheetAnimationStyle: Motion.sheet,
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) =>
          _IncomeSourceSheet(source: index == null ? null : _sources[index]),
    );
    if (result == null) return;
    final next = [..._sources];
    if (result.delete) {
      next.removeAt(index!);
    } else if (index == null) {
      next.add(result.source!);
    } else {
      next[index] = result.source!;
    }
    _setSources(next);
  }

  Future<void> _editLimit(CategorySuggestion item) async {
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _LimitDialog(item: item),
    );
    if (value == null) return;
    setState(() {
      // A negative result means "use the suggestion again".
      if (value < 0) {
        _overrides.remove(item.category.id);
      } else {
        _overrides[item.category.id] = value;
      }
    });
  }

  Future<void> _apply(List<CategorySuggestion> items) async {
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(financeRepositoryProvider);
    try {
      for (final item in items) {
        await repository.setBudget(item.category.id, item.suggested);
      }
      refreshFinance(ref);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${items.length} ${items.length == 1 ? 'presupuesto aplicado' : 'presupuestos aplicados'}',
          ),
        ),
      );
      context.canPop() ? context.pop() : context.go('/metrics');
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final income = monthlyIncome(_sources);
    final split = _split;
    final plan = planBudget(
      income: income,
      split: split,
      averages: _averages,
      needIds: _needIds,
      overrides: _overrides,
    );
    final ready = income > 0;
    final toApply = plan.categories.where((c) => c.suggested > 0).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.paddingOf(context).bottom + 28,
      ),
      children: [
        Row(
          children: [
            CircleButton(
              icon: CupertinoIcons.chevron_left,
              tooltip: 'Volver',
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/metrics'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const LargeTitle(
          title: 'Calculadora',
          subtitle: 'Arma tu presupuesto a partir de lo que ganas',
        ),
        const SizedBox(height: 20),
        // 1. Incomes.
        const _Step(number: 1, title: 'Tus ingresos'),
        FadeSlideIn(
          child: _IncomeCard(
            sources: _sources,
            total: income,
            onEdit: _editSource,
          ),
        ),
        const SizedBox(height: 24),
        // 2. Split.
        const _Step(number: 2, title: 'Cómo repartirlo'),
        SegmentedTabs<int>(
          selected: _splitIndex,
          onChanged: (value) => setState(() => _splitIndex = value),
          segments: {
            for (final (i, s) in budgetSplits.indexed) i: s.label,
            _customIndex: 'Propio',
          },
        ),
        const SizedBox(height: 8),
        Text(split.hint, style: TextStyle(color: palette.muted)),
        if (_splitIndex == _customIndex) ...[
          const SizedBox(height: 8),
          _PercentSlider(
            label: 'Necesidades',
            value: _customNeeds,
            max: 100 - _customWants,
            onChanged: (v) => setState(() => _customNeeds = v),
          ),
          _PercentSlider(
            label: 'Gustos',
            value: _customWants,
            max: 100 - _customNeeds,
            onChanged: (v) => setState(() => _customWants = v),
          ),
        ],
        const SizedBox(height: 14),
        _SplitCard(plan: plan, split: split),
        if (ready && plan.savings > 0 && widget.goals.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SavingsHint(goals: widget.goals, monthly: plan.savings),
        ],
        const SizedBox(height: 24),
        // 3. Limits per category.
        const _Step(number: 3, title: 'Límite por categoría'),
        Text(
          'Sugerido según tu gasto de los últimos meses. Toca un monto para '
          'cambiarlo y la etiqueta para moverlo entre necesidad y gusto.',
          style: TextStyle(color: palette.muted),
        ),
        const SizedBox(height: 10),
        if (_averages.isEmpty)
          BentoCard(
            child: Row(
              children: [
                const Mascot(mood: MascotMood.sleepy, size: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tienes categorías de gasto todavía.',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
              ],
            ),
          )
        else
          BentoCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, item) in plan.categories.indexed) ...[
                  if (i > 0) const Divider(indent: 72, height: 1),
                  _SuggestionRow(
                    item: item,
                    ready: ready,
                    onEdit: () => _editLimit(item),
                    onToggle: () => setState(() {
                      final id = item.category.id;
                      if (!_needIds.remove(id)) _needIds.add(id);
                    }),
                  ),
                ],
              ],
            ),
          ),
        if (ready) ...[
          const SizedBox(height: 10),
          for (final note in _notes(plan))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    CupertinoIcons.info_circle,
                    size: 16,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      note,
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 16),
        if (!ready)
          Text(
            'Agrega al menos un ingreso para calcular.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted),
          )
        else if (toApply.isNotEmpty)
          PillCta(
            label:
                'Aplicar ${toApply.length} '
                '${toApply.length == 1 ? 'presupuesto' : 'presupuestos'}',
            loading: _applying,
            onPressed: () => _apply(toApply),
          ),
      ],
    );
  }

  List<String> _notes(BudgetPlan plan) => [
    if (plan.needsCut > 0)
      'Tus necesidades suelen pasar el ${_split.needs}%: bajamos sus límites '
          'un ${(plan.needsCut * 100).round()}%.',
    if (plan.wantsCut > 0)
      'Tus gustos suelen pasar el ${_split.wants}%: bajamos sus límites '
          'un ${(plan.wantsCut * 100).round()}%.',
    if (plan.needsLeft < -0.5)
      'Tus límites de necesidades suman '
          '${Formatters.compactMoney(-plan.needsLeft)} más de lo previsto.',
    if (plan.wantsLeft < -0.5)
      'Tus límites de gustos suman '
          '${Formatters.compactMoney(-plan.wantsLeft)} más de lo previsto.',
    if (plan.needsLeft >= 1)
      'Te quedan ${Formatters.compactMoney(plan.needsLeft)} libres en '
          'necesidades.',
    if (plan.wantsLeft >= 1)
      'Te quedan ${Formatters.compactMoney(plan.wantsLeft)} libres para gustos.',
  ];
}

/// Numbered step heading.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: palette.onAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.sources,
    required this.total,
    required this.onEdit,
  });

  final List<IncomeSource> sources;
  final double total;
  final ValueChanged<int?> onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return BentoCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, source) in sources.indexed)
            ListTile(
              onTap: () => onEdit(i),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  CupertinoIcons.money_dollar,
                  color: palette.onAccent,
                ),
              ),
              title: Text(
                source.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${Formatters.compactMoney(source.amount)} · '
                '${source.frequency.label}',
                style: TextStyle(color: palette.muted),
              ),
              trailing: Text(
                '${Formatters.compactMoney(source.monthly)}/mes',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: OutlinedButton.icon(
              onPressed: () => onEdit(null),
              icon: const Icon(CupertinoIcons.add, size: 18),
              label: Text(
                sources.isEmpty
                    ? 'Agregar sueldo u otro ingreso'
                    : 'Agregar otro ingreso',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total al mes',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      Formatters.compactMoney(total),
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(
            '$label $value%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            max: max.toDouble(),
            divisions: max == 0 ? null : max ~/ 5,
            activeColor: palette.ink,
            label: '$value%',
            onChanged: (v) => onChanged((v / 5).round() * 5),
          ),
        ),
      ],
    );
  }
}

/// What the income sheet returns: a source to save, or a deletion.
class _SourceResult {
  const _SourceResult.save(IncomeSource this.source) : delete = false;
  const _SourceResult.delete() : source = null, delete = true;

  final IncomeSource? source;
  final bool delete;
}

class _IncomeSourceSheet extends StatefulWidget {
  const _IncomeSourceSheet({this.source});

  final IncomeSource? source;

  @override
  State<_IncomeSourceSheet> createState() => _IncomeSourceSheetState();
}

class _IncomeSourceSheetState extends State<_IncomeSourceSheet> {
  static const _suggestions = ['Sueldo', 'Mesada', 'Beca', 'Trabajos extra'];

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.source?.name);
  late final _amount = TextEditingController(
    text: widget.source?.amount.toStringAsFixed(2),
  );
  late IncomeFrequency _frequency =
      widget.source?.frequency ?? IncomeFrequency.monthly;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _parsed => double.tryParse(_amount.text.replaceAll(',', '.'));

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _SourceResult.save(IncomeSource(_name.text.trim(), _parsed!, _frequency)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.source == null ? 'Nuevo ingreso' : 'Editar ingreso',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final name in _suggestions)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => setState(() => _name.text = name),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Ponle un nombre' : null,
              ),
              const SizedBox(height: 12),
              EntranceAutofocus(
                enabled: widget.source == null,
                builder: (context, focusNode) => TextFormField(
                  controller: _amount,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Monto que recibes',
                    prefixText: r'$ ',
                  ),
                  validator: (_) => _parsed == null || _parsed! <= 0
                      ? 'Escribe un monto mayor a 0'
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedTabs<IncomeFrequency>(
                selected: _frequency,
                onChanged: (value) => setState(() => _frequency = value),
                segments: {for (final f in IncomeFrequency.values) f: f.label},
              ),
              const SizedBox(height: 10),
              // Only this line follows each key, not the sheet.
              ListenableBuilder(
                listenable: _amount,
                builder: (context, _) => Text(
                  'Equivale a ${Formatters.compactMoney((_parsed ?? 0) * _frequency.perMonth)} al mes.',
                  style: TextStyle(color: palette.muted),
                ),
              ),
              const SizedBox(height: 20),
              PillCta(label: 'Guardar ingreso', onPressed: _save),
              if (widget.source != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(context, const _SourceResult.delete()),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(CupertinoIcons.trash, size: 18),
                  label: const Text('Quitar ingreso'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for a category limit. Returns the amount, or -1 to go back to the
/// suggestion.
class _LimitDialog extends StatefulWidget {
  const _LimitDialog({required this.item});

  final CategorySuggestion item;

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  late final _controller = TextEditingController(
    text: widget.item.suggested > 0
        ? widget.item.suggested.toStringAsFixed(2)
        : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_controller.text.replaceAll(',', '.'));
    if (value == null || value < 0) {
      setState(() => _error = 'Escribe un monto válido');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Límite de ${widget.item.category.name}'),
      content: EntranceAutofocus(
        builder: (context, focusNode) => TextField(
          controller: _controller,
          focusNode: focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Al mes',
            prefixText: r'$ ',
            errorText: _error,
            helperText: widget.item.average > 0
                ? 'Sueles gastar ${Formatters.compactMoney(widget.item.average)}'
                : 'Aún no tienes gastos en esta categoría',
          ),
        ),
      ),
      actions: [
        if (widget.item.custom)
          TextButton(
            onPressed: () => Navigator.pop(context, -1.0),
            child: const Text('Usar sugerido'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _submit,
          child: const Text('Listo'),
        ),
      ],
    );
  }
}

/// Stacked bar and amounts of needs / wants / savings.
class _SplitCard extends StatelessWidget {
  const _SplitCard({required this.plan, required this.split});

  final BudgetPlan plan;
  final BudgetSplit split;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final duration = Motion.of(context, Motion.medium);
    final parts = [
      ('Necesidades', split.needs, plan.needs, palette.ink, palette.onInk),
      ('Gustos', split.wants, plan.wants, palette.lilac, palette.onLilac),
      ('Ahorro', split.savings, plan.savings, palette.accent, palette.onAccent),
    ];
    return BentoCard(
      radius: 24,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 14,
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    for (final (_, percent, _, color, _) in parts)
                      AnimatedContainer(
                        duration: duration,
                        curve: Motion.standard,
                        width: constraints.maxWidth * percent / 100,
                        color: color,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (final (label, percent, amount, color, _) in parts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$label · $percent%',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    Formatters.compactMoney(amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
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

class _SavingsHint extends StatelessWidget {
  const _SavingsHint({required this.goals, required this.monthly});

  final List<SavingsGoal> goals;
  final double monthly;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pending = goals.where((g) => g.savedAmount < g.targetAmount).toList()
      ..sort(
        (a, b) => (a.targetAmount - a.savedAmount).compareTo(
          b.targetAmount - b.savedAmount,
        ),
      );
    if (pending.isEmpty) return const SizedBox.shrink();
    final goal = pending.first;
    final months = ((goal.targetAmount - goal.savedAmount) / monthly).ceil();
    return BentoCard(
      color: palette.mint,
      child: Row(
        children: [
          Icon(iconFromApi(goal.icon), color: palette.onMint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Ahorrando ${Formatters.compactMoney(monthly)} al mes, '
              'completarías "${goal.name}" en $months '
              '${months == 1 ? 'mes' : 'meses'}.',
              style: TextStyle(
                color: palette.onMint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.item,
    required this.ready,
    required this.onEdit,
    required this.onToggle,
  });

  final CategorySuggestion item;
  final bool ready;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.need ? palette.ink : palette.lilac,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              iconFromApi(item.category.icon),
              color: item.need ? palette.onInk : palette.onLilac,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Cambiar a ${item.need ? 'gusto' : 'necesidad'}',
                      child: GestureDetector(
                        onTap: onToggle,
                        child: PillTag(
                          label: item.need ? 'Necesidad' : 'Gusto',
                          icon: CupertinoIcons.arrow_2_squarepath,
                        ),
                      ),
                    ),
                    Text(
                      item.average > 0
                          ? 'Promedio ${Formatters.compactMoney(item.average)}'
                          : 'Sin gastos aún',
                      style: text.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // Tap to type a limit; typed ones are highlighted.
          TextButton(
            onPressed: ready ? onEdit : null,
            style: TextButton.styleFrom(
              backgroundColor: item.custom ? palette.accent : null,
              foregroundColor: item.custom
                  ? palette.onAccent
                  : Theme.of(context).colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              !ready
                  ? '—'
                  : item.suggested > 0
                  ? Formatters.compactMoney(item.suggested)
                  : 'Definir',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: item.custom ? palette.onAccent : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
