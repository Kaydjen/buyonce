import 'dart:convert';
import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/gemini_client.dart';
import 'package:buyonce/data/repositories/receipt_parsing_repository.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/domain/models/amount.dart';
import 'package:buyonce/domain/models/gemini_outcome.dart';
import 'package:buyonce/domain/models/gemini_task.dart';
import 'package:buyonce/domain/models/money.dart';
import 'package:buyonce/domain/models/receipt_reading.dart';
import 'package:flutter_test/flutter_test.dart';

final _photo = Uint8List.fromList([1, 2, 3]);
const _known = ['Milk', 'Bread', 'Ziemniaki'];

/// A hand-written answer in the shape the schema asks for (a real receipt is read in
/// step 68.5). Prices are decimal strings as printed.
const _answer = {
  'store': '  Silpo  ',
  'date': '2026-11-09',
  'currency': 'uah',
  'total': '117,40',
  'discount': '5,00',
  'lines': [
    {
      'raw': 'МОЛОКО 2.5% 1Л',
      'kind': 'item',
      'match': 'milk',
      'count': 2,
      'millilitres': 1000,
      'price': '64,00',
      'discount': '4,00',
    },
    {
      'raw': 'ХЛІБ ДАРНИЦЬКИЙ',
      'kind': 'item',
      'match': 'Rye bread',
      'name': 'ХЛІБ ДАРНИЦЬКИЙ.',
      'price': '32,90',
    },
    {'raw': 'Пакет', 'kind': 'bag', 'price': '9,50'},
    {'raw': 'Знижка Сільпо', 'kind': 'discount', 'price': '5,00'},
    {'raw': 'РАЗОМ', 'kind': 'total', 'price': '117,40'},
  ],
};

ReceiptReading? _parse(Object? answer) => ReceiptParsingRepository.parse(
  answer is String ? answer : jsonEncode(answer),
  knownNames: _known,
  fallbackCurrency: 'PLN',
);

Future<(ReceiptParsingRepository, ScriptedGeminiApi)> _rig(
  Result<GeminiReply> Function(GeminiCall call) script, {
  bool withKey = true,
}) async {
  final keys = GeminiKeyService();
  if (withKey) await keys.write('key-1');
  final api = ScriptedGeminiApi(script);
  return (ReceiptParsingRepository(GeminiClient(api, keys)), api);
}

