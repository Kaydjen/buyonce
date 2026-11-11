import 'amount.dart';
import 'money.dart';

/// What a receipt line is. Only [item] becomes a product; the rest is kept so that the
/// review screen can count what it skipped and the sum check can add the line up.
enum ReceiptLineKind { item, discount, fee, deposit, bag, total, other }

/// How far a match of a line with a catalog product can be trusted. Decided by the app
/// (`decideMatches`), never by the model alone: a wrong tick hides a real need and
/// nobody notices, so only a CONFIRMED match is ticked by itself.
enum MatchTier {
  /// Ticked: the user confirmed this printed text before, or two readers agree, the
  /// model quoted the printed words it relied on, and the product has no look-alike.
  confirmed,

  /// A candidate only: shown with the printed text, not ticked, the user decides.
  check,

  /// Nothing in the catalog fits.
  none,
}

/// One line of a receipt as the model read it, already cleaned by the app.
class ReceiptLine {
  const ReceiptLine({
    required this.raw,
    required this.kind,
    this.match,
    this.name,
    this.amount = Amount.none,
    this.price,
    this.discount,
    MatchTier? tier,
    this.highConfidence = false,
    this.evidenceOk = false,
    this.meaning,
    this.fromAlias = false,
  }) : _tier = tier; // ignore: prefer_initializing_formals

  /// The line as printed (trimmed, clipped).
  final String raw;
  final ReceiptLineKind kind;

  /// The exact name of a catalog product this line is, or null: it is a new product.
  /// Always one of the names the request carried, in the catalog's own spelling.
  final String? match;

  /// A proposed name for a new product (null for a matched line and for non-items).
  final String? name;

  /// Count and the size of ONE unit (step 66).
  final Amount amount;

  /// What was paid for the line after its own discount; null = not readable.
  final Money? price;

  /// What the line saved (>= 0); null = no discount printed for it.
  final Money? discount;

  final MatchTier? _tier;

  /// The trust in [match]. A line built without a tier counts as confirmed when it has
  /// a match (a hand-made reading), else none.
  MatchTier get tier =>
      _tier ?? (match == null ? MatchTier.none : MatchTier.confirmed);

  /// The reader said "high" for its match.
  final bool highConfidence;

  /// The words the reader quoted as its reason were really in the printed text.
  final bool evidenceOk;

  /// The reader's short reading of the printed text ("jaja = яйця"), shown beside a
  /// match so that it can be checked at a glance.
  final String? meaning;

  /// The match comes from a pair the user confirmed earlier.
  final bool fromAlias;

  ReceiptLine withMatch({
    required String? match,
    required MatchTier tier,
    bool fromAlias = false,
  }) => ReceiptLine(
    raw: raw,
    kind: kind,
    match: match,
    name: name,
    amount: amount,
    price: price,
    discount: discount,
    tier: tier,
    highConfidence: highConfidence,
    evidenceOk: evidenceOk,
    meaning: meaning,
    fromAlias: fromAlias,
  );

  ReceiptLine withMoney({required Money? price, required Money? discount}) =>
      ReceiptLine(
        raw: raw,
        kind: kind,
        match: match,
        name: name,
        amount: amount,
        price: price,
        discount: discount,
        tier: _tier,
        highConfidence: highConfidence,
        evidenceOk: evidenceOk,
        meaning: meaning,
        fromAlias: fromAlias,
      );

  /// The name the review shows: the catalog name, else the proposed one, else the raw
  /// text.
  String get label => match ?? name ?? raw;

  /// Counts toward the total of the receipt.
  bool get isCharged =>
      kind == ReceiptLineKind.item ||
      kind == ReceiptLineKind.fee ||
      kind == ReceiptLineKind.deposit ||
      kind == ReceiptLineKind.bag;
}

/// A whole receipt as read from one or more photos.
class ReceiptReading {
  const ReceiptReading({
    required this.lines,
    this.store,
    this.date,
    this.total,
    this.discount,
  });

  final List<ReceiptLine> lines;
  final String? store;
  final DateTime? date;

  /// The total printed on the receipt.
  final Money? total;

  /// Saved by the receipt as a whole (loyalty bonus), no line owns it.
  final Money? discount;

  ReceiptReading withLines(List<ReceiptLine> lines) => ReceiptReading(
    lines: lines,
    store: store,
    date: date,
    total: total,
    discount: discount,
  );

  /// The lines that can become products or marks, in receipt order.
  Iterable<ReceiptLine> get items =>
      lines.where((l) => l.kind == ReceiptLineKind.item);

  /// Do the lines add up to the printed total? Null when there is no total to check
  /// against; false when they differ or a charged line has no price (something was
  /// misread). Charged lines minus the receipt-level discount, exact to the minor unit.
  bool? get linesMatchTotal {
    final t = total;
    if (t == null) return null;
    final charged = lines.where((l) => l.isCharged).toList();
    if (charged.any((l) => l.price == null)) return false;
    var sum = 0;
    for (final l in charged) {
      final p = l.price!;
      if (p.currency != t.currency) return false;
      sum += p.minor;
    }
    final d = discount;
    if (d != null) {
      if (d.currency != t.currency) return false;
      sum -= d.minor;
    }
    return sum == t.minor;
  }
}
