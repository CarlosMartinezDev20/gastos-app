import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/storage_provider.dart';
import '../errors/api_exception.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ApiClient(prefs);
});

class ApiClient {
  ApiClient(this._prefs)
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
          final token = _prefs.getString(_tokenKey);
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

  static const _tokenKey = 'access_token';
  final SharedPreferences _prefs;
  final Dio dio;

  /// Called when an authenticated request gets a 401. Set by AuthController.
  void Function()? onUnauthorized;

  String? get token => _prefs.getString(_tokenKey);

  Future<void> saveToken(String token) => _prefs.setString(_tokenKey, token);

  Future<void> clearToken() => _prefs.remove(_tokenKey);

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
