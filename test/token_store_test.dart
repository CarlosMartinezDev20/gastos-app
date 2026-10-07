import 'package:appgastos/core/network/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('moves a plain-text token from an earlier version', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'access_token': 'old-token'});
    final prefs = await SharedPreferences.getInstance();
    final store = SecureTokenStore(prefs);

    expect(await store.read(), 'old-token', reason: 'still signed in');
    expect(prefs.getString(SecureTokenStore.legacyKey), isNull);
    // Read again: now from secure storage only.
    expect(await store.read(), 'old-token');
  });

  test('writes and deletes only in secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SecureTokenStore(prefs);

    await store.write('new-token');
    expect(prefs.getKeys(), isEmpty, reason: 'no plain-text copy');
    expect(await store.read(), 'new-token');
    await store.delete();
    expect(await store.read(), isNull);
  });
}
