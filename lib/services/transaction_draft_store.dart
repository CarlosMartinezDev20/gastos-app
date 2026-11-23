import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TransactionDraftStore {
  Future<Map<String, dynamic>?> read(String key);
  Future<void> write(String key, Map<String, dynamic> draft);
  Future<void> delete(String key);
}

final transactionDraftStoreProvider = Provider<TransactionDraftStore>(
  (ref) => SecureTransactionDraftStore(),
);

/// Drafts contain financial data: use the same system-backed storage as sessions.
/// Ordered operations prevent an older autosave from resurrecting a saved draft.
class SecureTransactionDraftStore implements TransactionDraftStore {
  final _storage = const FlutterSecureStorage();
  Future<void> _pending = Future.value();

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<Map<String, dynamic>?> read(String key) => _run(() async {
    final raw = await _storage.read(key: key);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  });

  @override
  Future<void> write(String key, Map<String, dynamic> draft) =>
      _run(() => _storage.write(key: key, value: jsonEncode(draft)));

  @override
  Future<void> delete(String key) => _run(() => _storage.delete(key: key));
}
