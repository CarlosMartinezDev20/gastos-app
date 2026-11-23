import '../widgets/money_privacy.dart';
import 'dart:async';
import '../widgets/form_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/duplicates.dart';
import '../core/utils/formatters.dart';
import '../core/utils/receipt_scan.dart';
import '../core/utils/transaction_suggestions.dart';
import '../models/category.dart';
import '../models/payment_method.dart';
import '../models/recurring.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../providers/auth_provider.dart';
import '../services/transaction_draft_store.dart';
import '../services/receipt_scanner.dart';
import '../services/transaction_service.dart';
import '../widgets/app_states.dart';
import '../widgets/unsaved_changes_guard.dart';
import '../widgets/transaction_category_picker.dart';
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
  Transaction? similarTo,
  RecurrenceFrequency? repeat,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final controller = BottomSheet.createAnimationController(
    navigator,
    sheetAnimationStyle: Motion.sheet,
  );
  TransitionRoute<dynamic>? sheetRoute;
  try {
    await showModalBottomSheet<void>(
      sheetAnimationStyle: Motion.sheet,
      context: context,
      // Above the shell's floating tab bar.
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      transitionAnimationController: controller,
      // The inner sheet handles dragging so dismissals consult PopScope.
      enableDrag: false,
      showDragHandle: false,
      builder: (sheetContext) {
        sheetRoute = ModalRoute.of(sheetContext);
        return BottomSheet(
          animationController: controller,
          showDragHandle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          onClosing: () {
            // Keep the panel open while a dirty form asks about discarding.
            // A permitted pop immediately runs the normal exit animation.
            controller.forward();
            Navigator.maybePop(sheetContext);
          },
          builder: (_) => NewTransactionSheet(
            initialType: transaction?.type ?? initialType,
            transaction: transaction,
            similarTo: similarTo,
            repeat: repeat,
          ),
        );
      },
    );
    await sheetRoute?.completed;
  } finally {
    controller.dispose();
  }
}

class NewTransactionSheet extends ConsumerStatefulWidget {
  const NewTransactionSheet({
    super.key,
    required this.initialType,
    this.transaction,
    this.similarTo,
    this.repeat,
  });

  final TransactionType initialType;
  final Transaction? transaction;
  final Transaction? similarTo;
  final RecurrenceFrequency? repeat;

  @override
  ConsumerState<NewTransactionSheet> createState() =>
      _NewTransactionSheetState();
}

