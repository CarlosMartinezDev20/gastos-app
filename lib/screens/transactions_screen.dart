import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_palette.dart';
import '../core/utils/csv_export.dart';
import '../core/utils/file_export/file_export.dart';
import '../core/utils/formatters.dart';
import '../core/utils/transaction_filter.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';
import '../widgets/app_states.dart';
import '../widgets/ios_ui.dart';
import '../widgets/transaction_tile.dart';
import 'new_transaction_sheet.dart';

/// Segment values; null means "all".
enum _TypeFilter { all, expense, income }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});
  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _search = TextEditingController();
  _TypeFilter _type = _TypeFilter.all;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  TransactionType? get _transactionType => switch (_type) {
    _TypeFilter.all => null,
    _TypeFilter.expense => TransactionType.expense,
    _TypeFilter.income => TransactionType.income,
  };

  void _reset() => setState(() {
    _search.clear();
    _type = _TypeFilter.all;
    _range = null;
  });

  Future<void> _pickDates() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      helpText: 'Filtrar por fechas',
      saveText: 'Aplicar',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      fieldStartLabelText: 'Desde',
      fieldEndLabelText: 'Hasta',
    );
    if (mounted && selected != null) setState(() => _range = selected);
  }

  /// Downloads the movements shown (with the current filters) as CSV on the
  /// web; other platforms get it on the clipboard.
  Future<void> _export(List<Transaction> items) async {
    final messenger = ScaffoldMessenger.of(context);
    if (items.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay movimientos para exportar')),
      );
      return;
    }
    final csv = transactionsToCsv(items);
    final count =
        '${items.length} ${items.length == 1 ? 'movimiento' : 'movimientos'}';
    if (canDownloadFiles) {
      await downloadTextFile(csvFileName(DateTime.now()), csv, 'text/csv');
      messenger.showSnackBar(
        SnackBar(content: Text('Descargando $count en CSV')),
      );
    } else {
      await Clipboard.setData(ClipboardData(text: csv));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$count copiados como CSV. Pégalos en una hoja de cálculo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider(null));
    return transactions.when(
      loading: () => const AppShimmer(),
      error: (error, _) => AppErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(transactionsProvider(null)),
      ),
      data: _buildContent,
    );
  }

  Widget _buildContent(List<Transaction> items) {
    final palette = context.palette;
    final filtered = filterTransactions(
      items,
      query: _search.text,
      type: _transactionType,
      from: _range?.start,
      to: _range?.end,
    );
    final hasFilters =
        _search.text.isNotEmpty || _type != _TypeFilter.all || _range != null;
    final income = filtered
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (total, t) => total + t.amount);
    final expenses = filtered
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (total, t) => total + t.amount);
    final rows = <({String? heading, Transaction? transaction})>[];
    DateTime? previousDay;
    for (final transaction in filtered) {
      final local = transaction.date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day != previousDay) {
        rows.add((heading: Formatters.dayLabel(day), transaction: null));
        previousDay = day;
      }
      rows.add((heading: null, transaction: transaction));
    }

    return RefreshIndicator(
      onRefresh: () => ref.refresh(transactionsProvider(null).future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LargeTitle(
                    title: 'Movimientos',
                    subtitle: 'Cada ingreso y cada gasto',
                    trailing: [
                      CircleButton(
                        icon: CupertinoIcons.arrow_down_doc,
                        tooltip: 'Exportar CSV',
                        onPressed: () => _export(filtered),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CupertinoSearchTextField(
                    controller: _search,
                    placeholder: 'Buscar por nombre o categoría',
                    onChanged: (_) => setState(() {}),
                    onSuffixTap: () => setState(_search.clear),
                    backgroundColor: palette.card,
                    style: Theme.of(context).textTheme.bodyLarge,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedTabs(
                          selected: _type,
                          onChanged: (value) => setState(() => _type = value),
                          segments: const {
                            _TypeFilter.all: 'Todos',
                            _TypeFilter.expense: 'Gastos',
                            _TypeFilter.income: 'Ingresos',
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleButton(
                        icon: CupertinoIcons.calendar,
                        tooltip: 'Filtrar por fechas',
                        filled: _range != null,
                        onPressed: _pickDates,
                      ),
                    ],
                  ),
                  if (_range != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InputChip(
                        avatar: const Icon(CupertinoIcons.calendar, size: 16),
                        label: Text(
                          '${Formatters.fullDate.format(_range!.start)} – ${Formatters.fullDate.format(_range!.end)}',
                        ),
                        onDeleted: () => setState(() => _range = null),
                        deleteButtonTooltipMessage: 'Quitar filtro de fechas',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          label: 'Ingresos',
                          amount: income,
                          color: palette.mint,
                          onColor: palette.onMint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Gastos',
                          amount: expenses,
                          color: palette.blush,
                          onColor: palette.onBlush,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${filtered.length} ${filtered.length == 1 ? 'movimiento' : 'movimientos'} · balance ${Formatters.compactMoney(income - expenses)}',
                          style: TextStyle(color: palette.muted),
                        ),
                      ),
                      if (hasFilters)
                        TextButton(
                          onPressed: _reset,
                          child: const Text('Limpiar filtros'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    AppEmptyState(
                      title: items.isEmpty
                          ? 'Tu historial empieza aquí'
                          : 'Sin coincidencias',
                      subtitle: items.isEmpty
                          ? 'Registra tu primer movimiento para empezar a llevar el control.'
                          : 'Prueba otro nombre o cambia los filtros.',
                    ),
                    if (items.isEmpty)
                      FilledButton.icon(
                        onPressed: () => showNewTransactionSheet(
                          context,
                          initialType: TransactionType.expense,
                        ),
                        icon: const Icon(CupertinoIcons.add),
                        label: const Text('Registrar movimiento'),
                      )
                    else
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Ver todos los movimientos'),
                      ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  if (row.heading != null) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                      child: Text(
                        row.heading!,
                        style: Theme.of(
                          context,
                        ).textTheme.titleSmall?.copyWith(color: palette.muted),
                      ),
                    );
                  }
                  return Material(
                    key: ValueKey(row.transaction!.id),
                    color: palette.card,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TransactionTile(transaction: row.transaction!),
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: dockClearance(context))),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.onColor,
  });

  final String label;
  final double amount;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => BentoCard(
    color: color,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: onColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            Formatters.compactMoney(amount),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
