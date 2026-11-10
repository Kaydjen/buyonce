import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/gemini_client.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/domain/models/gemini_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

const _minuteQuota = 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier';
const _dayQuota = 'GenerateRequestsPerDayPerProjectPerModel-FreeTier';
const _a = 'model-a';
const _b = 'model-b';

final _request = GeminiRequest(
  prompt: 'Name the item',
  schema: const {'type': 'OBJECT'},
  image: Uint8List.fromList([1, 2, 3]),
);

/// A client over a script; [script] answers by model.
class Rig {
  Rig(this.script) {
    api = ScriptedGeminiApi((call) => script(call));
    client = GeminiClient(api, keys, clock: () => now);
  }

  final Result<GeminiReply> Function(GeminiCall call) script;
  late final ScriptedGeminiApi api;
  late final GeminiClient client;
  final keys = GeminiKeyService();
  var now = DateTime(2026, 11, 10, 12);

  Future<GeminiOutcome> ask(List<String> models, [GeminiRequest? request]) =>
      client.generate(request ?? _request, models);

  List<String> get asked => [for (final c in api.calls) c.model];
  void wait(Duration d) => now = now.add(d);
}

Future<Rig> rig(Result<GeminiReply> Function(GeminiCall call) script) async {
  final r = Rig(script);
  await r.keys.write('key-1');
  return r;
}

Result<GeminiReply> _ok(GeminiCall call) =>
    ScriptedGeminiApi.text('{"names":["Milk"]}');