class _NewTransactionSheetState extends ConsumerState<NewTransactionSheet>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _categoryAnchor = GlobalKey();
  final _titleFocus = FocusNode(debugLabel: 'Descripción del movimiento');
  final _categoryFocus = FocusNode(debugLabel: 'Categoría del movimiento');
  FocusNode? _amountFocus;
  bool _checkingDuplicate = false;
  late final _amount = TextEditingController(
    text: (widget.transaction ?? widget.similarTo)?.amount.toStringAsFixed(2),
  );
  late final _title = TextEditingController(
    text: (widget.transaction ?? widget.similarTo)?.title,
  );

  /// Shown under the amount, full width: inside the field it would be cut
  /// to the width of the digits.
  final _amountError = ValueNotifier<String?>(null);
  late TransactionType _type =
      widget.transaction?.type ?? widget.similarTo?.type ?? widget.initialType;
  late DateTime _date = widget.transaction?.date.toLocal() ?? DateTime.now();
  late String? _categoryId =
      (widget.transaction ?? widget.similarTo)?.category.id;

  /// How it was paid. Until the user picks one, a new movement uses the
  /// method of their last movement of the same type ([_methodFor]).
  late String? _paymentMethodId =
      (widget.transaction ?? widget.similarTo)?.paymentMethodId;
  late bool _methodPicked = _editing || widget.similarTo != null;
  late String? _reference = widget.transaction?.reference;

  /// What the last scan filled in, shown above the form to review.
  ScanDraft? _scanned;

  /// null = a one-off movement; otherwise a recurring rule is created.
  late RecurrenceFrequency? _repeat = widget.repeat;
  bool _saving = false;
  String? _error;
  Timer? _draftTimer;
  late final TransactionDraftStore _draftStore;
  String? _draftKey;
  bool _draftReady = false;
  late String _lastAmountText;
  late String _lastTitleText;
  bool _restoring = false;
  bool _interacted = false;
  bool _completed = false;
  bool _disposing = false;
  String? _draftStatus;

  Map<String, dynamic> _draft() => {
    'version': 1,
    'amount': _amount.text,
    'title': _title.text,
    'type': _type.name,
    'date': _date.toIso8601String(),
    'categoryId': _categoryId,
    'paymentMethodId': _paymentMethodId,
    'methodPicked': _methodPicked,
    'reference': _reference,
    'repeat': _repeat?.name,
  };

  void _onDraftTextChanged() {
    final changed =
        _amount.text != _lastAmountText || _title.text != _lastTitleText;
    _lastAmountText = _amount.text;
    _lastTitleText = _title.text;
    if (changed) _scheduleDraft();
  }

  void _scheduleDraft() {
    if (!_draftReady || _restoring || _completed || _saving) return;
    _interacted = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_persistDraft()),
    );
  }

  Future<void> _persistDraft() async {
    final key = _draftKey;
    if (_completed || key == null) return;
    if (!_hasChanges) {
      if (_interacted) {
        try {
          await _draftStore.delete(key);
        } catch (_) {
          /* Keep the form open. */
        }
      }
      return;
    }
    final snapshot = _draft();
    try {
      await _draftStore.write(key, snapshot);
      if (mounted && !_disposing && !_completed) {
        super.setState(
          () => _draftStatus = 'Borrador guardado en este dispositivo',
        );
      }
    } catch (_) {
      if (mounted && !_disposing) {
        super.setState(
          () => _draftStatus =
              'No se pudo guardar el borrador. Mantén abierto el formulario.',
        );
      }
    }
  }

  Future<void> _restoreDraft() async {
    final key = _draftKey;
    if (key == null) return;
    try {
      final draft = await _draftStore.read(key);
      if (!mounted || _interacted || draft == null || draft['version'] != 1) {
        return;
      }
      final type = TransactionType.values
          .where((v) => v.name == draft['type'])
          .firstOrNull;
      final date = DateTime.tryParse(draft['date'] as String? ?? '');
      if (type == null ||
          date == null ||
          draft['amount'] is! String ||
          draft['title'] is! String) {
        return;
      }
      _restoring = true;
      setState(() {
        _type = type;
        _date = date;
        _amount.text = draft['amount'] as String;
        _title.text = draft['title'] as String;
        _categoryId = draft['categoryId'] as String?;
        _paymentMethodId = draft['paymentMethodId'] as String?;
        _methodPicked = draft['methodPicked'] == true;
        _reference = draft['reference'] as String?;
        _repeat = RecurrenceFrequency.values
            .where((v) => v.name == draft['repeat'])
            .firstOrNull;
        _draftStatus =
            'Borrador recuperado. Revisa los datos antes de guardar.';
      });
    } catch (_) {
      if (mounted) {
        super.setState(
          () => _draftStatus = 'No se pudo recuperar el borrador.',
        );
      }
    } finally {
      _restoring = false;
    }
  }

  Future<void> _discardDraft() async {
    _draftTimer?.cancel();
    _completed = true;
    try {
      if (_draftKey case final key?) await _draftStore.delete(key);
    } catch (_) {
      _completed = false;
      rethrow;
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _scheduleDraft();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _draftTimer?.cancel();
      unawaited(_persistDraft());
    }
  }

  bool get _editing => widget.transaction != null;

  late final DateTime _initialDate;
  bool get _hasChanges =>
      _amount.text != (widget.transaction?.amount.toStringAsFixed(2) ?? '') ||
      _title.text != (widget.transaction?.title ?? '') ||
      _type != widget.initialType ||
      _date != _initialDate ||
      _categoryId != widget.transaction?.category.id ||
      _methodPicked != _editing ||
      _paymentMethodId != widget.transaction?.paymentMethodId ||
      _repeat != widget.repeat ||
      _scanned != null;

  @override
  void initState() {
    super.initState();
    // Capture the initial date before the user can change it.
    _initialDate = _date;
    _draftStore = ref.read(transactionDraftStoreProvider);
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      final scope = widget.transaction != null
          ? 'edit-${widget.transaction!.id}'
          : widget.similarTo != null
          ? 'similar-${widget.similarTo!.id}'
          : 'new';
      _draftKey = 'transaction_draft_v1:$userId:$scope';
    }
    _lastAmountText = _amount.text;
    _lastTitleText = _title.text;
    _amount.addListener(_onDraftTextChanged);
    _title.addListener(_onDraftTextChanged);
    WidgetsBinding.instance.addObserver(this);
    _draftReady = true;
    unawaited(_restoreDraft());
  }

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
    return suggestedPaymentMethod(
      title: _title.text,
      type: _type,
      methods: methods,
      history: transactions,
    );
  }

  @override
  void dispose() {
    _disposing = true;
    _draftTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (!_completed) unawaited(_persistDraft());
    _amount.removeListener(_onDraftTextChanged);
    _title.removeListener(_onDraftTextChanged);
    _amount.dispose();
    _amountError.dispose();
    _title.dispose();
    _titleFocus.dispose();
    _categoryFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _checkingDuplicate) return;
    final valid = _formKey.currentState!.validate();
    if (!valid || _categoryId == null) {
      final amount = double.tryParse(_amount.text.replaceAll(',', '.'));
      if (amount == null || !amount.isFinite || amount <= 0) {
        _amountFocus?.requestFocus();
      } else if (_title.text.trim().isEmpty) {
        _titleFocus.requestFocus();
      } else if (_categoryId == null) {
        _categoryFocus.requestFocus();
        final anchor = _categoryAnchor.currentContext;
        if (anchor != null) {
          Scrollable.ensureVisible(
            anchor,
            alignment: .5,
            duration: Motion.of(context, Motion.medium),
          );
        }
      }
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
        _checkingDuplicate = true;
        final bool again;
        try {
          again = await confirmAction(
            context,
            title: '¿Registrarlo de nuevo?',
            message:
                'Ya tienes "${duplicate.title}" por '
                '${context.money(duplicate.amount)} '
                '(${Formatters.dayLabel(duplicate.date).toLowerCase()}). '
                'Puede ser el mismo ticket.',
            confirmLabel: 'Registrar igual',
            destructive: false,
          );
        } finally {
          _checkingDuplicate = false;
        }
        if (!again || !mounted) return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
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
      // A failed local cleanup must not turn a committed transaction into a retry.
      try {
        await _discardDraft();
      } catch (_) {
        _completed = true;
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
      setState(() => _error = error.toString());
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
    // The amount stands alone on the sheet, in the label color, like
    // Apple Cash: no tinted box.
    final accent = palette.muted;
    final amountStyle = Theme.of(context).textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 48,
      letterSpacing: -1.5,
      color: Theme.of(context).colorScheme.onSurface,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return UnsavedChangesGuard(
      controllers: [_amount, _title],
      hasChanges: () => _hasChanges,
      saving: _saving,
      onDiscard: _discardDraft,
      child: KeyboardInset(
        extra: 22,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: FormLayout.inset),
          child: Form(
            key: _formKey,
            // The fields scroll; the error and the save button stay pinned
            // above the keyboard, so saving never needs a scroll to find it.
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // The title alone: the Gasto/Ingreso control
                            // below already says what's being recorded.
                            Expanded(
                              child: Text(
                                _editing
                                    ? 'Editar movimiento'
                                    : isIncome
                                    ? 'Registrar ingreso'
                                    : 'Registrar gasto',
                                style: FormLayout.titleStyle(context),
                              ),
                            ),
                            // Like iOS sheets: actions first, close last.
                            if (!_editing) ...[
                              CircleButton(
                                icon: CupertinoIcons.qrcode_viewfinder,
                                tooltip: 'Escanear factura o ticket',
                                onPressed: _scan,
                              ),
                              const Gap(8),
                            ],
                            CircleButton(
                              icon: CupertinoIcons.xmark,
                              tooltip: 'Cerrar formulario',
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.maybePop(context),
                            ),
                          ],
                        ),
                        if (_scanned case final scanned?) ...[
                          const Gap(FormLayout.fieldGap),
                          _ScanNote(draft: scanned),
                        ],
                        const Gap(FormLayout.sectionGap),
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
                        // The amount, large and centered as in Apple Cash: the field
                        // is as wide as what's typed, so the "$" stays beside it.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                          child: Column(
                            children: [
                              IntrinsicWidth(
                                child: EntranceAutofocus(
                                  enabled: !_editing,
                                  builder: (context, focusNode) => TextFormField(
                                    controller: _amount,
                                    focusNode: _amountFocus = focusNode,
                                    textAlign: TextAlign.center,
                                    textInputAction: TextInputAction.next,
                                    obscureText: MoneyPrivacyScope.hiddenOf(
                                      context,
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    style: amountStyle,
                                    decoration: InputDecoration(
                                      labelText: 'Monto',
                                      floatingLabelBehavior:
                                          FloatingLabelBehavior.always,
                                      floatingLabelAlignment:
                                          FloatingLabelAlignment.center,
                                      labelStyle: TextStyle(color: accent),
                                      floatingLabelStyle: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      hintText: '0',
                                      hintStyle: amountStyle?.copyWith(
                                        color: accent.withValues(alpha: .35),
                                      ),
                                      prefixText: r'$',
                                      prefixStyle: amountStyle,
                                      contentPadding: const EdgeInsets.only(
                                        top: 8,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      errorStyle: const TextStyle(
                                        fontSize: 0,
                                        height: 0,
                                      ),
                                      filled: false,
                                    ),
                                    onChanged: (_) => _amountError.value = null,
                                    // An empty error marks the field invalid; the
                                    // message itself goes below, in [_amountError].
                                    validator: (value) {
                                      final parsed = double.tryParse(
                                        (value ?? '').replaceAll(',', '.'),
                                      );
                                      final invalid =
                                          parsed == null || parsed <= 0;
                                      _amountError.value = invalid
                                          ? 'Ingresa un monto mayor a 0'
                                          : null;
                                      return invalid ? '' : null;
                                    },
                                  ),
                                ),
                              ),
                              ValueListenableBuilder(
                                valueListenable: _amountError,
                                builder: (context, error, _) => AnimatedSize(
                                  duration: Motion.of(context, Motion.medium),
                                  curve: Motion.standard,
                                  child: error == null
                                      ? const SizedBox.shrink()
                                      : Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Text(
                                            error,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(FormLayout.fieldGap),
                        TextFormField(
                          controller: _title,
                          focusNode: _titleFocus,
                          textInputAction: TextInputAction.next,
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
                        const Gap(FormLayout.sectionGap),
                        const FormSectionLabel('Categoría'),
                        const Gap(10),
                        categories.when(
                          loading: () =>
                              const SizedBox(height: 90, child: AppShimmer()),
                          error: (error, _) => Row(
                            children: [
                              Expanded(child: Text(error.toString())),
                              TextButton(
                                onPressed: () =>
                                    ref.invalidate(categoriesProvider),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                          data: (items) {
                            final filtered = items
                                .where((c) => c.type == _type)
                                .toList();
                            return ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _title,
                              builder: (context, value, _) {
                                final suggestion = _categoryId == null
                                    ? suggestedCategory(
                                        title: value.text,
                                        type: _type,
                                        categories: filtered,
                                        history:
                                            ref
                                                .read(
                                                  transactionsProvider(null),
                                                )
                                                .value ??
                                            const [],
                                      )
                                    : null;
                                return TransactionCategoryPicker(
                                  key: _categoryAnchor,
                                  focusNode: _categoryFocus,
                                  categories: filtered,
                                  selected: _categoryId,
                                  suggestedId: suggestion?.id,
                                  accent: accent,
                                  onChanged: (id) =>
                                      setState(() => _categoryId = id),
                                  onCreate: () async {
                                    final created = await showCategorySheet(
                                      context,
                                      type: _type,
                                    );
                                    if (created != null && mounted) {
                                      setState(() => _categoryId = created.id);
                                    }
                                  },
                                );
                              },
                            );
                          },
                        ),

                        const Gap(FormLayout.sectionGap),
                        FormSectionLabel(
                          isIncome ? 'Recibido en' : 'Pagado con',
                        ),
                        const Gap(10),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _title,
                          builder: (context, _, child) {
                            final methodId = _methodFor(methods);
                            final suggested = methods
                                .where((m) => m.id == methodId)
                                .firstOrNull;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!_methodPicked && suggested != null) ...[
                                  Text(
                                    'Sugerido: ${suggested.shortLabel}, según tu historial.',
                                    style: TextStyle(
                                      color: palette.muted,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Gap(8),
                                ],
                                PaymentMethodPicker(
                                  methods: methods,
                                  selected: methodId,
                                  onChanged: (id) => setState(() {
                                    _methodPicked = true;
                                    _paymentMethodId = id;
                                  }),
                                ),
                              ],
                            );
                          },
                        ),
                        const Gap(16),
                        // Same fill and corners as the fields above.
                        Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          shape: AppTheme.continuous(20),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
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
                                vertical: 16,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: .7),
                                    size: 22,
                                  ),
                                  const Gap(12),
                                  Expanded(
                                    child: Text(
                                      Formatters.dayLabel(_date),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    color: context.palette.muted,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (!_editing) ...[
                          const Gap(16),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            initiallyExpanded: _repeat != null,
                            title: const Text('Repetir movimiento'),
                            subtitle: Text(
                              _repeat == null
                                  ? 'No se repite'
                                  : _repeat == RecurrenceFrequency.weekly
                                  ? 'Cada semana'
                                  : 'Cada mes',
                            ),
                            children: [
                              SegmentedTabs<RecurrenceFrequency?>(
                                selected: _repeat,
                                onChanged: (value) =>
                                    setState(() => _repeat = value),
                                segments: const {
                                  null: 'No',
                                  RecurrenceFrequency.weekly: 'Cada semana',
                                  RecurrenceFrequency.monthly: 'Cada mes',
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_draftStatus != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _draftStatus!,
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                  ),
                if (_saving)
                  Semantics(
                    liveRegion: true,
                    child: const Text('Guardando movimiento…'),
                  ),
                if (_error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'No se pudo guardar. Tus datos siguen aquí; puedes reintentar.',
                    ),
                  ),
                FormError(_error),
                const Gap(12),
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
