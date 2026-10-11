import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/storage_provider.dart';
import '../auth/auth_gateway.dart';
import '../config/env.dart';
import '../errors/api_exception.dart';
import 'response_cache.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(authGatewayProvider),
    ResponseCache(ref.watch(sharedPreferencesProvider)),
  );
});

/// The NestJS API. Every request carries the Supabase session's access
/// token (`Authorization: Bearer …`), refreshed first when it is about to
/// expire.
class ApiClient {
  ApiClient(this._auth, [this._cache])
    : dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          // The free Render instance sleeps when idle and takes up to about
          // a minute to wake on the first request.
          receiveTimeout: const Duration(seconds: 70),
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.freshAccessToken();
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

  final AuthGateway _auth;
  final ResponseCache? _cache;
  final Dio dio;

  /// True while screens show saved data because the API can't be reached.
  final offline = ValueNotifier(false);

  /// The session's token (Supabase restores it from secure storage at
  /// startup), for the offline cache's user and the signed-in check.
  String? get _token => _auth.accessToken;

  /// Called when an authenticated request gets a 401. Set by AuthController.
  void Function()? onUnauthorized;

  String? get token => _token;

  /// Signing out also forgets the saved answers (financial data).
  Future<void> clearToken() async {
    offline.value = false;
    await _cache?.clear();
    await _auth.signOut();
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