void main() {
  test('no key: nothing is sent', () async {
    final r = Rig(_ok);
    expect(await r.ask([_a]), isA<GeminiNoKey>());
    expect(r.api.calls, isEmpty);
  });

  test('an empty list or blank ids: failed, nothing is sent', () async {
    final r = await rig(_ok);
    expect(await r.ask([]), isA<GeminiFailed>());
    expect(await r.ask([' ', '']), isA<GeminiFailed>());
    expect(r.api.calls, isEmpty);
  });

  test(
    'the first model answers; the request carries key, schema, image',
    () async {
      final r = await rig(_ok);
      final out = await r.ask(['models/$_a', _b]);
      expect(out, isA<GeminiOk>());
      expect((out as GeminiOk).text, '{"names":["Milk"]}');
      expect(out.model, _a);
      expect(r.asked, [_a]);
      final call = r.api.calls.single;
      expect(call.apiKey, 'key-1');
      expect(call.config!['responseSchema'], {'type': 'OBJECT'});
      expect(call.config!['thinkingConfig'], {'thinkingLevel': 'minimal'});
      final parts =
          ((call.body['contents'] as List).single as Map)['parts'] as List;
      expect((parts[0] as Map)['text'], 'Name the item');
      expect((parts[1] as Map)['inlineData'], {
        'mimeType': 'image/jpeg',
        'data': 'AQID',
      });
    },
  );

  test(
    'thought parts and a markdown fence are not part of the answer',
    () async {
      final r = await rig(
        (_) => Ok(
          GeminiReply(200, {
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'thinking...', 'thought': true},
                    {'text': '```json\n{"names":["Tea"]}\n```'},
                  ],
                },
              },
            ],
          }),
        ),
      );
      expect(((await r.ask([_a])) as GeminiOk).text, '{"names":["Tea"]}');
    },
  );

  group('overload', () {
    test('a 503 moves on and the model rests 20 s', () async {
      final r = await rig(
        (c) => c.model == _a
            ? ScriptedGeminiApi.error(503, 'high demand')
            : _ok(c),
      );
      expect(((await r.ask([_a, _b])) as GeminiOk).model, _b);
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b]);
      r.wait(const Duration(seconds: 21));
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b, _a, _b]);
    });

    test('a broken connection and an empty answer count as overload', () async {
      final r = await rig(
        (c) => switch (c.model) {
          _a => ScriptedGeminiApi.broken,
          _b => ScriptedGeminiApi.text('  '),
          _ => _ok(c),
        },
      );
      expect(((await r.ask([_a, _b, 'model-c'])) as GeminiOk).model, 'model-c');
    });

    test('overload everywhere is a failure, not a limit', () async {
      final r = await rig((_) => ScriptedGeminiApi.error(503, 'high demand'));
      expect(await r.ask([_a, _b]), isA<GeminiFailed>());
    });
  });

  group('limits', () {
    test('a minute limit skips the model for the delay Google gives', () async {
      final r = await rig(
        (c) => c.model == _a
            ? ScriptedGeminiApi.error(
                429,
                'quota',
                quotaId: _minuteQuota,
                retryDelay: '16s',
              )
            : _ok(c),
      );
      expect(((await r.ask([_a, _b])) as GeminiOk).model, _b);
      r.wait(const Duration(seconds: 10));
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b]);
      r.wait(const Duration(seconds: 7));
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b, _a, _b]);
    });

    test(
      'a daily limit skips the model for an hour, then it is probed',
      () async {
        final r = await rig(
          (c) => c.model == _a
              ? ScriptedGeminiApi.error(
                  429,
                  'quota',
                  quotaId: _dayQuota,
                  retryDelay: '43985s',
                )
              : _ok(c),
        );
        await r.ask([_a, _b]);
        r.wait(const Duration(minutes: 59));
        await r.ask([_a, _b]);
        expect(r.asked, [_a, _b, _b]);
        r.wait(const Duration(minutes: 2));
        await r.ask([_a, _b]);
        expect(r.asked, [_a, _b, _b, _a, _b]);
      },
    );

    test('an unknown quota with no delay rests 60 s', () async {
      final r = await rig(
        (c) => c.model == _a ? ScriptedGeminiApi.error(429, 'quota') : _ok(c),
      );
      await r.ask([_a, _b]);
      r.wait(const Duration(seconds: 59));
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b]);
      r.wait(const Duration(seconds: 2));
      await r.ask([_a, _b]);
      expect(r.asked.where((m) => m == _a).length, 2);
    });

    test(
      'the only model limited: Limited with model, scope and wait',
      () async {
        final r = await rig(
          (_) => ScriptedGeminiApi.error(
            429,
            'quota',
            quotaId: _minuteQuota,
            retryDelay: '16s',
          ),
        );
        var out = await r.ask([_a]) as GeminiLimited;
        expect(out.model, _a);
        expect(out.scope, LimitScope.minute);
        expect(out.retryIn, const Duration(seconds: 16));
        // Asked again while it rests: no request, the wait shrinks.
        r.wait(const Duration(seconds: 6));
        out = await r.ask([_a]) as GeminiLimited;
        expect(r.asked, [_a]);
        expect(out.retryIn, const Duration(seconds: 10));
      },
    );

    test('every model limited: AllLimited with the shortest wait', () async {
      final r = await rig(
        (c) => ScriptedGeminiApi.error(
          429,
          'quota',
          quotaId: _minuteQuota,
          retryDelay: c.model == _a ? '40s' : '15s',
        ),
      );
      final out = await r.ask([_a, _b]) as GeminiAllLimited;
      expect(out.retryIn, const Duration(seconds: 15));
    });

    test('one limited and one overloaded is a failure', () async {
      final r = await rig(
        (c) => c.model == _a
            ? ScriptedGeminiApi.error(429, 'quota', quotaId: _dayQuota)
            : ScriptedGeminiApi.error(503, 'high demand'),
      );
      expect(await r.ask([_a, _b]), isA<GeminiFailed>());
    });

    test(
      'a dead model does not count: the one that is left is Limited',
      () async {
        final r = await rig(
          (c) => c.model == _a
              ? ScriptedGeminiApi.error(404, 'no longer available')
              : ScriptedGeminiApi.error(429, 'quota', quotaId: _dayQuota),
        );
        final out = await r.ask([_a, _b]);
        expect(out, isA<GeminiLimited>());
        expect((out as GeminiLimited).scope, LimitScope.day);
      },
    );
  });

  group('models that cannot serve', () {
    test('a 404 marks the model for good', () async {
      final r = await rig(
        (c) => c.model == _a
            ? ScriptedGeminiApi.error(404, 'no longer available')
            : _ok(c),
      );
      await r.ask([_a, _b]);
      r.wait(const Duration(days: 2));
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b]);
    });

    test('only unknown models: failed', () async {
      final r = await rig((_) => ScriptedGeminiApi.error(404, 'gone'));
      expect(await r.ask([_a, _b]), isA<GeminiFailed>());
    });

    test('a 400 about the image marks the model as text-only', () async {
      final r = await rig(
        (c) => c.model == _a
            ? ScriptedGeminiApi.error(400, 'Unable to process input image.')
            : _ok(c),
      );
      await r.ask([_a, _b]);
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _b]);
      // A request without an image still goes to it.
      await r.ask([_a], const GeminiRequest(prompt: 'p', schema: {}));
      expect(r.asked.last, _a);
    });
  });

  group('the key and the network stop everything', () {
    test('a 400 about the API key', () async {
      final r = await rig(
        (_) => ScriptedGeminiApi.error(400, 'API key not valid. Please pass.'),
      );
      expect(await r.ask([_a, _b]), isA<GeminiBadKey>());
      expect(r.asked, [_a]);
    });

    test('a 403', () async {
      final r = await rig((_) => ScriptedGeminiApi.error(403, 'denied'));
      expect(await r.ask([_a, _b]), isA<GeminiBadKey>());
      expect(r.asked, [_a]);
    });

    test('no network', () async {
      final r = await rig((_) => ScriptedGeminiApi.offline);
      expect(await r.ask([_a, _b]), isA<GeminiOffline>());
      expect(r.asked, [_a]);
    });
  });

  group('the request ladder', () {
    test('a refused thinking level drops it and is remembered', () async {
      final r = await rig(
        (c) => c.config!.containsKey('thinkingConfig')
            ? ScriptedGeminiApi.error(
                400,
                'Thinking level MINIMAL is not supported for this model.',
              )
            : _ok(c),
      );
      expect(await r.ask([_a]), isA<GeminiOk>());
      expect(r.api.calls.length, 2);
      expect(r.api.calls.last.config!['responseSchema'], isNotNull);
      await r.ask([_a]);
      // The second question starts on the rung that worked.
      expect(r.api.calls.length, 3);
      expect(r.api.calls.last.config!.containsKey('thinkingConfig'), isFalse);
    });

    test('no schema support: JSON is asked for in the prompt', () async {
      final r = await rig(
        (c) => c.config != null
            ? ScriptedGeminiApi.error(400, 'response_schema is not supported')
            : ScriptedGeminiApi.text('{"names":["Rice"]}'),
      );
      expect(((await r.ask([_a])) as GeminiOk).text, '{"names":["Rice"]}');
      expect(r.api.calls.length, 3);
      final last = r.api.calls.last;
      expect(last.config, isNull);
      final parts =
          ((last.body['contents'] as List).single as Map)['parts'] as List;
      expect((parts.first as Map)['text'], contains('JSON only'));
      expect((parts.first as Map)['text'], contains('OBJECT'));
    });

    test('a 400 on every rung is overload-like: next model', () async {
      final r = await rig(
        (c) => c.model == _a ? ScriptedGeminiApi.error(400, 'odd') : _ok(c),
      );
      expect(((await r.ask([_a, _b])) as GeminiOk).model, _b);
      expect(r.asked, [_a, _a, _a, _b]);
    });
  });

  group('what the client forgets', () {
    Future<Rig> limitedA() => rig(
      (c) => c.model == _a
          ? ScriptedGeminiApi.error(429, 'quota', quotaId: _dayQuota)
          : _ok(c),
    );

    test('a new key', () async {
      final r = await limitedA();
      await r.ask([_a, _b]);
      await r.keys.write('key-2');
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _a, _b]);
    });

    test('a changed list', () async {
      final r = await limitedA();
      await r.ask([_a, _b]);
      await r.ask([_b, _a]);
      expect(r.asked, [_a, _b, _b]);
      await r.ask([_a, _b, 'model-c']);
      expect(r.asked.where((m) => m == _a).length, 2);
    });

    test('reset', () async {
      final r = await limitedA();
      await r.ask([_a, _b]);
      r.client.reset();
      await r.ask([_a, _b]);
      expect(r.asked, [_a, _b, _a, _b]);
    });
  });
}
