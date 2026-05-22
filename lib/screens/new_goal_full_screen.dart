import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/soft_card.dart';
import 'new_goal_sheet.dart';

class NewGoalFullScreen extends ConsumerStatefulWidget {
  const NewGoalFullScreen({super.key});

  @override
  ConsumerState<NewGoalFullScreen> createState() => _NewGoalFullScreenState();
}

class _NewGoalFullScreenState extends ConsumerState<NewGoalFullScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  DateTime? _deadline;
  String _icon = goalIcons.first.api;
  Color _color = AppColors.primary;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _description.dispose();
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
      context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Meta creada')));
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
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Meta')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
            children: [
              SoftCard(
                color: _color.withValues(alpha: .12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _color,
                      child: Icon(iconFromApi(_icon), color: Colors.white),
                    ),
                    const Gap(14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name.text.isEmpty ? 'Nombre de meta' : _name.text,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            amount <= 0
                                ? 'Monto objetivo'
                                : r'$ '
                                      '$amount',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nombre de meta'),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
              ),
              const Gap(14),
              TextFormField(
                controller: _amount,
                decoration: const InputDecoration(
                  labelText: 'Monto objetivo',
                  prefixText: r'$ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final parsed = double.tryParse(
                    (v ?? '').replaceAll(',', '.'),
                  );
                  return parsed == null || parsed <= 0 ? 'Monto válido' : null;
                },
              ),
              const Gap(14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: goalIcons
                    .map(
                      (option) => ChoiceChip(
                        avatar: Icon(iconFromApi(option.api), size: 18),
                        label: Text(option.label),
                        selected: option.api == _icon,
                        onSelected: (_) => setState(() => _icon = option.api),
                      ),
                    )
                    .toList(),
              ),
              const Gap(14),
              Wrap(
                spacing: 10,
                children:
                    [
                          AppColors.primary,
                          AppColors.income,
                          const Color(0xFF5465FF),
                          const Color(0xFFFFB000),
                        ]
                        .map(
                          (color) => InkWell(
                            onTap: () => setState(() => _color = color),
                            child: CircleAvatar(backgroundColor: color),
                          ),
                        )
                        .toList(),
              ),
              const Gap(14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  _deadline == null
                      ? 'Fecha límite'
                      : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                    initialDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
              ),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción opcional',
                ),
              ),
              const Gap(20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Crear Meta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
