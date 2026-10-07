import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/formatters.dart';
import '../models/budget.dart';
import '../models/category.dart';
import '../providers/finance_providers.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../core/theme/motion.dart';

/// Opens the sheet to create a budget, or to change or remove [budget].
Future<void> showBudgetSheet(BuildContext context, {Budget? budget}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => BudgetSheet(budget: budget),
  );
}

class BudgetSheet extends ConsumerStatefulWidget {
  const BudgetSheet({super.key, this.budget});

  final Budget? budget;

  @override
  ConsumerState<BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<BudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.budget?.amount.toStringAsFixed(2),
  );
  late String? _categoryId = widget.budget?.categoryId;

  /// Enter the limit as a share of the monthly income instead of an amount.
  bool _percentMode = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.budget != null;

  double? get _typed => double.tryParse(_amount.text.replaceAll(',', '.'));

  /// The limit in money: the typed amount, or that percent of [income].
  double _limitFrom(double income) {
    final typed = _typed ?? 0;
    return _percentMode
        ? (income * typed / 100 * 100).roundToDouble() / 100
        : typed;
  }

  void _switchMode(bool percent, double income) {
    if (percent == _percentMode) return;
    // Convert what was typed so switching keeps the same limit.
    final typed = _typed;
    setState(() {
      _percentMode = percent;
      if (typed != null && income > 0) {
        _amount.text = percent
            ? (typed / income * 100).toStringAsFixed(1)
            : (income * typed / 100).toStringAsFixed(2);
      }
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      refreshFinance(ref);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _save() {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _error = 'Elige una categoría');
      return;
    }
    final amount = _limitFrom(ref.read(monthlyIncomeProvider));
    _run(
      () => ref.read(financeRepositoryProvider).setBudget(_categoryId!, amount),
    );
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: '¿Quitar el presupuesto?',
      message:
          '${widget.budget!.category.name} ya no tendrá límite mensual. '
          'Tus movimientos no cambian.',
      confirmLabel: 'Quitar',
    );
    if (!confirmed || !mounted) return;
    _run(
      () => ref
          .read(financeRepositoryProvider)
          .deleteBudget(widget.budget!.categoryId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final categories = ref.watch(categoriesProvider);
    final income = ref.watch(monthlyIncomeProvider);
    final taken = {
      for (final b in ref.watch(budgetsProvider).value ?? const <Budget>[])
        b.categoryId,
    }..remove(widget.budget?.categoryId);

    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? 'Editar presupuesto' : 'Nuevo presupuesto',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Un límite de gasto para cada mes. $_hint',
                style: TextStyle(color: palette.muted),
              ),
              const SizedBox(height: 18),
              Text('Categoría', style: text.titleMedium),
              const SizedBox(height: 10),
              categories.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text(error.toString()),
                data: (items) {
                  final options = items
                      .where(
                        (c) =>
                            c.type == TransactionType.expense &&
                            !taken.contains(c.id),
                      )
                      .toList();
                  if (options.isEmpty) {
                    return Text(
                      'Todas tus categorías de gasto ya tienen presupuesto.',
                      style: TextStyle(color: palette.muted),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in options)
                        ChoiceChip(
                          avatar: Icon(iconFromApi(category.icon), size: 18),
                          label: Text(category.name),
                          selected: _categoryId == category.id,
                          // The category of an existing budget is fixed.
                          onSelected: _editing
                              ? null
                              : (_) =>
                                    setState(() => _categoryId = category.id),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              SegmentedTabs<bool>(
                selected: _percentMode,
                onChanged: (percent) => _switchMode(percent, income),
                segments: const {
                  false: 'Monto fijo',
                  true: '% de mis ingresos',
                },
              ),
              const SizedBox(height: 12),
              EntranceAutofocus(
                enabled: _editing,
                builder: (context, focusNode) => TextFormField(
                  controller: _amount,
                  focusNode: focusNode,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: _percentMode ? 'Porcentaje' : 'Límite mensual',
                    prefixText: _percentMode ? null : r'$ ',
                    suffixText: _percentMode ? '%' : null,
                  ),
                  validator: (_) {
                    final value = _typed;
                    if (value == null || value <= 0) {
                      return 'Escribe un número mayor a 0';
                    }
                    if (_percentMode && income <= 0) {
                      return 'Primero configura tus ingresos';
                    }
                    if (_percentMode && value > 100) return 'Máximo 100%';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Only this hint follows each key, not the sheet.
              ListenableBuilder(
                listenable: _amount,
                builder: (context, _) => Text(
                  _percentMode
                      ? income > 0
                            ? '= ${Formatters.compactMoney(_limitFrom(income))} '
                                  'al mes, de tus '
                                  '${Formatters.compactMoney(income)} de ingreso.'
                            : 'Configura tus ingresos en la calculadora para '
                                  'usar porcentajes.'
                      : income > 0 && (_typed ?? 0) > 0
                      ? 'Es el ${((_typed! / income) * 100).toStringAsFixed(1)}% '
                            'de tus ${Formatters.compactMoney(income)} al mes.'
                      : '',
                  style: TextStyle(color: palette.muted),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.blush,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        color: palette.onBlush,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: palette.onBlush,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PillCta(
                label: _editing ? 'Guardar cambios' : 'Crear presupuesto',
                loading: _saving,
                onPressed: _save,
              ),
              if (_editing) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _saving ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  icon: const Icon(CupertinoIcons.trash, size: 18),
                  label: const Text('Quitar presupuesto'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const _hint = 'Michi te avisará cuando te acerques al límite.';
}
