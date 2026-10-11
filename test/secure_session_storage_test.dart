import 'package:appgastos/core/auth/secure_session_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps the session only in secure storage', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = SecureSessionStorage(prefs);
    await storage.initialize();

    expect(await storage.hasAccessToken(), isFalse);
    await storage.persistSession('{"access_token":"a"}');
    expect(await storage.accessToken(), '{"access_token":"a"}');
    expect(prefs.getKeys(), isEmpty, reason: 'no plain-text copy');
    await storage.removePersistedSession();
    expect(await storage.hasAccessToken(), isFalse);
  });

  test('drops the API token of earlier versions', () async {
    FlutterSecureStorage.setMockInitialValues({'access_token': 'viejo'});
    SharedPreferences.setMockInitialValues({'access_token': 'viejo'});
    final prefs = await SharedPreferences.getInstance();
    await SecureSessionStorage(prefs).initialize();

    expect(prefs.getString(SecureSessionStorage.legacyKey), isNull);
    expect(
      await const FlutterSecureStorage().read(
        key: SecureSessionStorage.legacyKey,
      ),
      isNull,
    );
  });
}
