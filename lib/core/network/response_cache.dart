import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last successful answer of each GET, per user, so the app can show
/// it when there is no connection. Cleared on logout.
class ResponseCache {
  ResponseCache(this._prefs, {this.maxEntries = 40});

  final SharedPreferences _prefs;

  /// SharedPreferences is read whole at startup and rewritten on every
  /// change, so only the most recently saved answers are kept.
  final int maxEntries;

  static const _prefix = 'api_cache:';

  /// The saved keys, oldest first.
  static const _orderKey = 'api_cache_order';

  String _key(String user, RequestOptions options) =>
      '$_prefix$user:${options.uri.path}?${options.uri.query}';

  /// Searches and later pages of a list vary with every keystroke and
  /// scroll; offline, the first page of each list is enough.
  static bool worthSaving(RequestOptions options) {
    final query = options.uri.queryParameters;
    return !query.containsKey('cursor') && (query['q'] ?? '').isEmpty;
  }

  Future<void> save(String user, RequestOptions options, Object? data) async {
    if (!worthSaving(options)) return;
    final key = _key(user, options);
    final body = jsonEncode(data);
    final saved = _prefs.getStringList(_orderKey);
    final order = [...saved ?? const <String>[]]
      ..remove(key)
      ..add(key);
    final evicted = order.length > maxEntries
        ? order.sublist(0, order.length - maxEntries)
        : <String>[];
    // No index yet: answers saved by older versions (every search and page)
    // go away once.
    if (saved == null) {
      evicted.addAll(
        _prefs.getKeys().where((k) => k.startsWith(_prefix) && k != key),
      );
    }
    order.removeRange(0, order.length - math.min(order.length, maxEntries));
    // Every write starts before the first await: SharedPreferences updates
    // its memory at once, so answers arriving together can't lose a key.
    await Future.wait([
      _prefs.setStringList(_orderKey, order),
      for (final old in evicted) _prefs.remove(old),
      // The same answer as last time: no need to rewrite the file.
      if (_prefs.getString(key) != body) _prefs.setString(key, body),
    ]);
  }

  /// The cached body, or null when this request was never answered.
  Object? read(String user, RequestOptions options) {
    final raw = _prefs.getString(_key(user, options));
    return raw == null ? null : jsonDecode(raw);
  }

  Future<void> clear() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await _prefs.remove(key);
    }
    await _prefs.remove(_orderKey);
  }
}

/// Failures that mean "no connection", not an API answer.
bool isOfflineError(DioException error) => switch (error.type) {
  DioExceptionType.connectionError ||
  DioExceptionType.connectionTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.sendTimeout => true,
  _ => false,
};

/// The user id (`sub`) inside a JWT, to keep each account's cache apart.
String? tokenSubject(String? token) {
  final parts = token?.split('.');
  if (parts == null || parts.length != 3) return null;
  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    return (jsonDecode(payload) as Map<String, dynamic>)['sub'] as String?;
  } catch (_) {
    return null;
  }
}
