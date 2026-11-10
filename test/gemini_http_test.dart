import 'dart:convert';
import 'dart:io';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real HTTP service against a small server on this machine.
class _Server {
  _Server(this.handler);

  final Future<void> Function(HttpRequest request, int number) handler;
  late final HttpServer server;
  final ports = <int>[];
  var requests = 0;

  Future<_Server> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      requests++;
      ports.add(request.connectionInfo!.remotePort);
      handler(request, requests);
    });
    return this;
  }

  String get url => 'http://127.0.0.1:${server.port}/v1';

  Future<void> stop() => server.close(force: true);
}

Future<void> _json(HttpRequest r, Object body, {int status = 200}) async {
  r.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await r.response.close();
}

void main() {
  test('generate posts the body with the key and parses the answer', () async {
    String? path;
    String? key;
    Object? received;
    final s = await _Server((r, _) async {
      path = r.uri.path;
      key = r.headers.value('x-goog-api-key');
      received = jsonDecode(await utf8.decoder.bind(r).join());
      await _json(r, {'ok': true});
    }).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(baseUrl: s.url);
    addTearDown(api.close);

    final result = await api.generate(
      apiKey: 'k1',
      model: 'm1',
      body: {'x': 1},
    );
    expect(path, '/v1/models/m1:generateContent');
    expect(key, 'k1');
    expect(received, {'x': 1});
    final reply = (result as Ok<GeminiReply>).value;
    expect(reply.status, 200);
    expect(reply.json, {'ok': true});
  });

  test('listModels asks for a page and passes the token', () async {
    Uri? uri;
    final s = await _Server((r, _) async {
      uri = r.uri;
      await _json(r, {'models': []});
    }).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(baseUrl: s.url);
    addTearDown(api.close);

    await api.listModels(apiKey: 'k', pageToken: 'p2');
    expect(uri!.path, '/v1/models');
    expect(uri!.queryParameters, {'pageSize': '100', 'pageToken': 'p2'});
  });

  test('an error status and a body that is not JSON are returned as they are', () async {
    final s = await _Server((r, n) async {
      if (n == 1) return _json(r, {'error': 'x'}, status: 429);
      r.response
        ..statusCode = 502
        ..write('<html>bad gateway</html>');
      await r.response.close();
    }).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(baseUrl: s.url);
    addTearDown(api.close);

    final a = (await api.generate(apiKey: 'k', model: 'm', body: {}))
        as Ok<GeminiReply>;
    expect(a.value.status, 429);
    final b = (await api.generate(apiKey: 'k', model: 'm', body: {}))
        as Ok<GeminiReply>;
    expect(b.value.status, 502);
    expect(b.value.json, isNull);
  });

  test('a slow answer is given up on at the timeout', () async {
    final s = await _Server((r, _) async {
      await Future<void>.delayed(const Duration(seconds: 3));
      try {
        await _json(r, {});
      } catch (_) {}
    }).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(
      baseUrl: s.url,
      timeout: const Duration(milliseconds: 300),
    );
    addTearDown(api.close);

    final watch = Stopwatch()..start();
    final result = await api.generate(apiKey: 'k', model: 'm', body: {});
    expect((result as Failure).error, GeminiNetworkError.failed);
    expect(watch.elapsedMilliseconds, lessThan(2000));
  });

  test('nobody listening is "offline"', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final api = HttpGeminiApi(baseUrl: 'http://127.0.0.1:$port/v1');
    addTearDown(api.close);

    final result = await api.generate(apiKey: 'k', model: 'm', body: {});
    expect((result as Failure).error, GeminiNetworkError.offline);
  });

  test('warmUp opens the connection the next call uses', () async {
    final s = await _Server((r, _) => _json(r, {'ok': true})).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(baseUrl: s.url);
    addTearDown(api.close);

    await api.warmUp();
    await api.generate(apiKey: 'k', model: 'm', body: {});
    expect(s.requests, 2);
    expect(s.ports.toSet().length, 1, reason: 'one connection for both');
  });

  test('warmUp never throws, whatever the network does', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);
    final api = HttpGeminiApi(baseUrl: 'http://127.0.0.1:$port/v1');
    addTearDown(api.close);
    await api.warmUp();
  });

  test('a connection the server closed is replaced and the call goes on', () async {
    final s = await _Server((r, n) async {
      if (n == 1) {
        // The kept connection was dropped by the server before it answered.
        final socket = await r.response.detachSocket(writeHeaders: false);
        socket.destroy();
        return;
      }
      await _json(r, {'second': true});
    }).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(baseUrl: s.url);
    addTearDown(api.close);

    final result = await api.generate(apiKey: 'k', model: 'm', body: {});
    expect((result as Ok<GeminiReply>).value.json, {'second': true});
    expect(s.requests, 2);
  });

  test('a connection that keeps breaking ends as "offline"', () async {
    final s = await _Server((r, n) async {
      final socket = await r.response.detachSocket(writeHeaders: false);
      socket.destroy();
    }).start();
    addTearDown(s.stop);
    final api = HttpGeminiApi(baseUrl: s.url);
    addTearDown(api.close);

    final result = await api.generate(apiKey: 'k', model: 'm', body: {});
    expect((result as Failure).error, GeminiNetworkError.offline);
    expect(s.requests, 2);
  });
}
