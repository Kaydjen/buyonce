import 'product_names.dart';
import 'receipt_reading.dart';

/// Letters with marks folded to plain ones, lower case, so that "ŁĄKA" and "laka" meet.
/// Only the alphabets the app meets (Polish, Ukrainian and Russian stay as they are,
/// they have no plain form to fold to).
String foldText(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    out.write(_folds[ch] ?? ch);
  }
  return out.toString();
}

const _folds = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'ß': 's',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ç': 'c',
  'ñ': 'n',
};

/// Words that tell nothing about a product on a receipt (units, tax letters).
const _noise = {'x', 'szt', 'kg', 'g', 'ml', 'l', 'pcs', 'шт', 'кг', 'г', 'мл'};

/// The printed text of a line without what changes between purchases (weights, prices,
/// numbers, tax letters), so that the same product prints to the same key: "JajaSciol M
/// 10szt C 1 x10,99 10,99C" and the same line a week later are one key.
String printedKey(String raw) {
  final words = foldText(raw)
      .replaceAll(RegExp(r'[0-9]+([.,][0-9]+)?'), ' ')
      .split(RegExp(r'[^a-zа-яіїєґ]+'))
      .where((w) => w.length > 1 && !_noise.contains(w))
      .toList();
  return words.join(' ');
}

List<String> _words(String name) => [
  for (final w in foldText(name).split(RegExp(r'[^a-zа-яіїєґ0-9]+')))
    if (w.isNotEmpty) w,
];

/// Two different catalog names that are about the same thing ("Serek homogenizowany
/// brzoskwiniowy" and "... waniliowy", "Молоко" and "Молоко безлактозне"): at least
/// half of their words are shared. A receipt line for one is easily taken for the other.
bool areLookAlikes(String a, String b) {
  if (ProductNames.same(a, b)) return false;
  final wa = _words(a).toSet();
  final wb = _words(b).toSet();
  if (wa.isEmpty || wb.isEmpty) return false;
  final common = wa.intersection(wb).length;
  return common > 0 && common / wa.union(wb).length >= 0.5;
}

/// The other catalog names that look like [name].
List<String> lookAlikesOf(String name, Iterable<String> catalog) => [
  for (final other in catalog)
    if (areLookAlikes(name, other)) other,
];

/// Does the printed line carry what tells [name] from its look-alikes? A word of the
/// name that none of them has must be in the line (its first 4-5 letters are enough,
/// receipts abbreviate: "BRZOSK" for "brzoskwiniowy").
bool tellsApart(String name, List<String> lookAlikes, String raw) {
  final others = {for (final o in lookAlikes) ..._words(o)};
  final own = [
    for (final w in _words(name))
      if (!others.contains(w) && w.length >= 3) w,
  ];
  if (own.isEmpty) return false;
  final line = foldText(raw);
  return own.any(
    (w) => line.contains(w.substring(0, w.length < 5 ? w.length : 5)),
  );
}

/// The final trust in every item line, decided by the app.
///
/// A line is CONFIRMED (ticked by itself) when the user confirmed this printed text
/// before (an alias), or when the reader and the second reader agree on the product, the
/// reader said "high" and quoted words that are really in the line, and the product has
/// no look-alike in the catalog that the line does not rule out. Everything else that
/// has a candidate is CHECK: shown, not ticked. If the second reader could not be asked
/// ([matcher] null), nothing but an alias is confirmed: failing safe means ticking less.
///
/// [aliases] maps a printed key ([printedKey]) to a catalog name; [matcher] maps a line
/// index in `reading.lines` to the second reader's product (null = it found none).
ReceiptReading decideMatches(
  ReceiptReading reading, {
  required List<String> knownNames,
  Map<String, String> aliases = const {},
  Map<int, String?>? matcher,
}) {
  final lines = [...reading.lines];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.kind != ReceiptLineKind.item) continue;

    final learned = aliases[printedKey(line.raw)];
    final known = learned == null
        ? null
        : knownNames.where((n) => ProductNames.same(n, learned)).firstOrNull;
    if (known != null) {
      lines[i] = line.withMatch(
        match: known,
        tier: MatchTier.confirmed,
        fromAlias: true,
      );
      continue;
    }

    final reader = line.match;
    final second = matcher?[i];
    if (reader == null) {
      // Only the second reader found something: a candidate, never ticked.
      lines[i] = second == null
          ? line.withMatch(match: null, tier: MatchTier.none)
          : line.withMatch(match: second, tier: MatchTier.check);
      continue;
    }
    final agree = second != null && ProductNames.same(second, reader);
    final twins = lookAlikesOf(reader, knownNames);
    final ruledOut = twins.isEmpty || tellsApart(reader, twins, line.raw);
    final sure = agree && line.highConfidence && line.evidenceOk && ruledOut;
    lines[i] = line.withMatch(
      match: reader,
      tier: sure ? MatchTier.confirmed : MatchTier.check,
    );
  }
  return reading.withLines(lines);
}
