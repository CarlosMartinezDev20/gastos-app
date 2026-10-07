import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/storage_provider.dart';

/// Where the session's access token lives between launches.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

/// The system's secure storage: Android Keystore / iOS Keychain (encrypted,
/// not readable by other apps or from a backup), instead of plain
/// SharedPreferences.
class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._prefs, [FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _storage;

  static const _key = 'access_token';

  /// Where earlier versions kept the token in plain text.
  static const legacyKey = 'access_token';

  @override
  Future<String?> read() async {
    final token = await _storage.read(key: _key);
    if (token != null) return token;
    // Move a token saved by an earlier version, so updating doesn't sign
    // the user out, and leave no plain-text copy behind.
    final legacy = _prefs.getString(legacyKey);
    if (legacy == null || legacy.isEmpty) return null;
    await _storage.write(key: _key, value: legacy);
    await _prefs.remove(legacyKey);
    return legacy;
  }

  @override
  Future<void> write(String token) async {
    await _storage.write(key: _key, value: token);
    await _prefs.remove(legacyKey);
  }

  @override
  Future<void> delete() async {
    await _storage.delete(key: _key);
    await _prefs.remove(legacyKey);
  }
}

/// Keeps the token in memory only (tests, previews).
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String token) async => this.token = token;

  @override
  Future<void> delete() async => token = null;
}

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => SecureTokenStore(ref.watch(sharedPreferencesProvider)),
);
