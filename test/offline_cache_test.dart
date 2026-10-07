import 'dart:convert';
import 'dart:typed_data';

import 'package:appgastos/core/network/api_client.dart';
import 'package:appgastos/core/network/response_cache.dart';
import 'package:appgastos/core/network/token_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers with [body] while [online], else fails like a dropped network.
class _Network implements HttpClientAdapter {
  bool online = true;
  Object body = const [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!online) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin red',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

String jwt(String sub) =>
    'x.${base64Url.encode(utf8.encode(jsonEncode({'sub': sub}))).replaceAll('=', '')}.y';

Future<(ApiClient, _Network, SharedPreferences)> client(String user) async {
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(MemoryTokenStore(jwt(user)), ResponseCache(prefs));
  await api.restoreToken();
  final network = _Network();
  api.dio.httpClientAdapter = network;
  return (api, network, prefs);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offline, a GET answers with the last saved result', () async {
    final (api, network, _) = await client('u1');
    network.body = [
      {'id': 't1', 'amount': 8.5},
    ];
    await api.dio.get('/transactions');
    expect(api.offline.value, isFalse);

    network.online = false;
    final response = await api.dio.get('/transactions');
    expect(response.data, [
      {'id': 't1', 'amount': 8.5},
    ]);
    expect(response.extra['fromCache'], isTrue);
    expect(api.offline.value, isTrue);

    network.online = true;
    await api.dio.get('/transactions');
    expect(api.offline.value, isFalse, reason: 'back online');
  });

  test(
    'without a saved answer, or for writes, the error goes through',
    () async {
      final (api, network, _) = await client('u1');
      network.online = false;
      await expectLater(api.dio.get('/budgets'), throwsA(isA<DioException>()));
      await expectLater(
        api.dio.post('/transactions', data: {}),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    "one account never sees another's saved data; logout clears it",
    () async {
      final (alice, network, prefs) = await client('alice');
      network.body = ['de alice'];
      await alice.dio.get('/transactions');

      final bob = ApiClient(MemoryTokenStore(jwt('bob')), ResponseCache(prefs));
      await bob.restoreToken();
      bob.dio.httpClientAdapter = network..online = false;
      await expectLater(
        bob.dio.get('/transactions'),
        throwsA(isA<DioException>()),
      );

      await alice.clearToken();
      expect(prefs.getKeys().where((k) => k.startsWith('api_cache:')), isEmpty);
    },
  );

  test('tokenSubject reads the user id of a JWT', () {
    expect(tokenSubject(jwt('u1')), 'u1');
    expect(tokenSubject('no-es-un-jwt'), isNull);
    expect(tokenSubject(null), isNull);
  });
}
