import '../../core/utils/result.dart';
import 'gemini_api.dart';

/// One request the fake saw.
class GeminiCall {
  const GeminiCall(this.apiKey, this.model, this.body);
  final String apiKey;
  final String model;
  final Map<String, Object?> body;

  Map<String, Object?>? get config =>
      body['generationConfig'] as Map<String, Object?>?;
}

/// A Gemini API that answers from a script: tests and debug runs without a key or a
/// network. [respond] gets every call and returns the reply (or a network failure).
class ScriptedGeminiApi implements GeminiApi {
  ScriptedGeminiApi(this.respond, {this.respondList});

  final Result<GeminiReply> Function(GeminiCall call) respond;

  /// Answers `ListModels` by page token (null = the first page).
  final Result<GeminiReply> Function(String? pageToken)? respondList;
  final calls = <GeminiCall>[];
  final listCalls = <String?>[];

  @override
  Future<Result<GeminiReply>> listModels({
    required String apiKey,
    String? pageToken,
  }) async {
    listCalls.add(pageToken);
    return respondList?.call(pageToken) ??
        const Failure(GeminiNetworkError.failed);
  }

  /// A `ListModels` page: [models] are (name, displayName, methods) triples.
  static Result<GeminiReply> modelPage(
    List<(String, String, List<String>)> models, {
    String? next,
  }) => Ok(
    GeminiReply(200, {
      'models': [
        for (final (name, display, methods) in models)
          {
            'name': 'models/$name',
            'displayName': display,
            'supportedGenerationMethods': methods,
          },
      ],
      'nextPageToken': ?next,
    }),
  );

  @override
  Future<Result<GeminiReply>> generate({
    required String apiKey,
    required String model,
    required Map<String, Object?> body,
  }) async {
    final call = GeminiCall(apiKey, model, body);
    calls.add(call);
    return respond(call);
  }

  /// A 200 answer with [text] as the model's reply.
  static Result<GeminiReply> text(String text) => Ok(
    GeminiReply(200, {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
        },
      ],
    }),
  );

  /// An error answer in Google's shape. [quotaId] and [retryDelay] ("16s") are added the
  /// way a 429 carries them.
  static Result<GeminiReply> error(
    int status,
    String message, {
    String? quotaId,
    String? retryDelay,
  }) => Ok(
    GeminiReply(status, {
      'error': {
        'code': status,
        'message': message,
        'details': [
          if (quotaId != null)
            {
              '@type': 'type.googleapis.com/google.rpc.QuotaFailure',
              'violations': [
                {'quotaId': quotaId},
              ],
            },
          if (retryDelay != null)
            {
              '@type': 'type.googleapis.com/google.rpc.RetryInfo',
              'retryDelay': retryDelay,
            },
        ],
      },
    }),
  );

  static const offline = Failure<GeminiReply>(GeminiNetworkError.offline);
  static const broken = Failure<GeminiReply>(GeminiNetworkError.failed);
}
