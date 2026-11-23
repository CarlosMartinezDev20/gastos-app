import 'package:appgastos/core/monitoring/crash_reporting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const jwt =
    'eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJ1MSIsImVtYWlsIjoiYUBiLmMifQ.c2lnbmF0dXJh';

void main() {
  test('scrubs tokens, keys, passwords, emails, connections and amounts', () {
    final text = scrubText(
      'Authorization: Bearer $jwt token=$jwt sb_secret_AbC123 '
      'password=hunter22 refresh_token: abc123 ana@correo.com '
      'postgresql://postgres.ref:clave@host:5432/postgres gastó \$1,250.75',
    );
    for (final leaked in [
      jwt,
      'sb_secret_AbC123',
      'hunter22',
      'abc123',
      'ana@correo.com',
      'clave@host',
      '1,250.75',
    ]) {
      expect(text, isNot(contains(leaked)), reason: leaked);
    }
    expect(text, contains('[token]'));
    expect(text, contains('[email]'));
    expect(text, contains(r'$[amount]'));
  });

  test('an event keeps the error but drops request, user and extra', () {
    final event = scrubEvent(
      SentryEvent(
        message: SentryMessage('Falló con ana@correo.com'),
        exceptions: [
          SentryException(type: 'ApiException', value: 'Bearer $jwt'),
        ],
        request: SentryRequest(
          url: 'https://api/x?q=farmacia',
          headers: {'Authorization': 'Bearer $jwt'},
          cookies: 'sb=$jwt',
          data: {'password': 'hunter22'},
        ),
        user: SentryUser(id: 'u1', email: 'ana@correo.com'),
        // ignore: deprecated_member_use
        extra: {'amount': 12.5},
        serverName: 'Telefono de Ana',
        breadcrumbs: [
          Breadcrumb.http(
            url: Uri.parse('https://api/transactions?q=farmacia&from=2026'),
            method: 'POST',
            statusCode: 201,
          ),
        ],
      ),
    );

    expect(event.request, isNull);
    expect(event.user, isNull);
    // ignore: deprecated_member_use
    expect(event.extra, isNull);
    expect(event.serverName, isNull);
    expect(event.message!.formatted, 'Falló con [email]');
    expect(event.exceptions!.single.type, 'ApiException');
    expect(event.exceptions!.single.value, 'Bearer [token]');
    final http = event.breadcrumbs!.single;
    expect(http.data, {
      'method': 'POST',
      'status_code': 201,
      'url': 'https://api/transactions',
    });
  });

  test('crash reporting is off without a DSN (tests, local runs)', () async {
    expect(sentryDsn, isEmpty);
    var ran = false;
    await runWithCrashReporting(() async => ran = true);
    expect(ran, isTrue);
  });
}
