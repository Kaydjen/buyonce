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
}

class HttpGeminiApi implements GeminiApi {
  HttpGeminiApi({
    this.timeout = const Duration(seconds: 30),
    this.baseUrl = 'https://generativelanguage.googleapis.com/v1beta',
  });

  final Duration timeout;
  final String baseUrl;

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

  Future<Result<GeminiReply>> _send(
    String method,
    Uri uri,
    String apiKey,
    Map<String, Object?>? body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set('x-goog-api-key', apiKey);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(timeout);
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(timeout);
      Map<String, Object?>? json;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, Object?>) json = decoded;
      } catch (_) {}
      return Ok(GeminiReply(response.statusCode, json));
    } on SocketException {
      return const Failure(GeminiNetworkError.offline);
    } catch (_) {
      // A timeout, a broken connection, a TLS error: the model is slow or down.
      return const Failure(GeminiNetworkError.failed);
    } finally {
      client.close(force: true);
    }
  }
}

final geminiApiProvider = Provider<GeminiApi>((ref) => HttpGeminiApi());
