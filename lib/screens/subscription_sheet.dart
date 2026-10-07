import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/formatters.dart';
import '../core/utils/subscriptions.dart';
import '../core/utils/wallet.dart';
import '../models/category.dart';
import '../models/recurring.dart';
import '../providers/finance_providers.dart';
import '../widgets/ios_ui.dart';
import '../widgets/payment_method_picker.dart';
import '../widgets/service_logo.dart';

/// Picks a service from the catalog; returns its key ([otherServiceKey] for
/// one that isn't listed), or null when dismissed.
Future<String?> showServicePicker(BuildContext context) {
  return showModalBottomSheet<String>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ServicePicker(),
  );
}

class _ServicePicker extends StatelessWidget {
  const _ServicePicker();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final groups = <String, List<SubscriptionService>>{};
    for (final service in subscriptionCatalog) {
      groups.putIfAbsent(service.group, () => []).add(service);
    }
    Widget tile(String key, String name, Widget logo) => Semantics(
      button: true,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.pop(context, key),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              logo,
              const SizedBox(height: 6),
              Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // Four columns whose rows are as tall as their content.
    Widget grid(List<Widget> children) => LayoutBuilder(
      builder: (context, constraints) => Wrap(
        children: [
          for (final child in children)
            SizedBox(width: constraints.maxWidth / 4, child: child),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Agregar suscripción', style: text.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Elige el servicio. El precio lo escribes tú: cambia según tu '
            'país y plan.',
            style: TextStyle(color: context.palette.muted),
          ),
          for (final MapEntry(key: group, value: services)
              in groups.entries) ...[
            const SizedBox(height: 16),
            Text(group, style: text.titleSmall),
            grid([
              for (final s in services)
                tile(
                  s.key,
                  s.name,
                  ServiceLogo(serviceKey: s.key, name: s.name),
                ),
              if (group == groups.keys.last)
                tile(
                  otherServiceKey,
                  'Otra',
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.add),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Adds a subscription of [serviceKey], or edits [rule].
Future<void> showSubscriptionSheet(
  BuildContext context, {
  String? serviceKey,
  RecurringRule? rule,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _SubscriptionSheet(
      serviceKey: rule?.service ?? serviceKey ?? otherServiceKey,
      rule: rule,
    ),
  );
}

class _SubscriptionSheet extends ConsumerStatefulWidget {
  const _SubscriptionSheet({required this.serviceKey, this.rule});

  final String serviceKey;
  final RecurringRule? rule;

  @override
  ConsumerState<_SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends ConsumerState<_SubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final SubscriptionService? _service = serviceFor(widget.serviceKey);
  late final _name = TextEditingController(
    text: widget.rule?.title ?? _service?.name,
  );
  late final _amount = TextEditingController(
    text: widget.rule?.amount.toStringAsFixed(2),
  );
  late RecurrenceFrequency _frequency =
      widget.rule?.frequency ??
      _service?.frequency ??
      RecurrenceFrequency.monthly;
  late String? _paymentMethodId = widget.rule?.paymentMethodId;
  late bool _active = widget.rule?.active ?? true;

  /// Next charge (new subscriptions): a month from today by default, so
  /// adding one you already pay doesn't record a charge today.
  DateTime _nextCharge = () {
    final now = DateTime.now();
    return dayOfMonth(now.year, now.month + 1, now.day);
  }();
  bool _saving = false;
  String? _error;

  bool get _editing => widget.rule != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// The user's "Suscripciones" expense category, created the first time.
  Future<String> _categoryId() async {
    final categories = await ref.read(categoriesProvider.future);
    final existing = categories
        .where(
          (c) =>
              c.type == TransactionType.expense &&
              c.name.toLowerCase() == 'suscripciones',
        )
        .firstOrNull;
    if (existing != null) return existing.id;
    final created = await ref
        .read(financeRepositoryProvider)
        .createCategory(
          name: 'Suscripciones',
          icon: 'subscriptions',
          type: TransactionType.expense,
        );
    ref.invalidate(categoriesProvider);
    return created.id;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(financeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final name = _name.text.trim();
    final amount = double.parse(_amount.text.replaceAll(',', '.'));
    try {
      if (_editing) {
        await repository.updateRecurring(
          widget.rule!.id,
          title: name,
          amount: amount,
          frequency: _frequency,
          active: _active,
          setPaymentMethod: true,
          paymentMethodId: _paymentMethodId,
        );
      } else {
        await repository.createRecurring(
          title: name,
          amount: amount,
          type: TransactionType.expense,
          categoryId: await _categoryId(),
          frequency: _frequency,
          // Midday, so the local date can't shift with time zones.
          startDate: DateTime(
            _nextCharge.year,
            _nextCharge.month,
            _nextCharge.day,
            12,
          ),
          paymentMethodId: _paymentMethodId,
          service: widget.serviceKey,
        );
      }
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editing ? 'Suscripción actualizada' : '$name agregada',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final rule = widget.rule!;
    final confirmed = await confirmAction(
      context,
      title: '¿Eliminar ${rule.title}?',
      message:
          'Ya no se registrará su cobro. Los cobros pasados quedan en tu '
          'historial.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).deleteRecurring(rule.id);
      refreshFinance(ref);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  ListenableBuilder(
                    listenable: _name,
                    builder: (context, _) => ServiceLogo(
                      serviceKey: widget.serviceKey,
                      name: _name.text.isEmpty ? '?' : _name.text,
                      size: 56,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _editing ? 'Editar suscripción' : 'Nueva suscripción',
                      style: text.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Crunchyroll',
                  counterText: '',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe el nombre' : null,
              ),
              const SizedBox(height: 12),
              EntranceAutofocus(
                enabled: !_editing,
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
                    labelText: 'Precio',
                    prefixText: r'$ ',
                  ),
                  validator: (v) {
                    final value = double.tryParse(
                      (v ?? '').replaceAll(',', '.'),
                    );
                    return value == null || value <= 0
                        ? 'Escribe lo que te cobran'
                        : null;
                  },
                ),
              ),
              const SizedBox(height: 14),
              SegmentedTabs<RecurrenceFrequency>(
                selected: _frequency,
                onChanged: (value) => setState(() => _frequency = value),
                segments: const {
                  RecurrenceFrequency.monthly: 'Mensual',
                  RecurrenceFrequency.yearly: 'Anual',
                },
              ),
              if (!_editing) ...[
                const SizedBox(height: 14),
                InsetGroup(
                  children: [
                    InsetTile(
                      icon: CupertinoIcons.calendar,
                      title: 'Próximo cobro',
                      trailing: Text(Formatters.dayLabel(_nextCharge)),
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: DateTime(now.year + 1, now.month, now.day),
                          initialDate: _nextCharge,
                          helpText: 'Próximo cobro',
                        );
                        if (picked != null) {
                          setState(() => _nextCharge = picked);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Si te cobra hoy, elige hoy y lo registro ya como gasto.',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
              const SizedBox(height: 16),
              Text('Pagado con', style: text.titleSmall),
              const SizedBox(height: 8),
              PaymentMethodPicker(
                methods: ref.watch(paymentMethodsProvider).value ?? const [],
                selected: _paymentMethodId,
                onChanged: (id) => setState(() => _paymentMethodId = id),
              ),
              if (_editing) ...[
                const SizedBox(height: 16),
                InsetGroup(
                  children: [
                    InsetTile(
                      icon: CupertinoIcons.pause_circle,
                      title: 'Activa',
                      trailing: AppSwitch(
                        value: _active,
                        onChanged: (value) => setState(() => _active = value),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.blush,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: palette.onBlush,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PillCta(
                label: _editing ? 'Guardar cambios' : 'Agregar suscripción',
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
                  label: const Text('Eliminar suscripción'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
