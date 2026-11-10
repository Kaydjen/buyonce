import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/gemini_client.dart';
import 'package:buyonce/data/repositories/name_suggestion_repository.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/domain/models/gemini_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

final _photo = Uint8List.fromList([1, 2, 3]);

Future<(NameSuggestionRepository, ScriptedGeminiApi)> rig(
  Result<GeminiReply> Function(GeminiCall call) script, {
  bool withKey = true,
}) async {
  final keys = GeminiKeyService();
  if (withKey) await keys.write('key-1');
  final api = ScriptedGeminiApi(script);
  return (NameSuggestionRepository(GeminiClient(api, keys)), api);
}

String _promptOf(GeminiCall call) {
  final parts =
      ((call.body['contents'] as List).single as Map)['parts'] as List;
  return (parts.first as Map)['text'] as String;
}

void main() {
  group('parseNames', () {
    test('keeps up to three clean names in order', () {
      expect(
        NameSuggestionRepository.parseNames(
          '{"names":["  Piątnica   Skyr ","Skyr.","Jogurt pitny","Fourth"]}',
        ),
        ['Piątnica Skyr', 'Skyr', 'Jogurt pitny'],
      );
    });

    test('drops empty names and repeats in any letter case', () {
      expect(
        NameSuggestionRepository.parseNames(
          '{"names":["Milk","  ","milk","MILK!", 5, null]}',
        ),
        ['Milk'],
      );
    });

    test('an ALL CAPS name is put in sentence case, mixed case stays', () {
      expect(
        NameSuggestionRepository.parseNames(
          '{"names":["ZIEMNIAKI MĄCZYSTE","tołpa pianka","Piątnica Skyr"]}',
        ),
        ['Ziemniaki mączyste', 'tołpa pianka', 'Piątnica Skyr'],
      );
    });

    test('a short all-capital name (USB, SER) is left alone', () {
      expect(NameSuggestionRepository.parseNames('{"names":["USB","SER"]}'), [
        'USB',
        'SER',
      ]);
    });

    test('a broken answer gives nothing', () {
      for (final bad in ['', 'not json', '[]', '{"names":"Milk"}', '{"x":1}']) {
        expect(NameSuggestionRepository.parseNames(bad), isEmpty, reason: bad);
      }
    });

    test('a long name is clipped to the product limit', () {
      final names = NameSuggestionRepository.parseNames(
        '{"names":["${'a' * 150}"]}',
      );
      expect(names.single.length, 100);
    });
  });

  group('prompt', () {
    test(
      'packaging name untranslated, the app language only as a fallback',
      () {
        final p = NameSuggestionRepository.prompt('Ukrainian', const []);
        expect(p, contains('exactly as printed on the packaging'));
        expect(p, contains('never translate'));
        expect(p, contains('in Ukrainian'));
        expect(p, contains('not ALL CAPS'));
        expect(p, isNot(contains('already has these names')));
      },
    );

    test('carries the known names when there are some', () {
      final p = NameSuggestionRepository.prompt('English', [
        'Milk',
        'Ziemniaki',
      ]);
      expect(p, contains('Milk; Ziemniaki'));
      expect(p, contains('give that exact name first'));
    });

    test('a long catalog is cut', () {
      final names = [for (var i = 0; i < 500; i++) 'p$i'];
      final p = NameSuggestionRepository.prompt('English', names);
      expect(p, contains('p299'));
      expect(p, isNot(contains('p300')));
    });
  });

  group('suggest', () {
    test(
      'returns names and model; sends photo, schema and the models',
      () async {
        final (repo, api) = await rig(
          (_) =>
              ScriptedGeminiApi.text('{"names":["Kapusta kiszona","Kapusta"]}'),
        );
        final out = await repo.suggest(
          _photo,
          language: 'English',
          models: defaultItemModels,
        );
        expect(out, isA<SuggestedNames>());
        expect((out as SuggestedNames).names, ['Kapusta kiszona', 'Kapusta']);
        expect(out.model, 'gemini-3.5-flash-lite');
        final call = api.calls.single;
        expect(call.config!['responseSchema'], NameSuggestionRepository.schema);
        expect(_promptOf(call), contains('in English'));
      },
    );

    test('knownNames reach the prompt', () async {
      final (repo, api) = await rig(
        (_) => ScriptedGeminiApi.text('{"names":["Milk"]}'),
      );
      await repo.suggest(
        _photo,
        language: 'English',
        models: ['m'],
        knownNames: ['Milk', 'Eggs'],
      );
      expect(_promptOf(api.calls.single), contains('Milk; Eggs'));
    });

    test('an answer with no usable name is a failure', () async {
      final (repo, _) = await rig(
        (_) => ScriptedGeminiApi.text('{"names":["  ","!"]}'),
      );
      final out = await repo.suggest(
        _photo,
        language: 'English',
        models: ['m'],
      );
      expect((out as NoSuggestions).outcome, isA<GeminiFailed>());
    });

    test('the reason of a refused request is passed on', () async {
      final (noKey, _) = await rig(
        (_) => ScriptedGeminiApi.text('{}'),
        withKey: false,
      );
      final out = await noKey.suggest(
        _photo,
        language: 'English',
        models: ['m'],
      );
      expect((out as NoSuggestions).outcome, isA<GeminiNoKey>());
    });

    test('a limit of the only model is passed on', () async {
      final (limited, _) = await rig(
        (_) => ScriptedGeminiApi.error(
          429,
          'quota',
          quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
        ),
      );
      final out = await limited.suggest(
        _photo,
        language: 'English',
        models: ['m'],
      );
      expect((out as NoSuggestions).outcome, isA<GeminiLimited>());
    });
  });
}
