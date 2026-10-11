import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session (access and refresh tokens) in the system's
/// secure storage, Android Keystore / iOS Keychain, instead of the plain
/// SharedPreferences supabase_flutter uses by default.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._prefs, [FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _storage;

  static const key = 'supabase_session';

  /// Where versions before Supabase Auth kept their own API token. It no
  /// longer opens anything, so it is removed.
  static const legacyKey = 'access_token';

  @override
  Future<void> initialize() async {
    await _prefs.remove(legacyKey);
    if (await _storage.containsKey(key: legacyKey)) {
      await _storage.delete(key: legacyKey);
    }
  }

  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: key);

  @override
  Future<String?> accessToken() => _storage.read(key: key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: key, value: persistSessionString);

  @override
  Future<void> removePersistedSession() => _storage.delete(key: key);
}
