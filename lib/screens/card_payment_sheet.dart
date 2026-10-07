import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/formatters.dart';
import '../core/utils/wallet.dart';
import '../providers/finance_providers.dart';
import '../widgets/ios_ui.dart';
import '../widgets/payment_method_picker.dart';

/// Records a payment to a credit card. It isn't an expense — the purchases
/// already were — so it lowers what is owed, not the balance.
Future<void> showCardPaymentSheet(
  BuildContext context, {
  required WalletSummary summary,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _CardPaymentSheet(summary: summary),
  );
}

class _CardPaymentSheet extends ConsumerStatefulWidget {
  const _CardPaymentSheet({required this.summary});

  final WalletSummary summary;

  @override
  ConsumerState<_CardPaymentSheet> createState() => _CardPaymentSheetState();
}

class _CardPaymentSheetState extends ConsumerState<_CardPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: _suggestions.firstOrNull?.$2.toStringAsFixed(2),
  );
  DateTime _date = DateTime.now();
  String? _fromMethodId;
  bool _saving = false;
  String? _error;

  /// Amounts worth paying: the whole debt and the last statement.
  late final List<(String, double)> _suggestions = [
    if ((widget.summary.lastStatementSpent ?? 0) > 0 &&
        widget.summary.lastStatementSpent != widget.summary.debt)
      ('Último corte', widget.summary.lastStatementSpent!),
    if ((widget.summary.debt ?? 0) > 0) ('Deuda total', widget.summary.debt!),
  ];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(financeRepositoryProvider)
          .addCardPayment(
            widget.summary.method.id,
            amount: double.parse(_amount.text.replaceAll(',', '.')),
            date: _date,
            fromMethodId: _fromMethodId,
          );
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(content: Text('Pago registrado')));
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
    final sources = (ref.watch(paymentMethodsProvider).value ?? const [])
        .where((m) => !m.kind.isCredit)
        .toList();
    return KeyboardInset(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pagar ${widget.summary.method.name}',
                style: text.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'No cuenta como gasto: tus compras con la tarjeta ya lo '
                'hicieron. Solo baja lo que debes.',
                style: TextStyle(color: palette.muted),
              ),
              const SizedBox(height: 16),
              EntranceAutofocus(
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
                    labelText: 'Monto pagado',
                    prefixText: r'$ ',
                  ),
                  validator: (v) {
                    final value = double.tryParse(
                      (v ?? '').replaceAll(',', '.'),
                    );
                    return value == null || value <= 0
                        ? 'Escribe un monto mayor a 0'
                        : null;
                  },
                ),
              ),
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, value) in _suggestions)
                      ActionChip(
                        label: Text(
                          '$label · ${Formatters.compactMoney(value)}',
                        ),
                        onPressed: () =>
                            _amount.text = value.toStringAsFixed(2),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              InsetGroup(
                children: [
                  InsetTile(
                    icon: CupertinoIcons.calendar,
                    title: 'Fecha',
                    trailing: Text(Formatters.dayLabel(_date)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDate: _date,
                        helpText: 'Fecha del pago',
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                ],
              ),
              if (sources.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Desde (opcional)', style: text.titleSmall),
                const SizedBox(height: 8),
                PaymentMethodPicker(
                  methods: sources,
                  selected: _fromMethodId,
                  onChanged: (id) => setState(() => _fromMethodId = id),
                  allowAdd: false,
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
                label: 'Registrar pago',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
