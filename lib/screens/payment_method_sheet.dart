import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../models/payment_method.dart';
import '../providers/finance_providers.dart';
import '../widgets/ios_ui.dart';
import '../widgets/wallet_card.dart';

/// Opens the add/edit sheet for a wallet method. Returns the saved method,
/// or null when dismissed or deleted.
Future<PaymentMethod?> showPaymentMethodSheet(
  BuildContext context, {
  PaymentMethod? method,
}) {
  return showModalBottomSheet<PaymentMethod>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => PaymentMethodSheet(method: method),
  );
}

class PaymentMethodSheet extends ConsumerStatefulWidget {
  const PaymentMethodSheet({super.key, this.method});

  final PaymentMethod? method;

  @override
  ConsumerState<PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends ConsumerState<PaymentMethodSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.method?.name);
  late final _last4 = TextEditingController(text: widget.method?.last4);
  late final _bank = TextEditingController(text: widget.method?.bank);
  late final _limit = TextEditingController(
    text: widget.method?.creditLimit?.toStringAsFixed(2),
  );
  late final _statementDay = TextEditingController(
    text: widget.method?.statementDay?.toString(),
  );
  late final _dueDay = TextEditingController(
    text: widget.method?.dueDay?.toString(),
  );
  late PaymentMethodKind _kind =
      widget.method?.kind ?? PaymentMethodKind.creditCard;
  late CardBrand? _brand = widget.method?.brand ?? CardBrand.visa;
  late String _color = widget.method?.color ?? walletCardStyles.keys.first;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.method != null;

  @override
  void dispose() {
    for (final c in [_name, _last4, _bank, _limit, _statementDay, _dueDay]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _trimmed(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  static int? _day(TextEditingController c) => int.tryParse(c.text.trim());

  PaymentMethodInput get _input => PaymentMethodInput(
    name: _name.text.trim(),
    kind: _kind,
    color: _color,
    brand: _brand,
    last4: _trimmed(_last4),
    bank: _trimmed(_bank),
    creditLimit: double.tryParse(_limit.text.replaceAll(',', '.')),
    statementDay: _day(_statementDay),
    dueDay: _day(_dueDay),
  );

  /// What the card preview shows while typing.
  PaymentMethod get _preview {
    final input = _input;
    return PaymentMethod(
      id: 'preview',
      name: input.name.isNotEmpty
          ? input.name
          : _kind.isCard
          ? 'Nueva tarjeta'
          : _kind.label,
      kind: _kind,
      color: _color,
      brand: _kind.isCard ? _brand : null,
      last4: _kind.isCard && (input.last4?.length ?? 0) == 4
          ? input.last4
          : null,
      bank: _kind.hasBank ? input.bank : null,
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(financeRepositoryProvider);
    try {
      final saved = _editing
          ? await repository.updatePaymentMethod(widget.method!.id, _input)
          : await repository.createPaymentMethod(_input);
      ref.invalidate(paymentMethodsProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final method = widget.method!;
    final count = method.transactionCount;
    final confirmed = await confirmAction(
      context,
      title: '¿Quitar "${method.name}" de tu wallet?',
      message: count == 0
          ? 'No tiene movimientos.'
          : 'Sus $count ${count == 1 ? 'movimiento queda' : 'movimientos quedan'} '
                'en tu historial, sin método de pago.',
      confirmLabel: 'Quitar',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(financeRepositoryProvider).deletePaymentMethod(method.id);
      refreshFinance(ref);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final hint = switch (_kind) {
      PaymentMethodKind.creditCard => 'Ej. Visa Agrícola',
      PaymentMethodKind.debitCard => 'Ej. Débito BAC',
      PaymentMethodKind.cash => 'Ej. Efectivo',
      PaymentMethodKind.digital => 'Ej. Tigo Money',
    };
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _editing ? 'Editar método de pago' : 'Agregar a tu wallet',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 16),
              // Live preview: rebuilt by the fields it shows, not the sheet.
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: ListenableBuilder(
                    listenable: Listenable.merge([_name, _last4, _bank]),
                    builder: (context, _) => WalletCard(method: _preview),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SegmentedTabs<PaymentMethodKind>(
                selected: _kind,
                onChanged: (value) => setState(() => _kind = value),
                segments: {
                  for (final kind in PaymentMethodKind.values) kind: kind.label,
                },
              ),
              const SizedBox(height: 14),
              EntranceAutofocus(
                enabled: !_editing,
                builder: (context, focusNode) => TextFormField(
                  controller: _name,
                  focusNode: focusNode,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    hintText: hint,
                    counterText: '',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Ponle un nombre' : null,
                ),
              ),
              if (_kind.isCard) ...[
                const SizedBox(height: 14),
                Text('Marca', style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final brand in CardBrand.values)
                      ChoiceChip(
                        label: Text(brand.label),
                        selected: _brand == brand,
                        onSelected: (_) => setState(() => _brand = brand),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _last4,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Últimos 4 dígitos (opcional)',
                    hintText: '4821',
                    prefixIcon: Icon(CupertinoIcons.lock),
                  ),
                  validator: (v) => v == null || v.isEmpty || v.length == 4
                      ? null
                      : 'Escribe los 4 dígitos',
                ),
                const SizedBox(height: 6),
                Text(
                  'Nunca pedimos ni guardamos el número completo, el CVV ni '
                  'la fecha de vencimiento.',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
              if (_kind.hasBank) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bank,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _kind.isCard
                        ? 'Banco (opcional)'
                        : 'App o proveedor (opcional)',
                    hintText: _kind.isCard
                        ? 'Ej. Banco Agrícola'
                        : 'Ej. Tigo Money',
                    counterText: '',
                  ),
                ),
              ],
              if (_kind.isCredit) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _limit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Límite de crédito (opcional)',
                    prefixText: r'$ ',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final value = double.tryParse(v.replaceAll(',', '.'));
                    return value == null || value <= 0
                        ? 'Escribe un monto mayor a 0'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DayField(
                        controller: _statementDay,
                        label: 'Día de corte',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DayField(
                        controller: _dueDay,
                        label: 'Día de pago',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Con el día de corte te muestro lo gastado en cada estado '
                  'de cuenta; con el de pago, cuánto falta para pagar.',
                  style: text.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
              const SizedBox(height: 16),
              Text('Color', style: text.titleSmall),
              const SizedBox(height: 10),
              _ColorPicker(
                selected: _color,
                onSelected: (color) => setState(() => _color = color),
              ),
              AnimatedSize(
                duration: Motion.of(context, Motion.medium),
                curve: Motion.standard,
                child: _error == null
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 16),
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
              ),
              const SizedBox(height: 20),
              PillCta(
                label: _editing ? 'Guardar cambios' : 'Agregar a mi wallet',
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
                  label: const Text('Quitar de la wallet'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayField extends StatelessWidget {
  const _DayField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(2),
    ],
    decoration: InputDecoration(labelText: label, hintText: '1–31'),
    validator: (v) {
      if (v == null || v.isEmpty) return null;
      final day = int.tryParse(v);
      return day == null || day < 1 || day > 31 ? 'Entre 1 y 31' : null;
    },
  );
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final ring = Theme.of(context).colorScheme.onSurface;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final MapEntry(key: key, value: style) in walletCardStyles.entries)
          Semantics(
            button: true,
            selected: key == selected,
            label: style.label,
            child: GestureDetector(
              onTap: () => onSelected(key),
              child: AnimatedContainer(
                duration: Motion.of(context, Motion.fast),
                curve: Motion.standard,
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: key == selected ? ring : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: style.colors),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
