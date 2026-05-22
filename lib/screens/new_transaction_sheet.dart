import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/category.dart';
import '../providers/finance_providers.dart';
import '../services/transaction_service.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';

Future<void> showNewTransactionSheet(
  BuildContext context, {
  TransactionType initialType = TransactionType.income,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NewTransactionSheet(initialType: initialType),
  );
}

class NewTransactionSheet extends ConsumerStatefulWidget {
  const NewTransactionSheet({super.key, required this.initialType});

  final TransactionType initialType;

  @override
  ConsumerState<NewTransactionSheet> createState() =>
      _NewTransactionSheetState();
}

class _NewTransactionSheetState extends ConsumerState<NewTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _title = TextEditingController();
  late TransactionType _type = widget.initialType;
  DateTime _date = DateTime.now();
  String? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(transactionServiceProvider)
          .create(
            title: _title.text.trim(),
            amount: double.parse(_amount.text.replaceAll(',', '.')),
            type: _type,
            categoryId: _categoryId!,
            date: _date,
          );
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transacción registrada')));
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
    final categories = ref.watch(categoriesProvider);
    final isIncome = _type == TransactionType.income;
    final accent = isIncome ? AppColors.income : AppColors.primary;
    final mutedText = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: .66);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const Gap(18),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: accent.withValues(alpha: .12),
                      child: Icon(
                        isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: accent,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncome ? 'Registrar ingreso' : 'Registrar gasto',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                          ),
                          const Gap(4),
                          Text(
                            isIncome
                                ? 'Agrega dinero recibido a tu balance.'
                                : 'Registra un egreso y mantén el control.',
                            style: TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Gap(18),
                SegmentedButton<TransactionType>(
                  segments: const [
                    ButtonSegment(
                      value: TransactionType.income,
                      label: Text('Ingreso'),
                      icon: Icon(Icons.trending_up),
                    ),
                    ButtonSegment(
                      value: TransactionType.expense,
                      label: Text('Egreso'),
                      icon: Icon(Icons.trending_down),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) {
                    setState(() {
                      _type = value.first;
                      _categoryId = null;
                    });
                  },
                ),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: accent,
                      height: 1,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto',
                      prefixText: r'$ ',
                      border: InputBorder.none,
                      filled: false,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      return parsed == null || parsed <= 0
                          ? 'Monto válido'
                          : null;
                    },
                  ),
                ),
                const Gap(14),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Nota o nombre',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Escribe una nota' : null,
                ),
                const Gap(18),
                Text(
                  'Categoría',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Gap(10),
                categories.when(
                  loading: () =>
                      const SizedBox(height: 90, child: AppShimmer()),
                  error: (error, _) => Text(error.toString()),
                  data: (items) {
                    final filtered = items
                        .where((c) => c.type == _type)
                        .toList();
                    if (_categoryId == null && filtered.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _categoryId == null) {
                          setState(() => _categoryId = filtered.first.id);
                        }
                      });
                    }
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: filtered
                          .map(
                            (category) => ChoiceChip(
                              avatar: Icon(
                                iconFromApi(category.icon),
                                size: 18,
                                color: _categoryId == category.id
                                    ? accent
                                    : null,
                              ),
                              label: Text(category.name),
                              selected: _categoryId == category.id,
                              onSelected: (_) =>
                                  setState(() => _categoryId = category.id),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const Gap(16),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(Formatters.fullDate.format(_date)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDate: _date,
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const Gap(16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Aceptar y Registrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
