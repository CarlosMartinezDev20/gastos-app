import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/formatters.dart';
import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/icon_mapper.dart';
import '../core/theme/app_palette.dart';
import '../widgets/ios_ui.dart';
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
    final palette = context.palette;
    // Same header as the other full-screen pages (Categorías, Calculadora):
    // a round back button and a large title instead of a Material app bar.
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
                children: [
                  Row(
                    children: [
                      CircleButton(
                        icon: CupertinoIcons.chevron_left,
                        tooltip: 'Volver',
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/goals'),
                      ),
                    ],
                  ),
                  const Gap(16),
                  const LargeTitle(
                    title: 'Nueva meta',
                    subtitle: 'Ponle nombre y monto a lo que quieres lograr',
                  ),
                  const Gap(18),
                  BentoCard(
                    color: palette.lilac,
                    child: Row(
                      children: [
                        // Icon tile like the goal cards, on the lilac preview.
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            iconFromApi(_icon),
                            color: palette.onLilac,
                          ),
                        ),
                        const Gap(14),
                        // Only the preview follows each key, not the page.
                        Expanded(
                          child: ListenableBuilder(
                            listenable: Listenable.merge([_name, _amount]),
                            builder: (context, _) {
                              final amount =
                                  double.tryParse(
                                    _amount.text.replaceAll(',', '.'),
                                  ) ??
                                  0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _name.text.trim().isEmpty
                                        ? 'Nombre de la meta'
                                        : _name.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.onLilac,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    amount <= 0
                                        ? 'Monto objetivo'
                                        : Formatters.compactMoney(amount),
                                    style: TextStyle(color: palette.onLilac),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(18),
                  EntranceAutofocus(
                    builder: (context, focusNode) => TextFormField(
                      controller: _name,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la meta',
                        hintText: 'Ej. Nueva laptop',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Escribe un nombre'
                          : null,
                    ),
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
                    validator: (v) {
                      final parsed = double.tryParse(
                        (v ?? '').replaceAll(',', '.'),
                      );
                      return parsed == null || parsed <= 0
                          ? 'Ingresa un monto mayor a 0'
                          : null;
                    },
                  ),
                  const Gap(18),
                  Text(
                    'Ícono',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Gap(10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: goalIcons
                        .map(
                          (option) => ChoiceChip(
                            avatar: Icon(iconFromApi(option.api), size: 18),
                            label: Text(option.label),
                            selected: option.api == _icon,
                            onSelected: (_) =>
                                setState(() => _icon = option.api),
                          ),
                        )
                        .toList(),
                  ),
                  const Gap(24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.flag_outlined),
                    label: const Text('Crear meta'),
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
