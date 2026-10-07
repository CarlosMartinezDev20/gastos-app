import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last successful answer of each GET, per user, so the app can show
/// it when there is no connection. Cleared on logout.
class ResponseCache {
  ResponseCache(this._prefs);

  final SharedPreferences _prefs;

  static const _prefix = 'api_cache:';

  String _key(String user, RequestOptions options) =>
      '$_prefix$user:${options.uri.path}?${options.uri.query}';

  Future<void> save(String user, RequestOptions options, Object? data) =>
      _prefs.setString(_key(user, options), jsonEncode(data));

  /// The cached body, or null when this request was never answered.
  Object? read(String user, RequestOptions options) {
    final raw = _prefs.getString(_key(user, options));
    return raw == null ? null : jsonDecode(raw);
  }

  Future<void> clear() async {
    for (final key in _prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await _prefs.remove(key);
    }
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
