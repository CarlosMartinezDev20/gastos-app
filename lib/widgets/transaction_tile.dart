import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/formatters.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../screens/new_transaction_sheet.dart';
import '../services/transaction_service.dart';
import '../core/theme/app_palette.dart';
import 'icon_mapper.dart';
import '../core/theme/motion.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});
  final Transaction transaction;

  void _openDetail(BuildContext context) => showModalBottomSheet<void>(
    sheetAnimationStyle: Motion.sheet,
    context: context,
    // Above the shell's floating tab bar.
    useRootNavigator: true,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _TransactionDetail(transaction: transaction),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    // Goal withdrawals add to the balance, so they read like income.
    final income =
        transaction.type == TransactionType.income ||
        transaction.isGoalWithdrawal;
    final (tint, onTint) = income
        ? (palette.mint, palette.onMint)
        : transaction.isGoalContribution
        ? (palette.lilac, palette.onLilac)
        : (palette.blush, palette.onBlush);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Icon(
          iconFromApi(transaction.category.icon),
          color: onTint,
          size: 21,
        ),
      ),
      title: Text(
        transaction.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(
          TextSpan(
            children: [
              // Marks movements a recurring rule created.
              if (transaction.isRecurring)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              TextSpan(
                text:
                    '${transaction.category.name} · ${Formatters.shortDate.format(transaction.date.toLocal())}',
              ),
            ],
          ),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Container(
          // Income gets a lime badge.
          padding: income
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
              : EdgeInsets.zero,
          decoration: income
              ? BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(999),
                )
              : null,
          child: Text(
            _signedAmount(transaction),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: income ? palette.onAccent : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      onTap: () => _openDetail(context),
    );
  }
}

String _signedAmount(Transaction transaction) {
  final positive =
      transaction.type == TransactionType.income ||
      transaction.isGoalWithdrawal;
  return '${positive ? '+' : '−'}'
      '${Formatters.compactMoney(transaction.amount.abs())}';
}

class _TransactionDetail extends ConsumerStatefulWidget {
  const _TransactionDetail({required this.transaction});

  final Transaction transaction;

  @override
  ConsumerState<_TransactionDetail> createState() => _TransactionDetailState();
}

class _TransactionDetailState extends ConsumerState<_TransactionDetail> {
  bool _deleting = false;

  Transaction get _tx => widget.transaction;

  void _edit() {
    // Open the form from the screen underneath once this sheet is closed.
    final parent = Navigator.of(context).context;
    Navigator.pop(context);
    showNewTransactionSheet(parent, transaction: _tx);
  }

  /// Deletes at once and offers to undo, instead of asking first: faster,
  /// and a mistaken tap costs nothing.
  Future<void> _delete() async {
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    // The sheet closes before an undo: keep what it needs.
    final service = ref.read(transactionServiceProvider);
    final container = ProviderScope.containerOf(context);
    final tx = _tx;
    try {
      await service.delete(tx.id);
      refreshFinance(ref);
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('"${tx.title}" eliminado'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              try {
                await service.create(
                  title: tx.title,
                  amount: tx.amount,
                  type: tx.type,
                  categoryId: tx.category.id,
                  date: tx.date,
                  paymentMethodId: tx.paymentMethodId,
                  reference: tx.reference,
                );
                refreshFinanceIn(container);
              } catch (error) {
                messenger.showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final income = _tx.type == TransactionType.income;
    final method = (ref.watch(paymentMethodsProvider).value ?? const [])
        .where((m) => m.id == _tx.paymentMethodId)
        .firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailHero(transaction: _tx),
          const SizedBox(height: 18),
          Text(_tx.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            _signedAmount(_tx),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: income ? palette.onMint : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.hairline),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  _DetailFact(label: 'Categoría', value: _tx.category.name),
                  VerticalDivider(color: palette.hairline, width: 1),
                  _DetailFact(
                    label: 'Fecha',
                    value: Formatters.fullDate.format(_tx.date.toLocal()),
                  ),
                  VerticalDivider(color: palette.hairline, width: 1),
                  _DetailFact(label: 'Tipo', value: _tx.type.label),
                ],
              ),
            ),
          ),
          if (method != null)
            _DetailRow(
              icon: CupertinoIcons.creditcard,
              label: income ? 'Recibido en' : 'Pagado con',
              value: [method.name, ?method.masked].join(' '),
            ),
          if (_tx.reference case final reference?)
            _DetailRow(
              icon: CupertinoIcons.number,
              label: 'Referencia',
              value: reference,
            ),
          const SizedBox(height: 16),
          if (_tx.isGoalContribution) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Es un movimiento de una meta. Si eliminas la meta, su dinero vuelve a tu balance.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(context);
                GoRouter.of(context).go('/goals');
              },
              icon: const Icon(Icons.savings_outlined),
              label: const Text('Ir a Metas'),
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      foregroundColor: scheme.error,
                      side: BorderSide(
                        color: scheme.error.withValues(alpha: .4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _deleting ? null : _delete,
                    icon: _deleting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _deleting ? null : _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Pastel cover with the category icon, like the reference's recipe photo.
class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.transaction});

  final Transaction transaction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (tint, onTint) = transaction.type == TransactionType.income
        ? (palette.mint, palette.onMint)
        : transaction.isGoalContribution
        ? (palette.lilac, palette.onLilac)
        : (palette.blush, palette.onBlush);
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .55),
            shape: BoxShape.circle,
          ),
          child: Icon(
            iconFromApi(transaction.category.icon),
            size: 46,
            color: onTint,
          ),
        ),
      ),
    );
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.palette.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// One extra fact under the detail's summary box.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: muted)),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
