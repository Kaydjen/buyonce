import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';

/// What Google answered: the HTTP status and the JSON body (null when it was not JSON).
class GeminiReply {
  const GeminiReply(this.status, this.json);
  final int status;
  final Map<String, Object?>? json;
}

/// Why no answer came at all.
enum GeminiNetworkError { offline, failed }

/// One call of `generateContent`. No decisions here: what a status means is the client's
/// business.
abstract interface class GeminiApi {
  /// [model] is a bare id like `gemini-3.5-flash-lite`.
  Future<Result<GeminiReply>> generate({
    required String apiKey,
    required String model,
    required Map<String, Object?> body,
  });

  /// One page of the models this key can see (`ListModels`).
  Future<Result<GeminiReply>> listModels({
    required String apiKey,
    String? pageToken,
  });

  /// Opens the connection ahead of the first call (while the camera is open), so the
  /// call does not pay for the TLS handshake. Never fails and never waits for long.
  Future<void> warmUp();
}

/// Internal: the connection broke (reset, closed); tried once more before it is reported.
class _BrokenConnection {
  const _BrokenConnection();
}

class HttpGeminiApi implements GeminiApi {
  HttpGeminiApi({
    this.timeout = const Duration(seconds: 10),
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  });

  /// The whole call, connection to the last byte. A free-tier model now and then takes
  /// 20 s; waiting that long is worse than asking the next model.
  final Duration timeout;
  final String baseUrl;

  /// One client for all calls: its idle connections are kept, so a warmed-up connection
  /// is used by the next call (calls that overlap use one each).
  HttpClient? _client;

  HttpClient _open() => _client ??= HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 30);

  void close() {
    _client?.close(force: true);
    _client = null;
  }

  @override
  Future<void> warmUp() async {
    try {
      final request = await _open().headUrl(Uri.parse(baseUrl));
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      await response.drain<void>();
    } catch (_) {
      // Only a head start: the real call connects by itself.
    }
  }

  @override
  Future<Result<GeminiReply>> generate({
    required String apiKey,
    required String model,
    required Map<String, Object?> body,
  }) => _send(
    'POST',
    Uri.parse('$baseUrl/models/$model:generateContent'),
    apiKey,
    body,
  );

  @override
  Future<Result<GeminiReply>> listModels({
    required String apiKey,
    String? pageToken,
  }) => _send(
    'GET',
    Uri.parse('$baseUrl/models')
        .replace(queryParameters: {'pageSize': '100', 'pageToken': ?pageToken}),
    apiKey,
    null,
  );

  /// A kept connection may have been closed by the server meanwhile: a broken
  /// connection is tried once more on a new one before it counts as "no network".
  Future<Result<GeminiReply>> _send(
    String method,
    Uri uri,
    String apiKey,
    Map<String, Object?>? body,
  ) async {
    var result = await _once(method, uri, apiKey, body);
    if (result case Failure(error: _BrokenConnection())) {
      close();
      result = await _once(method, uri, apiKey, body);
    }
    return switch (result) {
      Failure(error: _BrokenConnection()) => const Failure(
        GeminiNetworkError.offline,
      ),
      _ => result,
    };
  }

  Future<Result<GeminiReply>> _once(
    String method,
    Uri uri,
    String apiKey,
    Map<String, Object?>? body,
  ) async {
    HttpClientRequest? request;
    Future<Result<GeminiReply>> call() async {
      final opened = await _open().openUrl(method, uri);
      request = opened;
      opened.headers.set('x-goog-api-key', apiKey);
      if (body != null) {
        opened.headers.contentType = ContentType.json;
        opened.write(jsonEncode(body));
      }
      final response = await opened.close();
      final text = await response.transform(utf8.decoder).join();
      Map<String, Object?>? json;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, Object?>) json = decoded;
      } catch (_) {}
      return Ok(GeminiReply(response.statusCode, json));
    }

    try {
      return await call().timeout(timeout);
    } on TimeoutException {
      request?.abort();
      return const Failure(GeminiNetworkError.failed);
    } on SocketException catch (e) {
      // No route or no DNS is "offline"; a connection that was reset is a broken one.
      return Failure(
        _isOffline(e) ? GeminiNetworkError.offline : const _BrokenConnection(),
      );
    } on HttpException {
      return const Failure(_BrokenConnection());
    } catch (_) {
      return const Failure(GeminiNetworkError.failed);
    }
  }

  static bool _isOffline(SocketException e) {
    final text = '${e.message} ${e.osError?.message ?? ''}'.toLowerCase();
    return text.contains('host lookup') ||
        text.contains('unreachable') ||
        text.contains('refused') ||
        text.contains('no address associated');
  }
}

final geminiApiProvider = Provider<GeminiApi>((ref) {
  final api = HttpGeminiApi();
  ref.onDispose(api.close);
  return api;
});
