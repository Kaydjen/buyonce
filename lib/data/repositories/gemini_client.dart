import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/result.dart';
import '../../domain/models/gemini_outcome.dart';
import '../services/gemini_api.dart';
import '../services/gemini_key_service.dart';

/// One question for the model: a prompt, an optional JPEG and the JSON shape of the answer.
class GeminiRequest {
  const GeminiRequest({required this.prompt, required this.schema, this.image});
  final String prompt;

  /// Gemini's schema (`type`, `properties`, ...) of the JSON the answer must have.
  final Map<String, Object?> schema;
  final Uint8List? image;
}

/// What the client knows about one model since the key or the list last changed.
class _Health {
  /// The first rung of the request ladder to try: the lowest one that worked, or the
  /// first one that did not fail with a 400 so far.
  int rung = 0;
  bool unavailable = false; // 404
  bool noImages = false; // 400 about the image
  DateTime? skipUntil;
  LimitScope? skipScope;
}

sealed class _Attempt {
  const _Attempt();
}

final class _Answer extends _Attempt {
  const _Answer(this.text);
  final String text;
}

final class _Limit extends _Attempt {
  const _Limit(this.scope, this.retryIn);
  final LimitScope scope;
  final Duration? retryIn;
}

/// Overload, a slow answer, an empty answer: try the next model.
final class _Transient extends _Attempt {
  const _Transient();
}

/// The model cannot serve this request at all (unknown, or no images).
final class _Dead extends _Attempt {
  const _Dead();
}

final class _Stop extends _Attempt {
  const _Stop(this.outcome);
  final GeminiOutcome outcome;
}

