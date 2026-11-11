import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/clip.dart';
import '../../domain/models/amount.dart';
import '../../domain/models/gemini_outcome.dart';
import '../../domain/models/money.dart';
import '../../domain/models/product_names.dart';
import '../../domain/models/receipt_matching.dart';
import '../../domain/models/receipt_reading.dart';
import 'gemini_client.dart';
import 'name_suggestion_repository.dart';

/// What the photos of a receipt gave: the reading, or the reason there is none.
sealed class ReceiptParsing {
  const ReceiptParsing();
}

final class ParsedReceipt extends ReceiptParsing {
  const ParsedReceipt(this.reading, this.model, {this.secondOpinion = true});
  final ReceiptReading reading;
  final String model;

  /// The second reader answered. When it did not (limits, no connection) nothing but a
  /// confirmed alias is ticked: the screen still works, it only trusts less.
  final bool secondOpinion;
}

final class NoReceipt extends ReceiptParsing {
  const NoReceipt(this.outcome);

  /// Never a [GeminiOk]: that is a [ParsedReceipt].
  final GeminiOutcome outcome;
}

/// The task "read this receipt", on top of [GeminiClient]. The model only reads text;
/// the app does every conversion it can do better: prices arrive as printed strings and
/// become minor units here, a `match` outside the catalog is rejected, the sum of the
/// lines is checked against the total ([ReceiptReading.linesMatchTotal]).
class ReceiptParsingRepository {
  ReceiptParsingRepository(this._client);
  final GeminiClient _client;

  /// A long receipt is photographed in parts; more parts than this are not sent.
  static const maxPhotos = 3;

  /// Most catalog names a prompt carries (the same cut as for one item photo).
  static const maxKnownNames = NameSuggestionRepository.maxKnownNames;

  /// Called when the camera opens: the connection is ready when the photo is.
  Future<void> warmUp() => _client.warmUp();

  static const _maxLines = 200;
  static const _kinds = [
    'item',
    'discount',
    'fee',
    'deposit',
    'bag',
    'total',
    'other',
  ];

