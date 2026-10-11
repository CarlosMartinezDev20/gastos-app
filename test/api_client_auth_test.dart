import 'dart:convert';
import 'dart:typed_data';

import 'package:appgastos/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Accepts only `Bearer good`; anything else is a 401, like the API.
class _Api implements HttpClientAdapter {
  final seen = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seen.add(auth);
    final ok = auth == 'Bearer good';
    return ResponseBody.fromString(
      jsonEncode(ok ? {'ok': true} : {'message': 'Tu sesión expiró'}),
      ok ? 200 : 401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(ApiClient, FakeAuthGateway, _Api, List<String>) setup(String token) {
  final auth = FakeAuthGateway(token);
  final api = ApiClient(auth);
  final server = _Api();
  api.dio.httpClientAdapter = server;
  final events = <String>[];
  api.onUnauthorized = () => events.add('logout');
  return (api, auth, server, events);
}

void main() {
  test('a rejected token is refreshed once and the request repeated', () async {
    final (api, auth, server, events) = setup('expired');
    auth.onRefresh = () => 'good';

    final response = await api.dio.get('/users/profile');

    expect(response.data, {'ok': true});
    expect(auth.refreshes, 1);
    expect(server.seen, ['Bearer expired', 'Bearer good']);
    expect(events, isEmpty, reason: 'still signed in');
  });

  test('a session that cannot be refreshed signs out', () async {
    final (api, auth, _, events) = setup('revoked');
    auth.onRefresh = () => null;

    await expectLater(
      api.dio.get('/users/profile'),
      throwsA(isA<DioException>()),
    );
    expect(events, ['logout']);
    expect(auth.token, isNull);
  });

  test('a token rejected again after refreshing signs out, no loop', () async {
    final (api, auth, server, events) = setup('bad');
    auth.onRefresh = () => 'still-bad';

    await expectLater(
      api.dio.get('/users/profile'),
      throwsA(isA<DioException>()),
    );
    expect(auth.refreshes, 1);
    expect(server.seen.length, 2);
    expect(events, ['logout']);
  });

  test('network failures and server errors read in Spanish', () {
    final api = ApiClient(FakeAuthGateway());
    final request = RequestOptions(path: '/x');
    expect(
      api
          .parseError(
            DioException(
              requestOptions: request,
              type: DioExceptionType.receiveTimeout,
            ),
          )
          .message,
      contains('tardando'),
    );
    expect(
      api
          .parseError(
            DioException.connectionError(requestOptions: request, reason: 'x'),
          )
          .message,
      contains('Sin conexión'),
    );
    final badGateway = api.parseError(
      DioException.badResponse(
        statusCode: 502,
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 502,
          data: '<html>Bad gateway</html>',
        ),
      ),
    );
    expect(badGateway.message, contains('no está disponible'));
    expect(badGateway.statusCode, 502);
  });
}
