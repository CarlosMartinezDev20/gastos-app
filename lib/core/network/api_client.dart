import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/api_exception.dart';
import 'token_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStoreProvider));
});

class ApiClient {
  ApiClient(this._store)
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
        onError: (error, handler) {
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
  final Dio dio;

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

  Future<void> clearToken() {
    _token = null;
    return _store.delete();
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
