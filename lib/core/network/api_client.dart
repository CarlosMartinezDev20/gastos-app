import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/storage_provider.dart';
import '../errors/api_exception.dart';
import 'response_cache.dart';
import 'token_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(tokenStoreProvider),
    ResponseCache(ref.watch(sharedPreferencesProvider)),
  );
});

class ApiClient {
  ApiClient(this._store, [this._cache])
    : dio = Dio(
        BaseOptions(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://localhost:3001',
          ),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          offline.value = false;
          final user = tokenSubject(_token);
          if (_cache != null &&
              user != null &&
              response.requestOptions.method == 'GET') {
            _cache.save(user, response.requestOptions, response.data);
          }
          handler.next(response);
        },
        onError: (error, handler) {
          // No connection: answer a GET with its last saved result.
          final user = tokenSubject(_token);
          final cached =
              _cache != null &&
                  user != null &&
                  error.requestOptions.method == 'GET' &&
                  isOfflineError(error)
              ? _cache.read(user, error.requestOptions)
              : null;
          if (cached != null) {
            offline.value = true;
            handler.resolve(
              Response(
                requestOptions: error.requestOptions,
                data: cached,
                statusCode: 200,
                extra: {'fromCache': true},
              ),
            );
            return;
          }
          final hadToken =
              error.requestOptions.headers['Authorization'] != null;
          if (error.response?.statusCode == 401 && hadToken) {
            // Expired or revoked token: drop the session instead of failing
            // every screen with "Unauthorized".
            clearToken();
            onUnauthorized?.call();
          }
          handler.reject(error);
        },
      ),
    );
  }

  final TokenStore _store;
  final ResponseCache? _cache;
  final Dio dio;

  /// True while screens show saved data because the API can't be reached.
  final offline = ValueNotifier(false);

  /// In memory after [restoreToken], so requests don't wait on storage.
  String? _token;

  /// Called when an authenticated request gets a 401. Set by AuthController.
  void Function()? onUnauthorized;

  String? get token => _token;

  /// Loads the saved session, once, before the first request.
  Future<void> restoreToken() async => _token ??= await _store.read();

  Future<void> saveToken(String token) {
    _token = token;
    return _store.write(token);
  }

  /// Signing out also forgets the saved answers (financial data).
  Future<void> clearToken() async {
    _token = null;
    offline.value = false;
    await _cache?.clear();
    await _store.delete();
  }

  ApiException parseError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      String message = 'No se pudo conectar con la API.';
      if (data is Map<String, dynamic>) {
        final raw = data['message'];
        if (raw is List) message = raw.join('\n');
        if (raw is String) message = raw;
      } else if (error.message != null) {
        message = error.message!;
      }
      return ApiException(message, statusCode: error.response?.statusCode);
    }
    return ApiException(error.toString());
  }
}
