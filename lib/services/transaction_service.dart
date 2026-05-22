import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import '../providers/finance_providers.dart';

final transactionServiceProvider = Provider<TransactionService>((ref) {
  return TransactionService(ref);
});

class TransactionService {
  const TransactionService(this._ref);

  final Ref _ref;

  Future<Transaction> create({
    required String title,
    required double amount,
    required TransactionType type,
    required String categoryId,
    required DateTime date,
  }) {
    return _ref
        .read(financeRepositoryProvider)
        .createTransaction(
          title: title,
          amount: amount,
          type: type,
          categoryId: categoryId,
          date: date,
        );
  }
}
