import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../core/utils/transaction_filter.dart';
import '../models/transaction_page.dart';
import 'auth_provider.dart';
import 'finance_providers.dart';

/// What Historial shows for one set of filters: the pages loaded so far
/// and the totals of everything that matches.
class HistoryState {
  const HistoryState({
    required this.items,
    required this.summary,
    this.nextCursor,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Transaction> items;
  final HistorySummary summary;
  final String? nextCursor;
  final bool loadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;
}

/// Historial, a page at a time. One list per [HistoryQuery], dropped when
/// no longer shown (each keystroke of a search is a new query).
final historyProvider = AsyncNotifierProvider.autoDispose
    .family<HistoryNotifier, HistoryState, HistoryQuery>(HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<HistoryState> {
  HistoryNotifier(this.query);

  final HistoryQuery query;

  static const pageSize = 50;

  /// The API's largest page.
  static const maxPage = 100;

  @override
  Future<HistoryState> build() async {
    ref.watch(currentUserIdProvider);
    // A refresh (e.g. after editing a movement deep in the list) reloads as
    // many as were on screen, so the list doesn't jump back to the top.
    final loaded = state.value?.items.length ?? 0;
    final repository = ref.watch(financeRepositoryProvider);
    if (query.paymentMethodId != null) {
      // The deployed API supports category filtering but not payment methods.
      // Fetch the complete matching history so totals never cover just one page.
      final params = query.apiParams;
      final all = await repository.transactions(
        type: query.type,
        from: params['from'] == null ? null : DateTime.parse(params['from']!),
        to: params['to'] == null ? null : DateTime.parse(params['to']!),
      );
      final items = filterTransactions(
        all,
        query: query.search,
        type: query.type,
        categoryId: query.categoryId,
        paymentMethodId: query.paymentMethodId,
        from: query.from,
        to: query.to,
      );
      double total(TransactionType type) => items
          .where((t) => t.type == type)
          .fold(0.0, (sum, t) => sum + t.amount);
      return HistoryState(
        items: items,
        summary: HistorySummary(
          count: items.length,
          income: total(TransactionType.income),
          expense: total(TransactionType.expense),
        ),
      );
    }
    final page = await ref
        .watch(financeRepositoryProvider)
        .transactionPage(query, limit: loaded.clamp(pageSize, maxPage));
    return HistoryState(
      items: page.items,
      summary: page.summary!,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        state.isLoading) {
      return;
    }
    state = AsyncData(_with(current, loadingMore: true));
    try {
      final page = await ref
          .read(financeRepositoryProvider)
          .transactionPage(query, cursor: current.nextCursor);
      // Disposed, or refreshed meanwhile: that list is gone.
      if (!ref.mounted || !identical(state.value?.items, current.items)) {
        return;
      }
      state = AsyncData(
        HistoryState(
          items: [...current.items, ...page.items],
          summary: current.summary,
          nextCursor: page.nextCursor,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(_with(current, error: error));
    }
  }

  static HistoryState _with(
    HistoryState s, {
    bool loadingMore = false,
    Object? error,
  }) => HistoryState(
    items: s.items,
    summary: s.summary,
    nextCursor: s.nextCursor,
    loadingMore: loadingMore,
    loadMoreError: error,
  );
}
