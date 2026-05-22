import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/icon_mapper.dart';

Future<void> showNewGoalSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const NewGoalSheet(),
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
  const NewGoalSheet({super.key});

  @override
  ConsumerState<NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends ConsumerState<NewGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  String _icon = goalIcons.first.api;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(savingsServiceProvider)
          .createGoal(
            name: _name.text.trim(),
            targetAmount: double.parse(_amount.text.replaceAll(',', '.')),
            icon: _icon,
            bgColor: 'bg-rose-500/10',
            iconColor: 'text-rose-500',
          );
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proyecto de ahorro creado')),
      );
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
                      'Nueva Meta de Ahorro',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
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
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre del proyecto',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
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
                  return parsed == null || parsed <= 0 ? 'Monto válido' : null;
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
                      (option) => InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => setState(() => _icon = option.api),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _icon == option.api
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .16)
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
                    )
                    .toList(),
              ),
              const Gap(18),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Crear Proyecto de Ahorro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