/// Asks the models of a list one after another until one answers, and remembers which
/// ones are limited or broken so the next request does not wait for them again.
///
/// Limits cannot be read in advance (the API has no such call), so they are learned from
/// the answers: a 429 skips that model until the limit lifts (a minute limit: the given
/// delay; a daily limit: one hour, then it is tried again), overload (500/503/504, a
/// timeout) skips it for 20 s, a 404 or an image refusal marks it for good. The memory
/// is dropped when the key or the list changes.
class GeminiClient {
  GeminiClient(this._api, this._keys, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final GeminiApi _api;
  final GeminiKeyService _keys;
  final DateTime Function() _now;

  static const overloadSkip = Duration(seconds: 20);
  static const dailySkip = Duration(hours: 1);
  static const unknownLimitSkip = Duration(seconds: 60);

  final _health = <String, _Health>{};
  String? _lastKey;
  List<String>? _lastModels;

  /// Forgets every limit and every mark.
  void reset() {
    _health.clear();
    _lastKey = null;
    _lastModels = null;
  }

  Future<GeminiOutcome> generate(
    GeminiRequest request,
    List<String> models,
  ) async {
    final stored = await _keys.read();
    final key = switch (stored) {
      Ok(:final value) => value,
      Failure() => null,
    };
    if (key == null || key.isEmpty) return const GeminiNoKey();
    final ids = [
      for (final m in models)
        if (m.trim().isNotEmpty) m.trim().replaceFirst('models/', ''),
    ];
    if (ids.isEmpty) return const GeminiFailed();
    if (key != _lastKey || !_sameList(ids, _lastModels)) {
      _health.clear();
      _lastKey = key;
      _lastModels = ids;
    }

    final hasImage = request.image != null;
    var live = 0;
    final limits = <(String, LimitScope, Duration?)>[];
    for (final model in ids) {
      final health = _health.putIfAbsent(model, _Health.new);
      if (health.unavailable || (hasImage && health.noImages)) continue;
      live++;
      final now = _now();
      final until = health.skipUntil;
      if (until != null && until.isAfter(now)) {
        // Skipped without a request. Only a limit is reported to the user.
        if (health.skipScope != null) {
          limits.add((model, health.skipScope!, until.difference(now)));
        }
        continue;
      }
      final attempt = await _ask(key, model, health, request);
      switch (attempt) {
        case _Answer(:final text):
          health.skipUntil = null;
          health.skipScope = null;
          return GeminiOk(text, model);
        case _Stop(:final outcome):
          return outcome;
        case _Limit(:final scope, :final retryIn):
          health.skipScope = scope;
          final wait = scope == LimitScope.day
              ? dailySkip
              : retryIn ?? unknownLimitSkip;
          health.skipUntil = now.add(wait > dailySkip ? dailySkip : wait);
          limits.add((model, scope, retryIn));
        case _Transient():
          health.skipScope = null;
          health.skipUntil = now.add(overloadSkip);
        case _Dead():
          live--;
      }
    }

    // Nothing answered. A limit is told to the user only when it is the reason: every
    // usable model is limited.
    if (live > 0 && limits.length == live) {
      if (live == 1) {
        final (model, scope, retryIn) = limits.single;
        return GeminiLimited(model, scope, retryIn);
      }
      final waits = [
        for (final l in limits)
          if (l.$3 != null) l.$3!,
      ];
      waits.sort();
      return GeminiAllLimited(waits.isEmpty ? null : waits.first);
    }
    return const GeminiFailed();
  }

  /// One model, down the request ladder: schema + minimal thinking, then schema only,
  /// then JSON asked for in the prompt. A 400 that is not about the key or the image
  /// moves to the next rung; the rung that works is remembered.
  Future<_Attempt> _ask(
    String key,
    String model,
    _Health health,
    GeminiRequest request,
  ) async {
    for (var rung = health.rung; rung < 3; rung++) {
      final result = await _api.generate(
        apiKey: key,
        model: model,
        body: _body(request, rung),
      );
      final GeminiReply reply;
      switch (result) {
        case Failure(error: GeminiNetworkError.offline):
          return const _Stop(GeminiOffline());
        case Failure():
          return const _Transient();
        case Ok(:final value):
          reply = value;
      }
      final status = reply.status;
      if (status == 200) {
        final text = _answerText(reply.json);
        if (text == null) return const _Transient();
        health.rung = rung;
        return _Answer(text);
      }
      final message = _errorMessage(reply.json);
      if (status == 429) return _limit(reply.json);
      if (status == 401 || status == 403) return const _Stop(GeminiBadKey());
      if (status == 404) {
        health.unavailable = true;
        return const _Dead();
      }
      if (status == 400) {
        final text = message.toLowerCase();
        if (text.contains('api key')) return const _Stop(GeminiBadKey());
        // "Thinking level ... not supported", a schema the model does not take: next rung.
        final aboutRequestShape =
            text.contains('thinking') ||
            text.contains('schema') ||
            text.contains('mime');
        if (!aboutRequestShape &&
            request.image != null &&
            (text.contains('image') || text.contains('media'))) {
          health.noImages = true;
          return const _Dead();
        }
        health.rung = rung + 1;
        continue;
      }
      // 500, 502, 503, 504, 408 and anything unexpected.
      return const _Transient();
    }
    return const _Transient();
  }

  Map<String, Object?> _body(GeminiRequest request, int rung) {
    final prompt = rung < 2
        ? request.prompt
        : '${request.prompt}\n\nAnswer with JSON only, no other text, '
              'in this shape: ${jsonEncode(request.schema)}';
    return {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            if (request.image != null)
              {
                'inlineData': {
                  'mimeType': 'image/jpeg',
                  'data': base64Encode(request.image!),
                },
              },
          ],
        },
      ],
      if (rung < 2)
        'generationConfig': {
          'responseMimeType': 'application/json',
          'responseSchema': request.schema,
          if (rung == 0) 'thinkingConfig': {'thinkingLevel': 'minimal'},
        },
    };
  }

  /// The last non-thought text part, without a markdown fence around it.
  String? _answerText(Map<String, Object?>? json) {
    final candidates = json?['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = (candidates.first as Map?)?['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return null;
    String? text;
    for (final part in parts) {
      if (part is Map && part['thought'] != true && part['text'] is String) {
        text = part['text'] as String;
      }
    }
    text = text?.trim();
    if (text == null || text.isEmpty) return null;
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(text);
    return fence?.group(1) ?? text;
  }

  String _errorMessage(Map<String, Object?>? json) {
    final error = json?['error'];
    final message = error is Map ? error['message'] : null;
    return message is String ? message : '';
  }

  /// Minute or day, by the quota id Google names; the delay is the one it asks for.
  _Limit _limit(Map<String, Object?>? json) {
    final error = json?['error'];
    final details = error is Map ? error['details'] : null;
    String quotaId = '';
    Duration? retryIn;
    if (details is List) {
      for (final d in details) {
        if (d is! Map) continue;
        final type = '${d['@type']}';
        if (type.endsWith('QuotaFailure')) {
          final violations = d['violations'];
          if (violations is List && violations.isNotEmpty) {
            final first = violations.first;
            if (first is Map) quotaId = '${first['quotaId']}';
          }
        } else if (type.endsWith('RetryInfo')) {
          retryIn = _parseDelay('${d['retryDelay']}');
        }
      }
    }
    final scope = quotaId.contains('PerDay')
        ? LimitScope.day
        : quotaId.contains('PerMinute')
        ? LimitScope.minute
        : LimitScope.unknown;
    return _Limit(scope, retryIn);
  }

  /// "16s", "12.5s": seconds as Google writes a duration; null when unreadable.
  Duration? _parseDelay(String text) {
    final match = RegExp(r'^(\d+(?:\.\d+)?)s$').firstMatch(text);
    if (match == null) return null;
    return Duration(
      milliseconds: (double.parse(match.group(1)!) * 1000).ceil(),
    );
  }

  bool _sameList(List<String> a, List<String>? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final geminiClientProvider = Provider(
  (ref) => GeminiClient(
    ref.watch(geminiApiProvider),
    ref.watch(geminiKeyServiceProvider),
  ),
);
