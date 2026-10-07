import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/formatters.dart';
import '../core/utils/wallet.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../widgets/animated_progress.dart';
import '../widgets/app_states.dart';
import '../widgets/ios_ui.dart';
import '../widgets/mascot.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/wallet_card.dart';
import 'card_payment_sheet.dart';
import 'payment_method_sheet.dart';

/// "Mi wallet": the user's cards and other payment methods, each with what
/// was spent with it in its current period.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);
    final transactions =
        ref.watch(transactionsProvider(null)).value ?? const <Transaction>[];
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: RefreshIndicator(
              onRefresh: () => Future.wait([
                ref.refresh(paymentMethodsProvider.future),
                ref.refresh(transactionsProvider(null).future),
              ]),
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
                    title: 'Mi wallet',
                    subtitle: 'Tus tarjetas y formas de pago',
                    trailing: [
                      CircleButton(
                        icon: CupertinoIcons.add,
                        tooltip: 'Agregar método de pago',
                        filled: true,
                        onPressed: () => showPaymentMethodSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...methods.when(
                    loading: () => const [
                      SizedBox(height: 200, child: AppShimmer()),
                    ],
                    error: (error, _) => [
                      AppErrorState(
                        message: error.toString(),
                        onRetry: () => ref.invalidate(paymentMethodsProvider),
                      ),
                    ],
                    data: (items) => items.isEmpty
                        ? const [_EmptyWallet()]
                        : [
                            for (final (i, method) in items.indexed) ...[
                              if (i > 0) const SizedBox(height: 22),
                              FadeSlideIn(
                                index: i,
                                child: _WalletEntry(
                                  summary: summarizeMethod(
                                    method,
                                    transactions,
                                    now,
                                  ),
                                ),
                              ),
                            ],
                          ],
                  ),
                  const SizedBox(height: 24),
                  const _PrivacyNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A card and, for credit cards, how much of the limit it used and when the
/// payment is due.
class _WalletEntry extends StatelessWidget {
  const _WalletEntry({required this.summary});

  final WalletSummary summary;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final limit = summary.limit;
    final due = summary.dueDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Pressable(
          onTap: () => showWalletDetail(context, summary.method.id),
          child: WalletCard(method: summary.method, summary: summary),
        ),
        if (summary.debt != null || limit != null || due != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (limit != null) ...[
                  AnimatedProgressBar(
                    value: summary.utilization ?? 0,
                    height: 6,
                    color: (summary.utilization ?? 0) > 1
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  [
                    if (summary.debt case final debt?) _debtLabel(debt),
                    if (summary.available case final available?)
                      available < 0
                          ? 'Pasaste el límite por '
                                '${Formatters.compactMoney(-available)}'
                          : 'Disponible ${Formatters.compactMoney(available)} '
                                'de ${Formatters.compactMoney(limit!)}',
                    if (due != null) _dueLabel(due),
                  ].join(' · '),
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

String _debtLabel(double debt) => debt > 0
    ? 'Debes ${Formatters.compactMoney(debt)}'
    : debt < 0
    ? '${Formatters.compactMoney(-debt)} a favor'
    : 'Al día';

String _dueLabel(DateTime due) {
  final days = daysUntil(due, DateTime.now());
  return switch (days) {
    0 => 'Pago hoy',
    1 => 'Pago mañana',
    _ => 'Pago en $days días',
  };
}

/// Details of one method: its card, this period's numbers and movements.
Future<void> showWalletDetail(BuildContext context, String methodId) {
  return showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _WalletDetail(methodId: methodId),
  );
}

class _WalletDetail extends ConsumerWidget {
  const _WalletDetail({required this.methodId});

  final String methodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    final method = methods.where((m) => m.id == methodId).firstOrNull;
    // Deleted from the edit sheet: nothing left to show.
    if (method == null) return const SizedBox(height: 120);
    final transactions =
        ref.watch(transactionsProvider(null)).value ?? const <Transaction>[];
    final summary = summarizeMethod(method, transactions, DateTime.now());
    final dayMonth = DateFormat("d 'de' MMMM", 'es');
    final shortDay = DateFormat('d MMM', 'es');
    final facts = <(IconData, String, String)>[
      (
        CupertinoIcons.cart,
        summary.byStatement ? 'Gastado en este corte' : 'Gastado este mes',
        Formatters.compactMoney(summary.spent),
      ),
      if (summary.debt case final debt?)
        (CupertinoIcons.money_dollar_circle, 'Deuda actual', _debtLabel(debt)),
      if (summary.lastStatementSpent case final last? when last > 0)
        (
          CupertinoIcons.doc_text,
          'Último corte',
          Formatters.compactMoney(last),
        ),
      if (summary.limit case final limit?)
        (CupertinoIcons.gauge, 'Límite', Formatters.compactMoney(limit)),
      if (summary.closesOn case final close?)
        (CupertinoIcons.scissors, 'Fecha de corte', dayMonth.format(close)),
      if (summary.dueDate case final due?)
        (
          CupertinoIcons.calendar,
          'Fecha de pago',
          '${shortDay.format(due)} · ${_dueLabel(due).replaceFirst('Pago ', '')}',
        ),
    ];
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
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: WalletCard(method: method, summary: summary),
            ),
          ),
          const SizedBox(height: 18),
          InsetGroup(
            children: [
              for (final (icon, label, value) in facts)
                InsetTile(
                  icon: icon,
                  title: label,
                  trailing: Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            summary.byStatement
                ? 'Movimientos de este corte'
                : 'Movimientos de este mes',
            style: text.titleMedium,
          ),
          const SizedBox(height: 8),
          if (summary.movements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Todavía no pagaste nada con ${method.name} en este periodo. '
                'Elígela en "Pagado con" al registrar un gasto.',
                style: TextStyle(color: palette.muted),
              ),
            )
          else
            BentoCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final t in summary.movements.take(8))
                    TransactionTile(transaction: t),
                ],
              ),
            ),
          const SizedBox(height: 18),
          if (method.kind.isCredit) ...[
            _CardPayments(methodId: method.id),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => showCardPaymentSheet(context, summary: summary),
              icon: const Icon(CupertinoIcons.checkmark_seal),
              label: const Text('Registrar pago'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: () => showPaymentMethodSheet(context, method: method),
            icon: const Icon(CupertinoIcons.pencil, size: 18),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyWallet extends StatelessWidget {
  const _EmptyWallet();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return BentoCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              const Mascot(mood: MascotMood.happy, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu wallet está vacía',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Agrega tus tarjetas, efectivo o apps de pago y te '
                      'digo cuánto gastas con cada una.',
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
            onPressed: () => showPaymentMethodSheet(context),
            icon: const Icon(CupertinoIcons.add),
            label: const Text('Agregar método de pago'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.muted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(CupertinoIcons.lock_shield, size: 18, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Solo guardamos el nombre y los últimos 4 dígitos. Nunca el '
            'número completo, el CVV ni la fecha de vencimiento.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// Scales down while pressed (a transform, like BentoCard) without clipping
/// the card's shadow.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  var _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _pressed ? .97 : 1,
        duration: Motion.of(context, Motion.fast),
        curve: Motion.standard,
        child: widget.child,
      ),
    ),
  );
}

/// Payments made to a credit card; a wrong one can be deleted.
class _CardPayments extends ConsumerWidget {
  const _CardPayments({required this.methodId});

  final String methodId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(cardPaymentsProvider(methodId)).value;
    if (payments == null || payments.isEmpty) return const SizedBox.shrink();
    final methods = ref.watch(paymentMethodsProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Text('Pagos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        InsetGroup(
          children: [
            for (final payment in payments.take(6))
              InsetTile(
                icon: CupertinoIcons.checkmark_seal_fill,
                iconColor: context.palette.onMint,
                title: [
                  Formatters.dayLabel(payment.date),
                  if (methods
                          .where((m) => m.id == payment.fromMethodId)
                          .firstOrNull
                      case final from?)
                    'desde ${from.name}',
                ].join(' · '),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.compactMoney(payment.amount),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      tooltip: 'Borrar pago',
                      icon: const Icon(CupertinoIcons.trash, size: 18),
                      onPressed: () async {
                        final confirmed = await confirmAction(
                          context,
                          title: '¿Borrar este pago?',
                          message: 'Vuelve a contar como deuda de la tarjeta.',
                          confirmLabel: 'Borrar',
                        );
                        if (!confirmed) return;
                        await ref
                            .read(financeRepositoryProvider)
                            .deleteCardPayment(payment.id);
                        refreshFinance(ref);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
