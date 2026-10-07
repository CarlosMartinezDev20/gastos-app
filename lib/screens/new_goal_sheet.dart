import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../models/savings_goal.dart';
import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../core/theme/motion.dart';

/// Opens the form to create a goal, or to edit [goal] when given.
Future<void> showNewGoalSheet(BuildContext context, {SavingsGoal? goal}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    // Above the shell's floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NewGoalSheet(goal: goal),
  );
}

class GoalIconOption {
  const GoalIconOption(this.api, this.label);
  final String api;
  final String label;
}

const goalIcons = [
  GoalIconOption('laptop_mac', 'Laptop'),
  GoalIconOption('flight', 'Avión'),
  GoalIconOption('school', 'Graduación'),
  GoalIconOption('sports_esports', 'Control'),
  GoalIconOption('directions_car', 'Carro'),
  GoalIconOption('home', 'Casa'),
  GoalIconOption('volunteer_activism', 'Mano'),
  GoalIconOption('auto_awesome', 'Magia'),
];

class NewGoalSheet extends ConsumerStatefulWidget {
  const NewGoalSheet({super.key, this.goal});

  final SavingsGoal? goal;

  @override
  ConsumerState<NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends ConsumerState<NewGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.goal?.name);
  late final _amount = TextEditingController(
    text: widget.goal?.targetAmount.toStringAsFixed(2),
  );
  late String _icon = widget.goal?.icon ?? goalIcons.first.api;
  bool _saving = false;

  bool get _editing => widget.goal != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
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
        );
      } else {
        await service.createGoal(
          name: name,
          targetAmount: target,
          icon: _icon,
          bgColor: 'bg-rose-500/10',
          iconColor: 'text-rose-500',
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
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardInset(
      extra: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
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
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (!_editing)
                      IconButton(
                        tooltip: 'Pantalla completa',
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/goals/new');
                        },
                        icon: const Icon(Icons.open_in_full),
                      ),
                  ],
                ),
                const Gap(18),
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
                const Gap(14),
                TextFormField(
                  controller: _amount,
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
                const Gap(18),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: goalIcons
                      .map(
                        (option) => Tooltip(
                          message: option.label,
                          child: Semantics(
                            button: true,
                            selected: _icon == option.api,
                            label: option.label,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => _icon = option.api),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _icon == option.api
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: .16)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  iconFromApi(option.api),
                                  color: _icon == option.api
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Gap(18),
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
    );
  }
}
