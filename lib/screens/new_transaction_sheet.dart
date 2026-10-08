import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/duplicates.dart';
import '../core/utils/formatters.dart';
import '../core/utils/receipt_scan.dart';
import '../core/utils/wallet.dart';
import '../models/category.dart';
import '../models/payment_method.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../services/receipt_scanner.dart';
import '../services/transaction_service.dart';
import '../widgets/app_states.dart';
import '../widgets/icon_mapper.dart';
import '../widgets/ios_ui.dart';
import '../widgets/payment_method_picker.dart';
import 'category_sheet.dart';
import '../core/theme/motion.dart';

/// Opens the form to register a movement, or to edit [transaction] when given.
/// [repeat] preselects a recurring frequency for a new movement.
Future<void> showNewTransactionSheet(
  BuildContext context, {
  TransactionType initialType = TransactionType.income,
  Transaction? transaction,
  RecurrenceFrequency? repeat,
}) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    // Above the shell's floating tab bar.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => NewTransactionSheet(
      initialType: transaction?.type ?? initialType,
      transaction: transaction,
      repeat: repeat,
    ),
  );
}

class NewTransactionSheet extends ConsumerStatefulWidget {
  const NewTransactionSheet({
    super.key,
    required this.initialType,
    this.transaction,
    this.repeat,
  });

  final TransactionType initialType;
  final Transaction? transaction;
  final RecurrenceFrequency? repeat;

  @override
  ConsumerState<NewTransactionSheet> createState() =>
      _NewTransactionSheetState();
}

