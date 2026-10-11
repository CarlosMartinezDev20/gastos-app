import '../core/auth/auth_gateway.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/auth_session.dart';
import '../models/user_profile.dart';

/// Accounts are Supabase Auth's (sign-in, sign-up, password); the profile
/// and everything else come from the API, which creates the profile on a
/// new account's first call.
class AuthRepository {
  const AuthRepository(this._api, this._auth);

  final ApiClient _api;
  final AuthGateway _auth;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    await _auth.signIn(email: email, password: password);
    return _session();
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _auth.signUp(name: name, email: email, password: password);
    return _session();
  }

  Future<AuthSession> _session() async {
    try {
      final user = await profile();
      return AuthSession(user: user, accessToken: _api.token!);
    } catch (_) {
      // Signed in but the API failed: don't leave a half-open session.
      await _api.clearToken();
      rethrow;
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

  /// Signs out the other devices; this one keeps its session.
  Future<void> changePassword({
    required String current,
    required String next,
  }) async {
    final email = (await profile()).email;
    await _auth.changePassword(email: email, current: current, next: next);
  }

  /// Deletes the account and all its data, then forgets the session.
  Future<void> deleteAccount(String password) async {
    try {
      await _api.dio.delete(ApiEndpoints.profile, data: {'password': password});
    } catch (error) {
      throw _api.parseError(error);
    }
    await _api.clearToken();
  }

  Future<void> logout() => _api.clearToken();
}
