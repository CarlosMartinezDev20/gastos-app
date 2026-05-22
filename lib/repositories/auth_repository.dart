import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/auth_session.dart';
import '../models/user_profile.dart';

class AuthRepository {
  const AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.authLogin,
        data: {'email': email, 'password': password},
      );
      final session = AuthSession.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _api.saveToken(session.accessToken);
      return session;
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _api.dio.post(
        ApiEndpoints.authRegister,
        data: {'name': name, 'email': email, 'password': password},
      );
      final session = AuthSession.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _api.saveToken(session.accessToken);
      return session;
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<UserProfile> profile() async {
    try {
      final response = await _api.dio.get(ApiEndpoints.profile);
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<UserProfile> updateProfile({bool? darkMode, String? name}) async {
    try {
      final body = <String, dynamic>{};
      if (darkMode != null) {
        body['darkMode'] = darkMode;
      }
      if (name != null) {
        body['name'] = name;
      }
      final response = await _api.dio.patch(ApiEndpoints.profile, data: body);
      return UserProfile.fromJson(response.data as Map<String, dynamic>);
    } catch (error) {
      throw _api.parseError(error);
    }
  }

  Future<void> logout() => _api.clearToken();
}
