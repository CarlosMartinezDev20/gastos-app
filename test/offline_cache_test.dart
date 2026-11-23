import 'dart:convert';
import 'dart:typed_data';

import 'package:appgastos/core/network/api_client.dart';
import 'package:appgastos/core/network/response_cache.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

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
  final api = ApiClient(FakeAuthGateway(jwt(user)), ResponseCache(prefs));
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

      final bob = ApiClient(FakeAuthGateway(jwt('bob')), ResponseCache(prefs));
      bob.dio.httpClientAdapter = network..online = false;
      await expectLater(
        bob.dio.get('/transactions'),
        throwsA(isA<DioException>()),
      );

      await alice.clearToken();
      expect(prefs.getKeys().where((k) => k.startsWith('api_cache:')), isEmpty);
    },
  );

  test(
    'keeps only the latest answers and skips searches and later pages',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient(
        FakeAuthGateway(jwt('u1')),
        ResponseCache(prefs, maxEntries: 2),
      );
      final network = _Network()..body = ['ok'];
      api.dio.httpClientAdapter = network;
      List<String> saved() =>
          prefs.getKeys().where((k) => k.startsWith('api_cache:')).toList()
            ..sort();

      await api.dio.get('/transactions/page', queryParameters: {'q': 'caf'});
      await api.dio.get(
        '/transactions/page',
        queryParameters: {'cursor': '2026-09-01T00:00:00.000Z_t1'},
      );
      expect(saved(), isEmpty);

      await api.dio.get('/budgets');
      await api.dio.get('/categories');
      await api.dio.get('/budgets'); // used again: now the newest
      await api.dio.get('/transactions');
      expect(saved(), [
        'api_cache:u1:/budgets?',
        'api_cache:u1:/transactions?',
      ]);

      await api.clearToken();
      expect(prefs.getKeys(), isNot(contains('api_cache_order')));
    },
  );

  test('drops what older versions saved without an index', () async {
    SharedPreferences.setMockInitialValues({
      'api_cache:u1:/transactions/page?q=a': '[]',
      'api_cache:u1:/transactions/page?q=ab': '[]',
      'balance_hidden': true,
    });
    final (api, _, prefs) = await client('u1');
    await api.dio.get('/budgets');
    expect(prefs.getKeys(), {
      'api_cache:u1:/budgets?',
      'api_cache_order',
      'balance_hidden',
    });
  });

  test('tokenSubject reads the user id of a JWT', () {
    expect(tokenSubject(jwt('u1')), 'u1');
    expect(tokenSubject('no-es-un-jwt'), isNull);
    expect(tokenSubject(null), isNull);
  });
}
