import '../widgets/money_privacy.dart';
import '../widgets/form_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/formatters.dart';
import '../core/utils/goal_plan.dart';
import '../models/savings_goal.dart';
import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/goal_icon_picker.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../widgets/ios_ui.dart';
import '../core/theme/motion.dart';

/// Opens the form to create a goal, or to edit [goal] when given.
/// [name] and [icon] prefill a new goal (the ideas on an empty Metas).
Future<void> showNewGoalSheet(
  BuildContext context, {
  SavingsGoal? goal,
  String? name,
  String? icon,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    // Above the shell's floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    builder: (_) => NewGoalSheet(goal: goal, name: name, icon: icon),
  );
}

class NewGoalSheet extends ConsumerStatefulWidget {
  const NewGoalSheet({super.key, this.goal, this.name, this.icon});

  final SavingsGoal? goal;
  final String? name;
  final String? icon;

  @override
  ConsumerState<NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends ConsumerState<NewGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.goal?.name ?? widget.name,
  );
  late final _amount = TextEditingController(
    text: widget.goal?.targetAmount.toStringAsFixed(2),
  );
  late String _icon = widget.goal?.icon ?? widget.icon ?? goalIcons.first.api;
  late DateTime? _targetDate = widget.goal?.targetDate;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.goal != null;
  bool get _hasChanges =>
      _name.text != (widget.goal?.name ?? widget.name ?? '') ||
      _amount.text != (widget.goal?.targetAmount.toStringAsFixed(2) ?? '') ||
      _icon != (widget.goal?.icon ?? widget.icon ?? goalIcons.first.api) ||
      _targetDate != widget.goal?.targetDate;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(savingsServiceProvider);
    final name = _name.text.trim();
    final target = double.parse(_amount.text.replaceAll(',', '.'));
    try {
      if (_editing) {
        await service.updateGoal(
          widget.goal!.id,
          name: name,
          targetAmount: target,
          icon: _icon,
          targetDate: _targetDate,
        );
      } else {
        await service.createGoal(
          name: name,
          targetAmount: target,
          icon: _icon,
          bgColor: 'bg-rose-500/10',
          iconColor: 'text-rose-500',
          targetDate: _targetDate,
        );
      }
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text(_editing ? 'Meta actualizada' : 'Meta creada')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedChangesGuard(
      controllers: [_name, _amount],
      hasChanges: () => _hasChanges,
      saving: _saving,
      child: KeyboardInset(
        extra: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FormLayout.inset),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editing ? 'Editar meta' : 'Nueva meta de ahorro',
                          style: FormLayout.titleStyle(context),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar formulario',
                        onPressed: _saving
                            ? null
                            : () => Navigator.maybePop(context),
                        icon: const Icon(CupertinoIcons.xmark),
                      ),
                      if (!_editing)
                        IconButton(
                          tooltip: 'Pantalla completa',
                          onPressed: _saving
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  context.push(
                                    '/goals/new',
                                    extra: (
                                      name: _name.text,
                                      amount: _amount.text,
                                      icon: _icon,
                                      targetDate: _targetDate,
                                    ),
                                  );
                                },
                          icon: const Icon(Icons.open_in_full),
                        ),
                    ],
                  ),
                  const Gap(FormLayout.sectionGap),
                  EntranceAutofocus(
                    enabled: !_editing,
                    builder: (context, focusNode) => TextFormField(
                      maxLength: 60,
                      controller: _name,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        counterText: '',
                        labelText: 'Nombre de la meta',
                        hintText: 'Ej. Viaje de fin de ciclo',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Escribe un nombre'
                          : null,
                    ),
                  ),
                  const Gap(FormLayout.fieldGap),
                  TextFormField(
                    controller: _amount,
                    obscureText: MoneyPrivacyScope.hiddenOf(context),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Monto objetivo',
                      prefixText: r'$ ',
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(
                        (value ?? '').replaceAll(',', '.'),
                      );
                      return parsed == null || parsed <= 0
                          ? 'Ingresa un monto mayor a 0'
                          : null;
                    },
                  ),
                  const Gap(FormLayout.fieldGap),
                  GoalDateField(
                    value: _targetDate,
                    amount: _amount,
                    saved: widget.goal?.savedAmount ?? 0,
                    onChanged: (day) => setState(() => _targetDate = day),
                  ),
                  const Gap(FormLayout.sectionGap),
                  const FormSectionLabel('Ícono'),
                  const Gap(10),
                  GoalIconPicker(
                    selected: _icon,
                    onChanged: (icon) => setState(() => _icon = icon),
                  ),
                  const Gap(4),
                  FormError(_error),
                  const Gap(12),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flag_outlined),
                    label: Text(_editing ? 'Guardar cambios' : 'Crear meta'),
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

/// "Fecha objetivo" (optional): the day to reach the goal by, and how much
/// that takes per month for the amount typed in [amount].
class GoalDateField extends StatelessWidget {
  const GoalDateField({
    super.key,
    required this.value,
    required this.amount,
    required this.onChanged,
    this.saved = 0,
  });

  final DateTime? value;
  final TextEditingController amount;
  final double saved;
  final ValueChanged<DateTime?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = value != null && !value!.isBefore(today)
        ? value!
        : DateTime(now.year, now.month + 6, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: DateTime(now.year + 30, 12, 31),
      initialDate: initial,
      helpText: '¿Para cuándo la quieres?',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InsetGroup(
          children: [
            InsetTile(
              icon: CupertinoIcons.calendar,
              title: 'Fecha objetivo',
              trailing: Text(
                value == null
                    ? 'Opcional'
                    : Formatters.dayMonthYear.format(value!),
                style: TextStyle(color: value == null ? palette.muted : null),
              ),
              onTap: () => _pick(context),
            ),
            if (value != null)
              InsetTile(
                icon: CupertinoIcons.xmark_circle,
                title: 'Quitar fecha',
                destructive: true,
                onTap: () => onChanged(null),
              ),
          ],
        ),
        if (value != null)
          // Only the hint follows each key, not the form.
          ListenableBuilder(
            listenable: amount,
            builder: (context, _) {
              final target =
                  double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
              final plan = goalPlan(
                SavingsGoal(
                  id: '',
                  name: '',
                  targetAmount: target,
                  savedAmount: saved,
                  icon: '',
                  bgColor: '',
                  iconColor: '',
                  progressPercent: 0,
                  targetDate: value,
                ),
                const [],
                now: DateTime.now(),
              );
              final perMonth = plan.perMonth;
              if (perMonth == null || target <= 0) {
                return const SizedBox.shrink();
              }
              final months = plan.monthsLeft!;
              return Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  'Ahorra ${context.money(perMonth)} al mes '
                  '(${months == 1 ? '1 mes' : '$months meses'}) para llegar.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              );
            },
          ),
      ],
    );
  }
}