class _NewTransactionSheetState extends ConsumerState<NewTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.transaction?.amount.toStringAsFixed(2),
  );
  late final _title = TextEditingController(text: widget.transaction?.title);
  late TransactionType _type = widget.initialType;
  late DateTime _date = widget.transaction?.date.toLocal() ?? DateTime.now();
  late String? _categoryId = widget.transaction?.category.id;

  /// How it was paid. Until the user picks one, a new movement uses the
  /// method of their last movement of the same type ([_methodFor]).
  late String? _paymentMethodId = widget.transaction?.paymentMethodId;
  late bool _methodPicked = _editing;
  late String? _reference = widget.transaction?.reference;

  /// What the last scan filled in, shown above the form to review.
  ScanDraft? _scanned;

  /// null = a one-off movement; otherwise a recurring rule is created.
  late RecurrenceFrequency? _repeat = widget.repeat;
  bool _saving = false;

  bool get _editing => widget.transaction != null;

  /// Opens the scanner and fills in what it read; the user reviews it.
  Future<void> _scan() async {
    final draft = await ref.read(scanLauncherProvider)(context);
    if (draft == null || !mounted) return;
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final history =
        ref.read(transactionsProvider(null)).value ?? const <Transaction>[];
    setState(() {
      _scanned = draft;
      _type = TransactionType.expense;
      if (draft.amount case final amount?) {
        _amount.text = amount.toStringAsFixed(2);
      }
      if (draft.merchant case final merchant?) _title.text = merchant;
      if (draft.date case final date?) {
        final now = DateTime.now();
        // Keep the current time so same-day movements stay in order.
        _date = DateTime(date.year, date.month, date.day, now.hour, now.minute);
        if (_date.isAfter(now)) _date = now;
      }
      if (draft.reference case final reference?) _reference = reference;
      _categoryId =
          suggestCategoryId(draft.merchant, history, categories) ??
          (categories.any(
                (c) => c.id == _categoryId && c.type == TransactionType.expense,
              )
              ? _categoryId
              : null);
    });
  }

  String? _methodFor(List<PaymentMethod> methods) {
    if (_methodPicked) return _paymentMethodId;
    final transactions =
        ref.read(transactionsProvider(null)).value ?? const <Transaction>[];
    return lastUsedPaymentMethodId(transactions, methods, _type);
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) {
      if (_categoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una categoría')),
        );
      }
      return;
    }

    final title = _title.text.trim();
    final amount = double.parse(_amount.text.replaceAll(',', '.'));
    // The same receipt scanned twice, or a double tap: ask before saving.
    if (!_editing && _repeat == null) {
      final duplicate = findLikelyDuplicate(
        existing:
            ref.read(transactionsProvider(null)).value ?? const <Transaction>[],
        type: _type,
        amount: amount,
        date: _date,
        title: title,
        reference: _reference,
      );
      if (duplicate != null) {
        final again = await confirmAction(
          context,
          title: '¿Registrarlo de nuevo?',
          message:
              'Ya tienes "${duplicate.title}" por '
              '${Formatters.compactMoney(duplicate.amount)} '
              '(${Formatters.dayLabel(duplicate.date).toLowerCase()}). '
              'Puede ser el mismo ticket.',
          confirmLabel: 'Registrar igual',
          destructive: false,
        );
        if (!again || !mounted) return;
      }
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(transactionServiceProvider);
    final paymentMethodId = _methodFor(
      ref.read(paymentMethodsProvider).value ?? const [],
    );
    try {
      if (_editing) {
        await service.update(
          widget.transaction!.id,
          title: title,
          amount: amount,
          type: _type,
          categoryId: _categoryId!,
          date: _date,
          paymentMethodId: paymentMethodId,
          reference: _reference,
        );
      } else if (_repeat case final frequency?) {
        // The API creates this first movement (and the next ones) itself.
        await ref
            .read(financeRepositoryProvider)
            .createRecurring(
              title: title,
              amount: amount,
              type: _type,
              categoryId: _categoryId!,
              frequency: frequency,
              startDate: _date,
              paymentMethodId: paymentMethodId,
            );
      } else {
        await service.create(
          title: title,
          amount: amount,
          type: _type,
          categoryId: _categoryId!,
          date: _date,
          paymentMethodId: paymentMethodId,
          reference: _reference,
        );
      }
      refreshFinance(ref);
      // Saved: a firm tap, like Apple Pay's confirmation.
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _editing
                ? 'Movimiento actualizado'
                : _repeat != null
                ? 'Se repetirá ${_repeat!.every}'
                : _type == TransactionType.income
                ? 'Ingreso registrado'
                : 'Gasto registrado',
          ),
        ),
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
    final categories = ref.watch(categoriesProvider);
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    // Rebuilds once movements load, for the last-used method.
    ref.watch(transactionsProvider(null));
    final isIncome = _type == TransactionType.income;
    final palette = context.palette;
    final (tint, accent) = isIncome
        ? (palette.mint, palette.onMint)
        : (palette.blush, palette.onBlush);
    final mutedText = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: .66);

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
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: tint,
                      child: Icon(
                        isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: accent,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _editing
                                ? 'Editar movimiento'
                                : isIncome
                                ? 'Registrar ingreso'
                                : 'Registrar gasto',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                          ),
                          const Gap(4),
                          Text(
                            isIncome
                                ? 'Agrega dinero recibido a tu balance.'
                                : 'Registra un gasto y mantén el control.',
                            style: TextStyle(
                              color: mutedText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_editing) ...[
                      const Gap(8),
                      CircleButton(
                        icon: CupertinoIcons.qrcode_viewfinder,
                        tooltip: 'Escanear factura o ticket',
                        onPressed: _scan,
                      ),
                    ],
                  ],
                ),
                if (_scanned case final scanned?) ...[
                  const Gap(14),
                  _ScanNote(draft: scanned),
                ],
                const Gap(18),
                SegmentedTabs(
                  segments: const {
                    TransactionType.expense: 'Gasto',
                    TransactionType.income: 'Ingreso',
                  },
                  selected: _type,
                  onChanged: (value) => setState(() {
                    _type = value;
                    _categoryId = null;
                  }),
                ),
                const Gap(16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: EntranceAutofocus(
                    enabled: !_editing,
                    builder: (context, focusNode) => TextFormField(
                      controller: _amount,
                      focusNode: focusNode,
                      textInputAction: TextInputAction.next,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: accent,
                        height: 1,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Monto',
                        labelStyle: TextStyle(color: accent),
                        floatingLabelStyle: TextStyle(color: accent),
                        prefixText: r'$ ',
                        prefixStyle: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: accent,
                              height: 1,
                            ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
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
                  ),
                ),
                const Gap(14),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    counterText: '',
                    labelText: 'Descripción',
                    hintText: 'Ej. Almuerzo en la facultad',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Escribe una descripción'
                      : null,
                ),
                const Gap(18),
                Text(
                  'Categoría',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Gap(10),
                categories.when(
                  loading: () =>
                      const SizedBox(height: 90, child: AppShimmer()),
                  error: (error, _) => Row(
                    children: [
                      Expanded(child: Text(error.toString())),
                      TextButton(
                        onPressed: () => ref.invalidate(categoriesProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (items) {
                    final filtered = items
                        .where((c) => c.type == _type)
                        .toList();
                    if (_categoryId == null && filtered.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && _categoryId == null) {
                          setState(() => _categoryId = filtered.first.id);
                        }
                      });
                    }
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final category in filtered)
                          ChoiceChip(
                            avatar: Icon(
                              iconFromApi(category.icon),
                              size: 18,
                              color: _categoryId == category.id ? accent : null,
                            ),
                            label: Text(category.name),
                            selected: _categoryId == category.id,
                            onSelected: (_) =>
                                setState(() => _categoryId = category.id),
                          ),
                        // Create a category without leaving the form; it
                        // comes back selected.
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Nueva'),
                          tooltip: 'Nueva categoría',
                          onPressed: () async {
                            final created = await showCategorySheet(
                              context,
                              type: _type,
                            );
                            if (created != null && mounted) {
                              setState(() => _categoryId = created.id);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),

                const Gap(18),
                Text(
                  isIncome ? 'Recibido en' : 'Pagado con',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Gap(10),
                PaymentMethodPicker(
                  methods: methods,
                  selected: _methodFor(methods),
                  onChanged: (id) => setState(() {
                    _methodPicked = true;
                    _paymentMethodId = id;
                  }),
                ),
                const Gap(16),
                Material(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: now,
                        initialDate: _date,
                        helpText: 'Fecha del movimiento',
                      );
                      // Keep the current time so same-day movements stay in order.
                      if (picked != null) {
                        setState(
                          () => _date = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            now.hour,
                            now.minute,
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .7),
                            size: 20,
                          ),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              Formatters.dayLabel(_date),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: .4),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_editing) ...[
                  const Gap(16),
                  Text(
                    'Repetir',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Gap(10),
                  SegmentedTabs<RecurrenceFrequency?>(
                    selected: _repeat,
                    onChanged: (value) => setState(() => _repeat = value),
                    segments: const {
                      null: 'No',
                      RecurrenceFrequency.weekly: 'Cada semana',
                      RecurrenceFrequency.monthly: 'Cada mes',
                    },
                  ),
                ],
                const Gap(16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(shape: const StadiumBorder()),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.onPill,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _editing
                        ? 'Guardar cambios'
                        : isIncome
                        ? 'Guardar ingreso'
                        : 'Guardar gasto',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Above the form after a scan: where the data came from, so it gets
/// reviewed, and a link to the invoice on Hacienda's site.
class _ScanNote extends StatelessWidget {
  const _ScanNote({required this.draft});

  final ScanDraft draft;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final message = switch (draft.source) {
      ScanSource.invoice when draft.amount == null =>
        'Tomé la fecha de la factura. Escribe el monto: el QR de Hacienda '
            'no lo trae.',
      ScanSource.invoice || ScanSource.receiptText =>
        'Leí el ticket. Revisa el monto y el comercio antes de guardar.',
      ScanSource.paymentQr => 'Datos del código de pago. Revísalos.',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.mint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.sparkles, color: palette.onMint, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: palette.onMint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (draft.invoiceUrl case final url?)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: palette.onMint,
                padding: const EdgeInsets.only(left: 22),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () =>
                  launchUrl(url, mode: LaunchMode.externalApplication),
              icon: const Icon(CupertinoIcons.arrow_up_right_square, size: 18),
              label: const Text('Ver factura en Hacienda'),
            ),
        ],
      ),
    );
  }
}