void main() {
  group('parse', () {
    test('lines, amounts and prices become domain values', () {
      final r = _parse(_answer)!;
      expect(r.store, 'Silpo');
      expect(r.date, DateTime(2026, 11, 9));
      expect(r.total, const Money(11740, 'UAH'));
      expect(r.discount, const Money(500, 'UAH'));
      expect(r.lines.length, 5);
      final milk = r.lines[0];
      expect(milk.kind, ReceiptLineKind.item);
      expect(milk.match, 'Milk'); // the catalog's own spelling
      expect(milk.name, isNull);
      expect(milk.amount, const Amount(count: 2, millilitres: 1000));
      // The mark price is what was paid: printed 64,00 minus the 4,00 discount.
      expect(milk.price, const Money(6000, 'UAH'));
      expect(milk.discount, const Money(400, 'UAH'));
      expect(r.items.length, 2);
    });

    test('a match outside the catalog is rejected and the line is new', () {
      final bread = _parse(_answer)!.lines[1];
      expect(bread.match, isNull);
      expect(bread.name, 'Хліб дарницький');
      expect(bread.label, 'Хліб дарницький');
      expect(bread.price, const Money(3290, 'UAH'));
      expect(bread.discount, isNull);
    });

    test('non-items carry no match, name or amount', () {
      final bag = _parse({
        'lines': [
          {
            'raw': 'Пакет',
            'kind': 'bag',
            'match': 'Milk',
            'name': 'Bag',
            'count': 3,
            'price': '9,50',
          },
        ],
      })!.lines.single;
      expect(bag.match, isNull);
      expect(bag.name, isNull);
      expect(bag.amount, Amount.none);
      expect(bag.price, const Money(950, 'PLN')); // the fallback currency
    });

    test('an item with no proposed name takes its printed text', () {
      final line = _parse({
        'lines': [
          {'raw': '  ZIEMNIAKI   MĄCZYSTE ', 'kind': 'item'},
        ],
      })!.lines.single;
      expect(line.name, 'Ziemniaki mączyste');
      expect(line.raw, 'ZIEMNIAKI MĄCZYSTE');
      expect(line.price, isNull);
    });

    test('rubbish values become "unknown", never a made-up value', () {
      final r = _parse({
        'currency': 'euro',
        'date': '2026-02-31',
        'total': 'n/a',
        'lines': [
          {
            'raw': 'Tea',
            'kind': 'wrong-kind',
            'price': 'free',
            'count': 0,
            'grams': -5,
          },
          {
            'raw': 'Jam',
            'kind': 'item',
            'price': '3,00',
            'discount': '9,00',
            'count': 0,
            'grams': 250.5,
          },
          {'kind': 'item'},
          'text',
          {'raw': '  ', 'kind': 'item'},
        ],
      })!;
      expect(r.date, isNull);
      expect(r.total, isNull);
      expect(r.store, isNull);
      expect(r.lines.length, 2);
      expect(r.lines[0].kind, ReceiptLineKind.other);
      expect(r.lines[0].price, isNull);
      final jam = r.lines[1];
      expect(
        jam.price,
        const Money(300, 'PLN'),
      ); // a discount above the price is dropped
      expect(jam.discount, isNull);
      expect(jam.amount, Amount.none);
    });

    test('a negative total or discount is read as its absolute value', () {
      final r = _parse({
        'total': '-10,00',
        'discount': '-2,50',
        'lines': [
          {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
        ],
      })!;
      expect(r.total, const Money(1000, 'PLN'));
      expect(r.discount, const Money(250, 'PLN'));
    });

    test('a broken answer gives nothing', () {
      for (final bad in [
        '',
        'not json',
        '[]',
        '{"lines":"x"}',
        '{"lines":[]}',
        '{"store":"x"}',
        '{"lines":[{"kind":"item"}]}',
      ]) {
        expect(_parse(bad), isNull, reason: bad);
      }
    });

    test('at most 200 lines are kept', () {
      final r = _parse({
        'lines': [
          for (var i = 0; i < 250; i++) {'raw': 'p$i', 'kind': 'item'},
        ],
      })!;
      expect(r.lines.length, 200);
    });
  });

  group('sum check', () {
    test('the lines minus the receipt discount equal the total', () {
      // 60,00 + 32,90 + 9,50 = 102,40 and the 5,00 discount: 97,40, not 117,40.
      expect(_parse(_answer)!.linesMatchTotal, isFalse);
      final ok = _parse({..._answer, 'total': '97,40'})!;
      expect(ok.linesMatchTotal, isTrue);
    });

    test(
      'no total: nothing to check; a charged line without a price: false',
      () {
        expect(
          _parse({
            'lines': [
              {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
            ],
          })!.linesMatchTotal,
          isNull,
        );
        expect(
          _parse({
            'total': '10,00',
            'lines': [
              {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
              {'raw': 'Jam', 'kind': 'item'},
            ],
          })!.linesMatchTotal,
          isFalse,
        );
      },
    );

    test('total, VAT and other lines do not count', () {
      final r = _parse({
        'total': '10,00',
        'lines': [
          {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
          {'raw': 'Разом', 'kind': 'total', 'price': '10,00'},
          {'raw': 'VAT', 'kind': 'other', 'price': '1,67'},
        ],
      })!;
      expect(r.linesMatchTotal, isTrue);
    });
  });

  group('discount lines', () {
    test(
      'a discount line under an item lowers its price (amount in price)',
      () {
        final r = _parse({
          'total': '28,79',
          'lines': [
            {'raw': 'Podudzie', 'kind': 'item', 'price': '22,65'},
            {'raw': 'Rabat -4,85', 'kind': 'discount', 'price': '4,85'},
            {'raw': 'Jaja', 'kind': 'item', 'price': '10,99'},
          ],
        })!;
        expect(r.lines[0].price, const Money(1780, 'PLN'));
        expect(r.lines[0].discount, const Money(485, 'PLN'));
        expect(r.lines[2].discount, isNull);
        expect(r.discount, isNull);
        expect(r.linesMatchTotal, isTrue);
      },
    );

    test('the amount may sit in the discount field, even negative', () {
      final r = _parse({
        'total': '5,00',
        'lines': [
          {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
          {'raw': 'Rabat', 'kind': 'discount', 'discount': '-5,00'},
        ],
      })!;
      expect(r.lines[0].price, const Money(500, 'PLN'));
      expect(r.linesMatchTotal, isTrue);
    });

    test('two discount lines under one item both attach', () {
      final r = _parse({
        'lines': [
          {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
          {'raw': 'Rabat', 'kind': 'discount', 'price': '1,00'},
          {'raw': 'Promo', 'kind': 'discount', 'price': '2,00'},
        ],
      })!;
      expect(r.lines[0].price, const Money(700, 'PLN'));
      expect(r.lines[0].discount, const Money(300, 'PLN'));
    });

    test('a discount that follows no item, or exceeds it, is for the whole receipt', () {
      final r = _parse({
        'total': '9,00',
        'discount': '99,00', // the model's own sum is replaced by the lines
        'lines': [
          {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
          {'raw': 'Suma', 'kind': 'total', 'price': '10,00'},
          {'raw': 'Karta -1,00', 'kind': 'discount', 'price': '1,00'},
          {'raw': 'Big', 'kind': 'discount', 'price': '50,00'},
        ],
      })!;
      expect(r.lines[0].price, const Money(1000, 'PLN'));
      expect(r.discount, const Money(5100, 'PLN'));
    });

    test(
      'without discount lines the model sum of receipt discounts stands',
      () {
        final r = _parse({
          'discount': '2,00',
          'lines': [
            {'raw': 'Tea', 'kind': 'item', 'price': '10,00'},
          ],
        })!;
        expect(r.discount, const Money(200, 'PLN'));
      },
    );
  });

  group('prompt and request', () {
    test('the prompt carries the catalog and the decimal-string rule', () {
      final p = ReceiptParsingRepository.prompt('Ukrainian', _known);
      expect(p, contains('Milk; Bread; Ziemniaki'));
      expect(p, contains('Never invent a match'));
      expect(p, contains('decimal strings'));
      expect(p, contains('in the language and style of the products above'));
    });

    test('an empty catalog: no match, new names in the app language', () {
      final p = ReceiptParsingRepository.prompt('Ukrainian', const []);
      expect(p, contains('"match" is always null'));
      expect(p, contains('in Ukrainian'));
    });

    test('a long catalog is cut', () {
      final names = [for (var i = 0; i < 500; i++) 'p$i'];
      final p = ReceiptParsingRepository.prompt('English', names);
      expect(p, contains('p299'));
      expect(p, isNot(contains('p300')));
    });

    test('the schema asks for lines and every kind', () {
      final props = ReceiptParsingRepository.schema['properties']! as Map;
      expect(props.keys, containsAll(['store', 'date', 'currency', 'lines']));
      final kind =
          (((props['lines']! as Map)['items']! as Map)['properties']!
                  as Map)['kind']!
              as Map;
      expect(kind['enum'], hasLength(ReceiptLineKind.values.length));
      for (final k in ReceiptLineKind.values) {
        expect(kind['enum'], contains(k.name));
      }
    });
  });

  group('read', () {
    test('sends all photos, schema and models; returns the reading', () async {
      final (repo, api) = await _rig(
        (_) => ScriptedGeminiApi.text(jsonEncode(_answer)),
      );
      final out = await repo.read(
        [_photo, _photo],
        language: 'English',
        models: defaultReceiptModels,
        knownNames: _known,
        fallbackCurrency: 'PLN',
      );
      expect(out, isA<ParsedReceipt>());
      expect((out as ParsedReceipt).reading.lines.length, 5);
      expect(out.model, defaultReceiptModels.first);
      final call = api.calls.single;
      expect(call.config!['responseSchema'], ReceiptParsingRepository.schema);
      final parts =
          ((call.body['contents'] as List).single as Map)['parts'] as List;
      expect(parts.length, 3); // the prompt and two photos
      expect((parts[2] as Map)['inlineData'], isNotNull);
    });

    test('no photos or too many: failed, nothing is sent', () async {
      final (repo, api) = await _rig(
        (_) => ScriptedGeminiApi.text(jsonEncode(_answer)),
      );
      for (final photos in [
        <Uint8List>[],
        [_photo, _photo, _photo, _photo],
      ]) {
        final out = await repo.read(
          photos,
          language: 'English',
          models: ['m'],
          knownNames: _known,
          fallbackCurrency: 'PLN',
        );
        expect(out, isA<NoReceipt>());
      }
      expect(api.calls, isEmpty);
    });

    test('a broken answer is a failure', () async {
      final (broken, _) = await _rig((_) => ScriptedGeminiApi.text('nope'));
      final out = await broken.read(
        [_photo],
        language: 'English',
        models: ['m'],
        knownNames: _known,
        fallbackCurrency: 'PLN',
      );
      expect((out as NoReceipt).outcome, isA<GeminiFailed>());
    });

    test('a client outcome (no key) passes through', () async {
      final (noKey, _) = await _rig(
        (_) => ScriptedGeminiApi.text('{}'),
        withKey: false,
      );
      final out2 = await noKey.read(
        [_photo],
        language: 'English',
        models: ['m'],
        knownNames: _known,
        fallbackCurrency: 'PLN',
      );
      expect((out2 as NoReceipt).outcome, isA<GeminiNoKey>());
    });
  });
}
