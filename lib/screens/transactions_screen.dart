import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_palette.dart';
import '../core/theme/motion.dart';
import '../core/utils/csv_export.dart';
import '../core/utils/file_export/file_export.dart';
import '../core/utils/formatters.dart';
import '../core/utils/transaction_filter.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/transaction_page.dart';
import '../providers/finance_providers.dart';
import '../providers/history_provider.dart';
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

  /// The search the list was asked for; it follows the field after a pause
  /// in typing, so each keystroke doesn't hit the API.
  String _searched = '';
  Timer? _debounce;

  /// The last list shown, kept on screen while new filters load.
  HistoryState? _shown;

  /// Swiped away: off the list at once, before the reload confirms it.
  final _swiped = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  TransactionType? get _transactionType => switch (_type) {
    _TypeFilter.all => null,
    _TypeFilter.expense => TransactionType.expense,
    _TypeFilter.income => TransactionType.income,
  };

  HistoryQuery get _query => (
    search: _searched,
    type: _transactionType,
    from: _range?.start,
    to: _range?.end,
  );

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searched = value.trim());
    });
  }

  void _reset() => setState(() {
    _debounce?.cancel();
    _search.clear();
    _searched = '';
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

  /// Downloads every movement that matches the filters (not only the pages
  /// loaded) as CSV on the web; other platforms get it on the clipboard.
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final query = _query;
    final List<Transaction> items;
    try {
      items = filterTransactions(
        await ref
            .read(financeRepositoryProvider)
            .transactions(type: query.type),
        query: query.search,
        from: query.from,
        to: query.to,
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    }
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
    final query = _query;
    final history = ref.watch(historyProvider(query));
    if (history.value case final value?) _shown = value;
    final shown = _shown;
    if (shown == null) {
      if (history.hasError) {
        return AppErrorState(
          message: history.error.toString(),
          onRetry: () => ref.invalidate(historyProvider(query)),
        );
      }
      return const AppShimmer();
    }
    return _buildContent(
      shown,
      query: query,
      // New filters loading while the previous list stays on screen.
      updating: history.isLoading && history.value == null,
      error: history.value == null ? history.error : null,
    );
  }

  Widget _buildContent(
    HistoryState history, {
    required HistoryQuery query,
    required bool updating,
    Object? error,
  }) {
    final palette = context.palette;
    final filtered = history.items
        .where((t) => !_swiped.contains(t.id))
        .toList();
    final hasFilters = _search.text.isNotEmpty || query.hasFilters;
    final income = history.summary.income;
    final expenses = history.summary.expense;
    final count = history.summary.count;
    // One inset group per day, like a grouped iOS list.
    final days = <({String heading, List<Transaction> items})>[];
    DateTime? previousDay;
    for (final transaction in filtered) {
      final local = transaction.date.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (day != previousDay) {
        days.add((heading: Formatters.dayLabel(day), items: []));
        previousDay = day;
      }
      days.last.items.add(transaction);
    }

    return CollapsingTitle(
      title: 'Movimientos',
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(historyProvider(query).future),
        child: NotificationListener<ScrollNotification>(
          // The next page loads before the end comes into view.
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.vertical &&
                notification.metrics.extentAfter < 800 &&
                history.hasMore &&
                !updating) {
              ref.read(historyProvider(query).notifier).loadMore();
            }
            return false;
          },
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
                            icon: CupertinoIcons.repeat,
                            tooltip: 'Movimientos recurrentes',
                            onPressed: () => context.push('/recurring'),
                          ),
                          CircleButton(
                            icon: CupertinoIcons.arrow_down_doc,
                            tooltip: 'Exportar CSV',
                            onPressed: _export,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CupertinoSearchTextField(
                        controller: _search,
                        placeholder: 'Buscar por nombre o categoría',
                        onChanged: _onSearchChanged,
                        onSuffixTap: () {
                          _search.clear();
                          _onSearchChanged('');
                        },
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
                              onChanged: (value) =>
                                  setState(() => _type = value),
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
                            avatar: const Icon(
                              CupertinoIcons.calendar,
                              size: 16,
                            ),
                            label: Text(
                              '${Formatters.fullDate.format(_range!.start)} – ${Formatters.fullDate.format(_range!.end)}',
                            ),
                            onDeleted: () => setState(() => _range = null),
                            deleteButtonTooltipMessage:
                                'Quitar filtro de fechas',
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
                              '$count ${count == 1 ? 'movimiento' : 'movimientos'} · balance ${Formatters.compactMoney(income - expenses)}',
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
              if (updating || error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: error != null
                        ? _LoadError(
                            message: error.toString(),
                            onRetry: () =>
                                ref.invalidate(historyProvider(query)),
                          )
                        : const LinearProgressIndicator(minHeight: 2),
                  ),
                ),
              if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        AppEmptyState(
                          title: !hasFilters
                              ? 'Tu historial empieza aquí'
                              : 'Sin coincidencias',
                          subtitle: !hasFilters
                              ? 'Registra tu primer movimiento para empezar a llevar el control.'
                              : 'Prueba otro nombre o cambia los filtros.',
                        ),
                        if (!hasFilters)
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
                  // Dimmed while the list for new filters is on its way.
                  sliver: SliverAnimatedOpacity(
                    opacity: updating ? .45 : 1,
                    duration: Motion.of(context, Motion.fast),
                    sliver: SliverList.builder(
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
                              child: Text(
                                day.heading,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ),
                            BentoCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  for (final (i, t) in day.items.indexed) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        indent: 72,
                                        color: palette.hairline,
                                      ),
                                    _SwipeToDelete(
                                      key: ValueKey(t.id),
                                      transaction: t,
                                      onDeleted: () =>
                                          setState(() => _swiped.add(t.id)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              if (history.hasMore || history.loadMoreError != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: history.loadingMore
                          ? const CupertinoActivityIndicator()
                          : history.loadMoreError != null
                          ? _LoadError(
                              message: history.loadMoreError.toString(),
                              onRetry: () => ref
                                  .read(historyProvider(query).notifier)
                                  .loadMore(),
                            )
                          : TextButton(
                              onPressed: () => ref
                                  .read(historyProvider(query).notifier)
                                  .loadMore(),
                              child: Text(
                                'Ver más (${count - filtered.length} restantes)',
                              ),
                            ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: dockClearance(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A movement row that deletes when swiped to the left, like iOS Mail,
/// with the same "Deshacer" as the detail sheet. Goal contributions are
/// managed from Metas, so they don't swipe.
class _SwipeToDelete extends ConsumerWidget {
  const _SwipeToDelete({
    super.key,
    required this.transaction,
    required this.onDeleted,
  });

  final Transaction transaction;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TransactionTile(transaction: transaction),
    );
    if (transaction.isGoalContribution) return tile;
    final error = Theme.of(context).colorScheme.error;
    return Dismissible(
      key: ValueKey('swipe-${transaction.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: .35},
      movementDuration: Motion.of(context, Motion.medium),
      resizeDuration: Motion.of(context, Motion.medium),
      onUpdate: (details) {
        // A tick when the swipe crosses the point of no return.
        if (details.reached && !details.previousReached) {
          HapticFeedback.mediumImpact();
        }
      },
      background: Container(
        color: error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.trash, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) =>
          deleteTransactionWithUndo(context, ref, transaction),
      onDismissed: (_) => onDeleted(),
      child: tile,
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(message, style: TextStyle(color: context.palette.muted)),
      ),
      TextButton(onPressed: onRetry, child: const Text('Reintentar')),
    ],
  );
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
          child: AnimatedAmount(
            amount,
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
