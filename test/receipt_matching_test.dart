import 'dart:convert';
import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/gemini_client.dart';
import 'package:buyonce/data/repositories/receipt_alias_repository.dart';
import 'package:buyonce/data/repositories/receipt_parsing_repository.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/data/services/settings_service.dart';
import 'package:buyonce/domain/models/receipt_matching.dart';
import 'package:buyonce/domain/models/receipt_reading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'receipt_fixtures.dart';

const _catalog = [
  'Milk',
  'Eggs',
  'Картошка',
  'Serek homogenizowany brzoskwiniowy',
  'Serek homogenizowany waniliowy',
];

/// An item line as the first reader left it: a candidate with its reasons.
ReceiptLine _line(
  String raw, {
  String? match,
  bool high = true,
  bool evidence = true,
}) => ReceiptLine(
  raw: raw,
  kind: ReceiptLineKind.item,
  match: match,
  tier: match == null ? MatchTier.none : MatchTier.check,
  highConfidence: match != null && high,
  evidenceOk: match != null && evidence,
);

ReceiptReading _reading(List<ReceiptLine> lines) =>
    ReceiptReading(lines: lines);

MatchTier _tier(ReceiptReading r, int i) => r.lines[i].tier;

void main() {
  group('text helpers', () {
    test('foldText lowers and drops accents', () {
      expect(foldText('ŁĄKA Śliwka'), 'laka sliwka');
      expect(foldText('Яйця'), 'яйця');
    });

    test(
      'printedKey keeps the words, not the weights, prices and tax letters',
      () {
        expect(
          printedKey('JajaSciol M 10szt C 1 x10,99 10,99C'),
          printedKey('JajaSciol M 12szt C 1 x11,49 11,49C'),
        );
        expect(
          printedKey('Podu ku Mega p kg C 1,620 x13,99 22,65C'),
          'podu ku mega',
        );
        expect(printedKey('3001994  12,99 A'), '');
      },
    );

    test('look-alikes: shared words, not the same name', () {
      expect(
        areLookAlikes(
          'Serek homogenizowany brzoskwiniowy',
          'Serek homogenizowany waniliowy',
        ),
        isTrue,
      );
      expect(areLookAlikes('Молоко', 'Молоко безлактозне'), isTrue);
      expect(areLookAlikes('Milk', 'Eggs'), isFalse);
      expect(areLookAlikes('Milk', 'milk'), isFalse);
      expect(lookAlikesOf('Serek homogenizowany waniliowy', _catalog), [
        'Serek homogenizowany brzoskwiniowy',
      ]);
    });

    test('a look-alike is told apart only by a word the line really has', () {
      const peach = 'Serek homogenizowany brzoskwiniowy';
      final twins = lookAlikesOf(peach, _catalog);
      expect(tellsApart(peach, twins, 'SEREK HOMOG BRZOSK 150G'), isTrue);
      expect(tellsApart(peach, twins, 'SEREK HOMOG 150G'), isFalse);
      expect(tellsApart(peach, twins, 'SEREK WANIL'), isFalse);
    });
  });

  group('decideMatches', () {
    test('both readers agree, high, evidence, no look-alike: confirmed', () {
      final r = decideMatches(
        _reading([_line('JAJA M 10SZT', match: 'Eggs')]),
        knownNames: _catalog,
        matcher: {0: 'eggs'},
      );
      expect(_tier(r, 0), MatchTier.confirmed);
      expect(r.lines[0].match, 'Eggs');
    });

    test('the second reader names another product: only a candidate', () {
      final r = decideMatches(
        _reading([_line('Podu ku Mega p kg', match: 'Картошка')]),
        knownNames: _catalog,
        matcher: {0: 'Milk'},
      );
      expect(_tier(r, 0), MatchTier.check);
      expect(r.lines[0].match, 'Картошка');
    });

    test(
      'the second reader finds nothing: only a candidate (the potato case)',
      () {
        final r = decideMatches(
          _reading([_line('Podu ku Mega p kg', match: 'Картошка')]),
          knownNames: _catalog,
          matcher: {0: null},
        );
        expect(_tier(r, 0), MatchTier.check);
      },
    );

    test('no second opinion: nothing is ticked by itself', () {
      final r = decideMatches(
        _reading([
          _line('JAJA M 10SZT', match: 'Eggs'),
          _line('MLEKO', match: 'Milk'),
        ]),
        knownNames: _catalog,
        matcher: null,
      );
      expect(r.lines.map((l) => l.tier), [MatchTier.check, MatchTier.check]);
    });

    test(
      'low confidence, or evidence that is not in the line: a candidate',
      () {
        final r = decideMatches(
          _reading([
            _line('JAJA', match: 'Eggs', high: false),
            _line('JAJA', match: 'Eggs', evidence: false),
          ]),
          knownNames: _catalog,
          matcher: {0: 'Eggs', 1: 'Eggs'},
        );
        expect(r.lines.map((l) => l.tier), [MatchTier.check, MatchTier.check]);
      },
    );

    test('look-alikes in the catalog: confirmed only when the line tells them apart', () {
      const peach = 'Serek homogenizowany brzoskwiniowy';
      final r = decideMatches(
        _reading([
          _line('SEREK HOMOG 150G', match: peach),
          _line('SEREK HOMOG BRZOSK 150G', match: peach),
        ]),
        knownNames: _catalog,
        matcher: {0: peach, 1: peach},
      );
      expect(_tier(r, 0), MatchTier.check);
      expect(_tier(r, 1), MatchTier.confirmed);
    });

    test(
      'a line only the second reader matched is a candidate, never ticked',
      () {
        final r = decideMatches(
          _reading([_line('JAJA', match: null)]),
          knownNames: _catalog,
          matcher: {0: 'Eggs'},
        );
        expect(_tier(r, 0), MatchTier.check);
        expect(r.lines[0].match, 'Eggs');
      },
    );

    test('nobody matched: none', () {
      final r = decideMatches(
        _reading([_line('KOMIN', match: null)]),
        knownNames: _catalog,
        matcher: {0: null},
      );
      expect(_tier(r, 0), MatchTier.none);
      expect(r.lines[0].match, isNull);
    });

    test(
      'a pair the user confirmed before is confirmed without the readers',
      () {
        final aliases = {printedKey('JAJA SCIOL M 10SZT'): 'Eggs'};
        final r = decideMatches(
          _reading([
            _line('JAJA SCIOL M 12SZT 11,49', match: 'Milk', high: false),
          ]),
          knownNames: _catalog,
          aliases: aliases,
          matcher: null,
        );
        expect(_tier(r, 0), MatchTier.confirmed);
        expect(r.lines[0].match, 'Eggs');
        expect(r.lines[0].fromAlias, isTrue);
      },
    );

    test('a learned pair whose product is gone is ignored', () {
      final r = decideMatches(
        _reading([_line('JAJA', match: 'Eggs')]),
        knownNames: _catalog,
        aliases: {printedKey('JAJA'): 'Deleted product'},
        matcher: {0: 'Eggs'},
      );
      expect(r.lines[0].fromAlias, isFalse);
      expect(_tier(r, 0), MatchTier.confirmed); // by the readers
    });

    test('other lines are left alone', () {
      final r = decideMatches(
        _reading(const [ReceiptLine(raw: 'SUMA', kind: ReceiptLineKind.total)]),
        knownNames: _catalog,
        matcher: const {},
      );
      expect(r.lines.single.kind, ReceiptLineKind.total);
    });
  });

  group('the readers answer', () {
    test(
      'the first reader: evidence must be in the line, high only when said so',
      () {
        final reading = ReceiptParsingRepository.parse(
          jsonEncode({
            'currency': 'PLN',
            'lines': [
              {
                'raw': 'JajaSciol M 10szt C 1 x10,99 10,99C',
                'kind': 'item',
                'evidence': 'jaja',
                'meaning': 'jaja = яйця',
                'match': 'Eggs',
                'confidence': 'high',
              },
              {
                'raw': 'Podu ku Mega p kg C 1,620 x13,99 22,65C',
                'kind': 'item',
                'evidence': 'kartofel',
                'match': 'Картошка',
                'confidence': 'high',
              },
              {
                'raw': 'MLEKO',
                'kind': 'item',
                'evidence': 'MLEKO',
                'match': 'Milk',
                'confidence': 'low',
              },
            ],
          }),
          knownNames: _catalog,
          fallbackCurrency: 'PLN',
        )!;
        final eggs = reading.lines[0];
        expect(eggs.evidenceOk, isTrue);
        expect(eggs.highConfidence, isTrue);
        expect(eggs.meaning, 'jaja = яйця');
        expect(eggs.tier, MatchTier.check); // not decided yet
        // The quoted word is not printed anywhere in the line: no evidence.
        expect(reading.lines[1].evidenceOk, isFalse);
        expect(reading.lines[2].highConfidence, isFalse);
      },
    );

    test('the second reader: catalog names only, evidence in the line, asked lines only', () {
      final asked = {1: 'JAJA M 10SZT', 3: 'Podu ku Mega', 4: 'SEREK'};
      final out = ReceiptParsingRepository.parseMatcher(
        jsonEncode({
          'matches': [
            {'index': 1, 'evidence': 'jaja', 'match': 'eggs'},
            {'index': 3, 'evidence': 'kartofel', 'match': 'Картошка'},
            {'index': 4, 'evidence': 'SEREK', 'match': 'Not in the list'},
            {'index': 9, 'evidence': 'x', 'match': 'Milk'},
          ],
        }),
        asked,
        _catalog,
      );
      expect(out, {1: 'Eggs', 3: null, 4: null});
      expect(
        ReceiptParsingRepository.parseMatcher('rubbish', asked, _catalog),
        {1: null, 3: null, 4: null},
      );
    });

    test('the prompts say that a wrong match is worse than none', () {
      expect(
        ReceiptParsingRepository.prompt('English', _catalog),
        contains('a wrong match is much worse than none'),
      );
      final p = ReceiptParsingRepository.matcherPrompt({2: 'JAJA'}, _catalog);
      expect(p, contains('2: JAJA'));
      expect(
        p.toLowerCase(),
        contains('a wrong match is much worse than none'),
      );
      expect(p, contains('no evidence, no match'));
    });
  });

  group('the whole read', () {
    final photo = Uint8List.fromList([1, 2, 3]);

    Future<(ReceiptParsingRepository, ScriptedGeminiApi)> rig(
      Result<GeminiReply> Function(GeminiCall call) script,
    ) async {
      await GeminiKeyService().write('key-1');
      final api = ScriptedGeminiApi(script);
      return (
        ReceiptParsingRepository(GeminiClient(api, GeminiKeyService())),
        api,
      );
    }

    final reader = jsonEncode({
      'currency': 'PLN',
      'lines': [
        {
          'raw': 'JajaSciol M 10szt C 1 x10,99 10,99C',
          'kind': 'item',
          'evidence': 'Jaja',
          'meaning': 'jaja = яйця',
          'match': 'Eggs',
          'confidence': 'high',
          'price': '10,99',
        },
        {
          'raw': 'Podu ku Mega p kg C 1,620 x13,99 22,65C',
          'kind': 'item',
          'evidence': 'Podu ku Mega',
          'meaning': 'mega = картошка',
          'match': 'Картошка',
          'confidence': 'high',
          'price': '22,65',
        },
      ],
    });

    Future<ParsedReceipt> read(
      ReceiptParsingRepository repo, {
      Map<String, String> aliases = const {},
      List<String> names = _catalog,
      List<String> models = const ['model-a', 'model-b'],
    }) async => await repo.read(
      [photo],
      language: 'English',
      models: models,
      knownNames: names,
      fallbackCurrency: 'PLN',
      aliases: aliases,
    ) as ParsedReceipt;

    test('a garbled line the second reader cannot place is not ticked (the potato case)', () async {
      final (repo, api) = await rig(
        (c) => receiptReply(
          c,
          reader,
          matcher: jsonEncode({
            'matches': [
              {'index': 0, 'evidence': 'Jaja', 'match': 'Eggs'},
              {'index': 1, 'evidence': 'Podu ku Mega', 'match': null},
            ],
          }),
        ),
      );
      final out = await read(repo);
      expect(out.secondOpinion, isTrue);
      expect(out.reading.lines[0].tier, MatchTier.confirmed);
      expect(out.reading.lines[1].tier, MatchTier.check);
      expect(out.reading.lines[1].match, 'Картошка'); // shown as a candidate
      expect(api.calls.length, 2);
    });

    test('the second reader is text only and prefers another model', () async {
      final (repo, api) = await rig((c) => receiptReply(c, reader));
      await read(repo);
      final second = api.calls[1];
      expect(isMatcherCall(second), isTrue);
      final parts =
          ((second.body['contents'] as List).single as Map)['parts'] as List;
      expect(parts.length, 1); // the prompt only, no photo
      expect(promptOf(second), contains('0: JajaSciol'));
      expect(promptOf(second), contains('1: Podu ku Mega'));
      expect(api.calls.first.model, 'model-a');
      expect(second.model, 'model-b');
    });

    test('the second reader fails: still usable, nothing is ticked', () async {
      final (repo, _) = await rig(
        (c) => isMatcherCall(c)
            ? ScriptedGeminiApi.text('not json at all')
            : ScriptedGeminiApi.text(reader),
      );
      var out = await read(repo);
      // Garbage is "found nothing": candidates only.
      expect(out.reading.lines.every((l) => l.tier == MatchTier.check), isTrue);

      final (repo2, _) = await rig(
        (c) => isMatcherCall(c)
            ? ScriptedGeminiApi.error(500, 'down')
            : ScriptedGeminiApi.text(reader),
      );
      out = await read(repo2);
      expect(out.secondOpinion, isFalse);
      expect(out.reading.lines.every((l) => l.tier == MatchTier.check), isTrue);
      expect(out.reading.lines.map((l) => l.match), ['Eggs', 'Картошка']);
    });

    test('a known pair is not asked about again', () async {
      final (repo, api) = await rig((c) => receiptReply(c, reader));
      final out = await read(
        repo,
        aliases: {printedKey('JajaSciol M 10szt C 1 x10,99 10,99C'): 'Eggs'},
      );
      expect(out.reading.lines[0].fromAlias, isTrue);
      expect(out.reading.lines[0].tier, MatchTier.confirmed);
      expect(promptOf(api.calls[1]), isNot(contains('JajaSciol')));
      expect(promptOf(api.calls[1]), contains('Podu ku Mega'));
    });

    test(
      'everything known: no second request; an empty catalog: none either',
      () async {
        final (repo, api) = await rig((c) => receiptReply(c, reader));
        await read(
          repo,
          aliases: {
            printedKey('JajaSciol M 10szt C 1 x10,99 10,99C'): 'Eggs',
            printedKey('Podu ku Mega p kg C 1,620 x13,99 22,65C'): 'Картошка',
          },
        );
        expect(api.calls.length, 1);

        final (repo2, api2) = await rig((c) => receiptReply(c, reader));
        final out = await read(repo2, names: const []);
        expect(api2.calls.length, 1);
        expect(out.reading.lines.every((l) => l.match == null), isTrue);
      },
    );
  });

  group('learned pairs', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'a pair is kept per list, the newest wins, forgetting removes it',
      () async {
        final repo = ReceiptAliasRepository(SettingsService());
        expect(await repo.load('g1'), isEmpty);
        await repo.learn('g1', {'jaja': 'p1', 'mleko': 'p2'});
        await repo.learn('g2', {'jaja': 'other'});
        expect(await repo.load('g1'), {'jaja': 'p1', 'mleko': 'p2'});
        expect(await repo.load('g2'), {'jaja': 'other'});
        await repo.learn('g1', {'jaja': 'p3'});
        expect((await repo.load('g1'))['jaja'], 'p3');
        await repo.forget('g1', ['jaja', 'unknown']);
        expect(await repo.load('g1'), {'mleko': 'p2'});
        // A new object reads what an old one stored.
        expect(await ReceiptAliasRepository(SettingsService()).load('g1'), {
          'mleko': 'p2',
        });
      },
    );

    test(
      'the oldest pairs go past the limit; damaged data reads as empty',
      () async {
        final repo = ReceiptAliasRepository(SettingsService());
        await repo.learn('g', {
          for (var i = 0; i < ReceiptAliasRepository.maxPerList + 5; i++)
            'k$i': 'p$i',
        });
        final kept = await repo.load('g');
        expect(kept.length, ReceiptAliasRepository.maxPerList);
        expect(kept.containsKey('k0'), isFalse);
        expect(
          kept.containsKey('k${ReceiptAliasRepository.maxPerList + 4}'),
          isTrue,
        );

        SharedPreferences.setMockInitialValues({
          ReceiptAliasRepository.storeKey: '{not json',
        });
        expect(
          await ReceiptAliasRepository(SettingsService()).load('g'),
          isEmpty,
        );
        await ReceiptAliasRepository(SettingsService()).learn('g', {'a': 'b'});
        expect(await ReceiptAliasRepository(SettingsService()).load('g'), {
          'a': 'b',
        });
      },
    );
  });
}
