import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/clip.dart';
import '../../domain/models/amount.dart';
import '../../domain/models/gemini_outcome.dart';
import '../../domain/models/money.dart';
import '../../domain/models/product_names.dart';
import '../../domain/models/receipt_reading.dart';
import 'gemini_client.dart';
import 'name_suggestion_repository.dart';

/// What the photos of a receipt gave: the reading, or the reason there is none.
sealed class ReceiptParsing {
  const ReceiptParsing();
}

final class ParsedReceipt extends ReceiptParsing {
  const ParsedReceipt(this.reading, this.model);
  final ReceiptReading reading;
  final String model;
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
            'match': {'type': 'STRING', 'nullable': true},
            'name': {'type': 'STRING', 'nullable': true},
            'count': {'type': 'INTEGER', 'nullable': true},
            'grams': {'type': 'INTEGER', 'nullable': true},
            'millilitres': {'type': 'INTEGER', 'nullable': true},
            'price': {'type': 'STRING', 'nullable': true},
            'discount': {'type': 'STRING', 'nullable': true},
          },
          'required': ['raw', 'kind'],
        },
      },
    },
    'required': ['lines'],
  };

  /// [photos] are JPEGs of the same receipt, in order (at most [maxPhotos]).
  /// [knownNames] are the names of the active products; [language] is the English name
  /// of the app language, used for new names when the catalog is empty;
  /// [fallbackCurrency] (ISO code) is used when the receipt shows none.
  Future<ReceiptParsing> read(
    List<Uint8List> photos, {
    required String language,
    required List<String> models,
    required List<String> knownNames,
    required String fallbackCurrency,
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
    final reading = parse(
      outcome.text,
      knownNames: knownNames,
      fallbackCurrency: fallbackCurrency,
    );
    if (reading == null) return const NoReceipt(GeminiFailed());
    return ParsedReceipt(reading, outcome.model);
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
            'is one of them set "match" to that exact name; otherwise null. Never '
            'invent a match.'
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
          lines[t!] = ReceiptLine(
            raw: item.raw,
            kind: item.kind,
            match: item.match,
            name: item.name,
            amount: item.amount,
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