  static const schema = <String, Object?>{
    'type': 'OBJECT',
    'properties': {
      'store': {'type': 'STRING', 'nullable': true},
      'date': {'type': 'STRING', 'nullable': true},
      'currency': {'type': 'STRING', 'nullable': true},
      'total': {'type': 'STRING', 'nullable': true},
      'discount': {'type': 'STRING', 'nullable': true},
      'lines': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'raw': {'type': 'STRING'},
            'kind': {'type': 'STRING', 'enum': _kinds},
            'evidence': {'type': 'STRING', 'nullable': true},
            'meaning': {'type': 'STRING', 'nullable': true},
            'match': {'type': 'STRING', 'nullable': true},
            'confidence': {
              'type': 'STRING',
              'enum': ['high', 'low'],
              'nullable': true,
            },
            'name': {'type': 'STRING', 'nullable': true},
            'count': {'type': 'INTEGER', 'nullable': true},
            'grams': {'type': 'INTEGER', 'nullable': true},
            'millilitres': {'type': 'INTEGER', 'nullable': true},
            'price': {'type': 'STRING', 'nullable': true},
            'discount': {'type': 'STRING', 'nullable': true},
          },
          // The reason comes before the answer: a model that has to quote the printed
          // words first guesses less.
          'propertyOrdering': [
            'raw',
            'kind',
            'evidence',
            'meaning',
            'match',
            'confidence',
            'name',
            'count',
            'grams',
            'millilitres',
            'price',
            'discount',
          ],
          'required': ['raw', 'kind'],
        },
      },
    },
    'required': ['lines'],
  };

  static const matcherSchema = <String, Object?>{
    'type': 'OBJECT',
    'properties': {
      'matches': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'index': {'type': 'INTEGER'},
            'evidence': {'type': 'STRING', 'nullable': true},
            'match': {'type': 'STRING', 'nullable': true},
          },
          'propertyOrdering': ['index', 'evidence', 'match'],
          'required': ['index'],
        },
      },
    },
    'required': ['matches'],
  };

  /// [photos] are JPEGs of the same receipt, in order (at most [maxPhotos]).
  /// [knownNames] are the names of the active products, the ones that matter most first
  /// (a long catalog is cut); [language] is the English name of the app language, used
  /// for new names when the catalog is empty; [fallbackCurrency] (ISO code) is used
  /// when the receipt shows none. [aliases] are pairs the user confirmed before
  /// (printed key -> catalog name).
  ///
  /// Two readers: the first reads the photos and proposes matches; a second one, text
  /// only and preferably another model, is asked about the same lines. `decideMatches`
  /// ticks only what both agree on.
  Future<ReceiptParsing> read(
    List<Uint8List> photos, {
    required String language,
    required List<String> models,
    required List<String> knownNames,
    required String fallbackCurrency,
    Map<String, String> aliases = const {},
  }) async {
    if (photos.isEmpty || photos.length > maxPhotos) {
      return const NoReceipt(GeminiFailed());
    }
    final outcome = await _client.generate(
      GeminiRequest(
        prompt: prompt(language, knownNames),
        schema: schema,
        images: photos,
      ),
      models,
    );
    if (outcome is! GeminiOk) return NoReceipt(outcome);
    final parsed = parse(
      outcome.text,
      knownNames: knownNames,
      fallbackCurrency: fallbackCurrency,
    );
    if (parsed == null) return const NoReceipt(GeminiFailed());

    final second = await _secondOpinion(
      parsed,
      knownNames: knownNames,
      aliases: aliases,
      models: models,
      readerModel: outcome.model,
    );
    final reading = decideMatches(
      parsed,
      knownNames: knownNames,
      aliases: aliases,
      matcher: second,
    );
    return ParsedReceipt(reading, outcome.model, secondOpinion: second != null);
  }

  /// The second reader's matches by line index, or null when it could not answer.
  Future<Map<int, String?>?> _secondOpinion(
    ReceiptReading reading, {
    required List<String> knownNames,
    required Map<String, String> aliases,
    required List<String> models,
    required String readerModel,
  }) async {
    final asked = <int, String>{};
    for (var i = 0; i < reading.lines.length; i++) {
      final line = reading.lines[i];
      if (line.kind != ReceiptLineKind.item) continue;
      final learned = aliases[printedKey(line.raw)];
      if (learned != null &&
          knownNames.any((n) => ProductNames.same(n, learned))) {
        continue; // the user already confirmed this one
      }
      asked[i] = line.raw;
    }
    // Nothing to ask, or nothing to match with: an empty answer is a complete one.
    if (asked.isEmpty || knownNames.isEmpty) return const {};
    // Another model than the one that read the photos, when there is one.
    final others = [
      for (final m in models)
        if (m.replaceFirst('models/', '') != readerModel) m,
    ];
    final ordered = [...others, ...models.where((m) => !others.contains(m))];
    final outcome = await _client.generate(
      GeminiRequest(
        prompt: matcherPrompt(asked, knownNames),
        schema: matcherSchema,
      ),
      ordered,
    );
    if (outcome is! GeminiOk) return null;
    return parseMatcher(outcome.text, asked, knownNames);
  }

  static String matcherPrompt(Map<int, String> lines, List<String> knownNames) {
    final known = knownNames.take(maxKnownNames).toList();
    return [
      'These are lines of a shop receipt, as "number: printed text":',
      [for (final e in lines.entries) '${e.key}: ${e.value}'].join('\n'),
      'The shopping list has these products: ${known.join('; ')}.',
      'For every line say which product of the list it is, or null. A wrong match is '
          'much worse than none: answer null when the printed text is abbreviated, '
          'garbled or not clearly that product. Many products are look-alikes of each '
          'other (flavours, sizes): pick one only when the text tells which. Before '
          '"match" copy into "evidence" the exact words of the line that name the '
          'product; no evidence, no match. The receipt may be printed in another '
          'language than the list: translate first.',
    ].join(' ');
  }

  /// The matches of the second reader: only for the lines that were asked, only a name
  /// of the catalog (in its own spelling), and only with evidence that is really in the
  /// printed line; anything else is "none".
  static Map<int, String?> parseMatcher(
    String text,
    Map<int, String> asked,
    List<String> knownNames,
  ) {
    final result = <int, String?>{for (final i in asked.keys) i: null};
    final Object? json;
    try {
      json = jsonDecode(text);
    } catch (_) {
      return result;
    }
    final list = json is Map ? json['matches'] : null;
    if (list is! List) return result;
    for (final item in list) {
      if (item is! Map) continue;
      final index = item['index'];
      if (index is! int || !asked.containsKey(index)) continue;
      final name = item['match'];
      if (name is! String) continue;
      final known = knownNames.where((n) => ProductNames.same(n, name));
      if (known.isEmpty) continue;
      if (!_evidenceIn(item['evidence'], asked[index]!)) continue;
      result[index] = known.first;
    }
    return result;
  }

  /// Are the quoted words really in the printed line (any case, no accents)?
  static bool _evidenceIn(Object? evidence, String raw) {
    if (evidence is! String) return false;
    final quote = foldText(evidence.trim().replaceAll(RegExp(r'\s+'), ' '));
    return quote.length >= 2 &&
        foldText(raw.replaceAll(RegExp(r'\s+'), ' ')).contains(quote);
  }

  static String prompt(String language, List<String> knownNames) {
    final known = knownNames.take(maxKnownNames).toList();
    return [
      'The photos show one shopping receipt, in order from top to bottom; parts may '
          'overlap, so read every printed line once.',
      'Return every printed line in "lines", in receipt order. Copy "raw" exactly as '
          'printed. "kind": item for a purchased product (also weighed and by-the-piece '
          'ones), discount for a separate discount or bonus line, fee for a service '
          'charge, deposit for a bottle or container deposit, bag for a carrier bag, '
          'total for the total or payment lines, other for anything else (card '
          'numbers, VAT summaries, addresses).',
      'Numbers are decimal strings exactly as printed, with the printed decimal '
          'separator and no currency sign, for example "32,90".',
      'For an item, "price" is its line total as printed, before any discount line. '
          'For a separate discount line (kind discount, for example "Rabat -4,85") put '
          'its positive amount in "price" and leave "match" and "name" empty; do not '
          'copy it into the discount of the item (the app attaches it). The discount '
          'field of an item is only for a discount printed on the same line as the item. The '
          'top-level "discount" is the positive sum of discounts that are not printed '
          'as lines; null when none. The top-level "total" is the amount to pay.',
      '"count" is how many units were bought (1 when not printed). "grams" or '
          '"millilitres" is the size of ONE unit when printed (500 g, 1.5 l) as a '
          'whole number, or the weighed quantity when the product is sold by weight '
          '(with count 1); null otherwise.',
      '"currency" is the ISO 4217 code of the receipt; "date" is YYYY-MM-DD; "store" '
          'is the shop name; null when not printed.',
      if (known.isNotEmpty)
        'The shopping list has these products: ${known.join('; ')}. For an item that '
            'clearly is one of them set "match" to that exact name; otherwise null. '
            'Never invent a match: a wrong match is much worse than none, so when the '
            'printed text is abbreviated, garbled or you are not sure, "match" is null. '
            'Fill "evidence" first: the exact word or words copied from "raw" that name '
            'the product, and "meaning": their short reading in the language of the '
            'list ("jaja = яйця"); no evidence, no match. "confidence" is "high" only '
            'when the evidence names the product itself. Many products of the list are '
            'look-alikes of each other (flavours, sizes): pick one only when the '
            'printed text tells which.'
      else
        'The shopping list has no products yet: "match" is always null.',
      'For an item with no match set "name" to a short name for the shopping list: '
          '${known.isNotEmpty ? 'in the language and style of the products above' : 'in $language'}, '
          'singular, normal capitalisation (not ALL CAPS), without the percent, size, '
          'price or store code, keeping a brand only when it defines the product. '
          'Other lines have no "name" and no "match".',
    ].join(' ');
  }

  /// The reading in an answer, or null when the answer is not usable (not JSON, no
  /// lines). [knownNames] decide which `match` values stand: any other is dropped
  /// (the line becomes a new product), a valid one takes the catalog's own spelling.
  static ReceiptReading? parse(
    String text, {
    required List<String> knownNames,
    required String fallbackCurrency,
  }) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } catch (_) {
      return null;
    }
    if (json is! Map || json['lines'] is! List) return null;

    final currency = _currency(json['currency']) ?? fallbackCurrency;
    Money? money(Object? v) =>
        v is String || v is num ? parseMoney('$v', currency) : null;
    Money? positive(Object? v) {
      final m = money(v);
      return m?.copyWith(minor: m.minor.abs());
    }

    final lines = <ReceiptLine>[];
    for (final item in (json['lines'] as List).take(_maxLines)) {
      if (item is! Map) continue;
      final raw = item['raw'];
      if (raw is! String) continue;
      final printed = clip(raw.trim().replaceAll(RegExp(r'\s+'), ' '), 200);
      if (printed.isEmpty) continue;
      final kind = ReceiptLineKind.values.firstWhere(
        (k) => k.name == item['kind'],
        orElse: () => ReceiptLineKind.other,
      );
      final isItem = kind == ReceiptLineKind.item;

      String? match;
      if (isItem && item['match'] is String) {
        for (final n in knownNames) {
          if (ProductNames.same(n, item['match'] as String)) {
            match = n;
            break;
          }
        }
      }
      final highConfidence = match != null && item['confidence'] == 'high';
      final evidenceOk =
          match != null && _evidenceIn(item['evidence'], printed);
      final meaningRaw = item['meaning'];
      final meaning = match != null && meaningRaw is String
          ? clip(ProductNames.normalize(meaningRaw), 80)
          : '';
      String? name;
      if (isItem && match == null) {
        final proposed = item['name'] is String
            ? NameSuggestionRepository.cleanName(item['name'] as String)
            : '';
        name = proposed.isNotEmpty
            ? proposed
            : NameSuggestionRepository.cleanName(printed);
        if (name.isEmpty) name = null;
      }

      // The price on the mark is what was paid: printed price minus the line discount.
      // A discount larger than the price is a misreading: keep the price, drop it.
      var price = money(item['price']);
      var discount = positive(item['discount']);
      if (price != null && discount != null) {
        if (discount.minor <= price.minor) {
          price = price.copyWith(minor: price.minor - discount.minor);
        } else {
          discount = null;
        }
      }
      if (discount != null && discount.minor == 0) discount = null;

      // A discount line carries its amount in `price` (asked) or `discount` (models do
      // both); it is kept as a plain `discount` and placed below.
      if (kind == ReceiptLineKind.discount) {
        final amount = positive(item['price']) ?? positive(item['discount']);
        price = null;
        discount = amount == null || amount.minor == 0 ? null : amount;
      }

      lines.add(
        ReceiptLine(
          raw: printed,
          kind: kind,
          match: match,
          name: name,
          amount: isItem ? _amount(item) : Amount.none,
          price: price,
          discount: discount,
          // Only a candidate until `decideMatches` has weighed it.
          tier: match == null ? MatchTier.none : MatchTier.check,
          highConfidence: highConfidence,
          evidenceOk: evidenceOk,
          meaning: meaning.isEmpty ? null : meaning,
        ),
      );
    }
    if (lines.isEmpty) return null;

    // A discount line right under an item (or under another discount of it) is that
    // item's discount: its price becomes what was paid. Any other discount line, or one
    // larger than the item, belongs to the receipt as a whole.
    var sawDiscountLine = false;
    var unattached = 0;
    int? target;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.kind == ReceiptLineKind.item) {
        target = i;
      } else if (l.kind == ReceiptLineKind.discount) {
        sawDiscountLine = true;
        final amount = l.discount;
        if (amount == null) continue;
        final t = target;
        final item = t == null ? null : lines[t];
        if (item != null &&
            item.price != null &&
            amount.minor <= item.price!.minor) {
          lines[t!] = item.withMoney(
            price: item.price!.copyWith(
              minor: item.price!.minor - amount.minor,
            ),
            discount: item.discount == null
                ? amount
                : item.discount!.copyWith(
                    minor: item.discount!.minor + amount.minor,
                  ),
          );
        } else {
          unattached += amount.minor;
          target = null;
        }
      } else {
        target = null;
      }
    }

    final store = json['store'] is String
        ? ProductNames.normalize(json['store'] as String)
        : '';
    return ReceiptReading(
      lines: lines,
      store: store.isEmpty ? null : clip(store, 60),
      date: _date(json['date']),
      total: positive(json['total']),
      // With discount lines the app knows what no item owns; without any, the model's
      // own total of receipt-wide discounts stands.
      discount: sawDiscountLine
          ? (unattached > 0 ? Money(unattached, currency) : null)
          : positive(json['discount']),
    );
  }

  static String? _currency(Object? v) {
    if (v is! String) return null;
    final code = v.trim().toUpperCase();
    return RegExp(r'^[A-Z]{3}$').hasMatch(code) ? code : null;
  }

  static DateTime? _date(Object? v) {
    if (v is! String) return null;
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(v.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final date = DateTime(y, mo, d);
    // DateTime rolls 2026-02-31 over to March: reject what did not survive.
    if (date.year != y || date.month != mo || date.day != d) return null;
    return date;
  }

  static Amount _amount(Map item) {
    int? whole(Object? v) => v is num && v == v.toInt() ? v.toInt() : null;
    final count = whole(item['count']);
    return Amount.none.copyWith(
      count: count == null || count < 1 ? 1 : count,
      grams: whole(item['grams']),
      millilitres: whole(item['millilitres']),
    );
  }
}

final receiptParsingRepositoryProvider = Provider(
  (ref) => ReceiptParsingRepository(ref.watch(geminiClientProvider)),
);
