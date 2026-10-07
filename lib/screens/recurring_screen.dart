import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/formatters.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../providers/finance_providers.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import 'category_sheet.dart';
import 'new_transaction_sheet.dart';
import '../core/theme/motion.dart';
import '../widgets/payment_method_picker.dart';

/// Weekly and monthly movements the API creates on its own.
class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(recurringProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(recurringProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/profile'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LargeTitle(
                    title: 'Recurrentes',
                    subtitle: 'Mesada, alquiler, suscripciones…',
                    trailing: [
                      CircleButton(
                        icon: CupertinoIcons.add,
                        tooltip: 'Nuevo recurrente',
                        filled: true,
                        onPressed: () => showNewTransactionSheet(
                          context,
                          initialType: TransactionType.expense,
                          repeat: RecurrenceFrequency.monthly,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  rules.when(
                    loading: () =>
                        const SizedBox(height: 240, child: AppShimmer()),
                    error: (error, _) => AppErrorState(
                      message: error.toString(),
                      onRetry: () => ref.invalidate(recurringProvider),
                    ),
                    data: (items) => items.isEmpty
                        ? const _EmptyRecurring()
                        : _RecurringList(items: items),
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

class _RecurringList extends StatelessWidget {
  const _RecurringList({required this.items});

  final List<RecurringRule> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    // Net monthly effect of the active rules (a week ≈ 4.33 per month).
    double monthly(TransactionType type) => items
        .where((r) => r.active && r.type == type)
        .fold(
          0.0,
          (sum, r) =>
              sum +
              r.amount *
                  (r.frequency == RecurrenceFrequency.weekly ? 52 / 12 : 1),
        );
    final income = monthly(TransactionType.income);
    final expense = monthly(TransactionType.expense);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeSlideIn(
          child: Row(
            children: [
              Expanded(
                child: _Total(
                  label: 'Entra al mes',
                  value: income,
                  color: palette.accent,
                  onColor: palette.onAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Total(
                  label: 'Sale al mes',
                  value: expense,
                  color: palette.ink,
                  onColor: palette.onInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FadeSlideIn(
          index: 1,
          child: BentoCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (i, rule) in items.indexed) ...[
                  if (i > 0) const Divider(indent: 72, height: 1),
                  _RecurringRow(rule: rule),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  final String label;
  final double value;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return BentoCard(
      color: color,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: onColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.compactMoney(value),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final (tile, onTile) = categoryColors(palette, rule.type);
    final next = DateFormat("d 'de' MMM", 'es').format(rule.nextDate.toLocal());
    final income = rule.type == TransactionType.income;
    return ListTile(
      onTap: () => showModalBottomSheet<void>(
        sheetAnimationStyle: Motion.sheet,
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => _RecurringSheet(rule: rule),
      ),
      minTileHeight: 68,
      contentPadding: const EdgeInsets.only(left: 14, right: 6),
      leading: Opacity(
        opacity: rule.active ? 1 : .45,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tile,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(iconFromApi(rule.category.icon), color: onTile, size: 22),
        ),
      ),
      title: Text(
        rule.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        rule.active
            ? '${income ? '+' : '−'}${Formatters.compactMoney(rule.amount)} · '
                  '${rule.frequency.label} · próximo $next'
            : 'En pausa',
        style: TextStyle(color: palette.muted),
      ),
      trailing: AppSwitch(
        value: rule.active,
        onChanged: (value) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref
                .read(financeRepositoryProvider)
                .updateRecurring(rule.id, active: value);
            refreshFinance(ref);
          } catch (error) {
            messenger.showSnackBar(SnackBar(content: Text(error.toString())));
          }
        },
      ),
    );
  }
}

/// Edits the title, amount and frequency of a rule, or deletes it.
class _RecurringSheet extends ConsumerStatefulWidget {
  const _RecurringSheet({required this.rule});

  final RecurringRule rule;

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.rule.title);
  late final _amount = TextEditingController(
    text: widget.rule.amount.toStringAsFixed(2),
  );
  late RecurrenceFrequency _frequency = widget.rule.frequency;
  late String? _paymentMethodId = widget.rule.paymentMethodId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
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
    _run(
      () => ref
          .read(financeRepositoryProvider)
          .updateRecurring(
            widget.rule.id,
            title: _title.text.trim(),
            amount: double.parse(_amount.text.replaceAll(',', '.')),
            frequency: _frequency,
            setPaymentMethod: true,
            paymentMethodId: _paymentMethodId,
          ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: '¿Eliminar "${widget.rule.title}"?',
      message:
          'No se crearán más movimientos. Los que ya se registraron se '
          'quedan en tu historial.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    _run(
      () => ref.read(financeRepositoryProvider).deleteRecurring(widget.rule.id),
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
                'Editar recurrente',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.rule.category.name} · ${widget.rule.type.label}',
                style: TextStyle(color: palette.muted),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Escribe una descripción'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: r'$ ',
                ),
                validator: (v) {
                  final value = double.tryParse((v ?? '').replaceAll(',', '.'));
                  return value == null || value <= 0
                      ? 'Escribe un monto mayor a 0'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              SegmentedTabs<RecurrenceFrequency>(
                selected: _frequency,
                onChanged: (value) => setState(() => _frequency = value),
                segments: const {
                  RecurrenceFrequency.weekly: 'Cada semana',
                  RecurrenceFrequency.monthly: 'Cada mes',
                },
              ),
              const SizedBox(height: 16),
              Text(
                widget.rule.type == TransactionType.income
                    ? 'Recibido en'
                    : 'Pagado con',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              PaymentMethodPicker(
                methods: ref.watch(paymentMethodsProvider).value ?? const [],
                selected: _paymentMethodId,
                onChanged: (id) => setState(() => _paymentMethodId = id),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PillCta(
                label: 'Guardar cambios',
                loading: _saving,
                onPressed: _save,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(CupertinoIcons.trash, size: 18),
                label: const Text('Eliminar recurrente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecurring extends StatelessWidget {
  const _EmptyRecurring();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BentoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const Mascot(mood: MascotMood.calm, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nada se repite todavía',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Al registrar un movimiento, elige "Cada semana" o '
                      '"Cada mes" y yo lo anoto por ti.',
                      style: TextStyle(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            onPressed: () => showNewTransactionSheet(
              context,
              initialType: TransactionType.income,
              repeat: RecurrenceFrequency.monthly,
            ),
            icon: const Icon(CupertinoIcons.repeat),
            label: const Text('Crear recurrente'),
          ),
        ],
      ),
    );
  }
}
