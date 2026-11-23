import '../widgets/money_privacy.dart';
import '../widgets/form_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../providers/finance_providers.dart';
import '../services/savings_service.dart';
import '../widgets/icon_mapper.dart';
import '../core/theme/app_palette.dart';
import '../widgets/ios_ui.dart';
import '../widgets/goal_icon_picker.dart';
import '../widgets/unsaved_changes_guard.dart';
import 'new_goal_sheet.dart';

typedef GoalDraft = ({
  String name,
  String amount,
  String icon,
  DateTime? targetDate,
});

class NewGoalFullScreen extends ConsumerStatefulWidget {
  const NewGoalFullScreen({super.key, this.draft});

  final GoalDraft? draft;

  @override
  ConsumerState<NewGoalFullScreen> createState() => _NewGoalFullScreenState();
}

class _NewGoalFullScreenState extends ConsumerState<NewGoalFullScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.draft?.name);
  late final _amount = TextEditingController(text: widget.draft?.amount);
  late String _icon = widget.draft?.icon ?? goalIcons.first.api;
  late DateTime? _targetDate = widget.draft?.targetDate;

  bool get _hasChanges =>
      _name.text.isNotEmpty ||
      _amount.text.isNotEmpty ||
      _icon != goalIcons.first.api ||
      _targetDate != null;
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
            targetDate: _targetDate,
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
    return UnsavedChangesGuard(
      controllers: [_name, _amount],
      hasChanges: () => _hasChanges,
      saving: _saving,
      child: Scaffold(
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
                          onPressed: () {
                            if (!_saving) Navigator.maybePop(context);
                          },
                        ),
                      ],
                    ),
                    const Gap(16),
                    const LargeTitle(title: 'Nueva meta'),
                    const Gap(FormLayout.sectionGap),
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
                          const Gap(FormLayout.fieldGap),
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
                                          : context.money(amount),
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
                    const Gap(FormLayout.sectionGap),
                    EntranceAutofocus(
                      builder: (context, focusNode) => TextFormField(
                        maxLength: 60,
                        controller: _name,
                        focusNode: focusNode,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          counterText: '',
                          labelText: 'Nombre de la meta',
                          hintText: 'Ej. Nueva laptop',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Escribe un nombre'
                            : null,
                      ),
                    ),
                    const Gap(FormLayout.fieldGap),
                    TextFormField(
                      controller: _amount,
                      decoration: const InputDecoration(
                        labelText: 'Monto objetivo',
                        prefixText: r'$ ',
                      ),
                      obscureText: MoneyPrivacyScope.hiddenOf(context),
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
                    const Gap(FormLayout.fieldGap),
                    GoalDateField(
                      value: _targetDate,
                      amount: _amount,
                      onChanged: (day) => setState(() => _targetDate = day),
                    ),
                    const Gap(FormLayout.sectionGap),
                    const FormSectionLabel('Ícono'),
                    const Gap(10),
                    GoalIconPicker(
                      selected: _icon,
                      onChanged: (icon) => setState(() => _icon = icon),
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
      ),
    );
  }
}
