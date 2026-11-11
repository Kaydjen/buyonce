/// How much of a product: a count and/or the size of one unit (weight, volume).
///
/// Integers only, no floats: grams and millilitres. The measure is the size of ONE
/// unit, so 2 x 1.5 l is `count: 2, millilitres: 1500`; a weighed item is count 1 and
/// its weight. The data fields are independent (both can be set), the UI shows one
/// measure per product.
class Amount {
  const Amount({this.count = 1, this.grams, this.millilitres})
    : assert(count >= 1),
      assert(grams == null || grams > 0),
      assert(millilitres == null || millilitres > 0);

  /// Nothing set: a count of 1 and no measure. Rows show nothing for it.
  static const none = Amount();

  /// Biggest values the editor offers; one place for the limits (the rules do not see
  /// inside the map).
  static const maxCount = 99;
  static const maxGrams = 99999;
  static const maxMillilitres = 99999;

  final int count;
  final int? grams;
  final int? millilitres;

  bool get isNone => count == 1 && grams == null && millilitres == null;

  /// A copy; a null measure argument keeps it, [clearGrams]/[clearMillilitres] remove it.
  /// Values are brought into range (count 1..[maxCount]); a measure of 0 or less is
  /// removed.
  Amount copyWith({
    int? count,
    int? grams,
    int? millilitres,
    bool clearGrams = false,
    bool clearMillilitres = false,
  }) {
    final g = clearGrams ? null : grams ?? this.grams;
    final ml = clearMillilitres ? null : millilitres ?? this.millilitres;
    return Amount(
      count: (count ?? this.count).clamp(1, maxCount),
      grams: g == null || g <= 0 ? null : g.clamp(1, maxGrams),
      millilitres: ml == null || ml <= 0 ? null : ml.clamp(1, maxMillilitres),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Amount &&
      other.count == count &&
      other.grams == grams &&
      other.millilitres == millilitres;

  @override
  int get hashCode => Object.hash(count, grams, millilitres);

  @override
  String toString() => 'Amount(x$count, ${grams}g, ${millilitres}ml)';
}
