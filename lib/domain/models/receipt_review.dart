import 'amount.dart';
import 'money.dart';
import 'product.dart';
import 'product_names.dart';
import 'receipt_reading.dart';

/// One row of the review screen: a product the receipt line(s) stand for. A row with a
/// [product] is a catalog product ("Found"); a row without one will be created ("New").
class ReviewRow {
  const ReviewRow({
    required this.id,
    this.product,
    required this.name,
    required this.proposed,
    required this.amount,
    this.price,
    this.discount,
    required this.raws,
    required this.checked,
    this.alreadyMine = false,
    this.partnerHas = false,
  });

  /// Stable inside one review (`r0`, `r1`, ...).
  final String id;

  /// The catalog product, null for a new one.
  final Product? product;

  /// The shown name: the product's own, or the proposed new name (editable).
  final String name;

  /// The name the model proposed for a new product; [ReceiptReview.pick] returns here
  /// when the user chooses "New product".
  final String proposed;

  final Amount amount;

  /// What was paid for the row (null = unknown), after line discounts; kept as read.
  final Money? price;
  final Money? discount;

  /// The printed lines behind the row, in receipt order (shown under the name when they
  /// differ from it).
  final List<String> raws;

  final bool checked;

  /// I already marked this product in my open trip: the receipt only attaches amount
  /// and price to that mark.
  final bool alreadyMine;

  /// The partner marked it: their mark is read-only, so the row is muted and disabled.
  final bool partnerHas;

  bool get isNew => product == null;
  bool get locked => partnerHas && !alreadyMine;

  ReviewRow copyWith({
    Product? product,
    bool clearProduct = false,
    String? name,
    Amount? amount,
    Money? price,
    Money? discount,
    bool clearPrice = false,
    bool clearDiscount = false,
    List<String>? raws,
    bool? checked,
    bool? alreadyMine,
    bool? partnerHas,
  }) => ReviewRow(
    id: id,
    product: clearProduct ? null : product ?? this.product,
    name: name ?? this.name,
    proposed: proposed,
    amount: amount ?? this.amount,
    price: clearPrice ? null : price ?? this.price,
    discount: clearDiscount ? null : discount ?? this.discount,
    raws: raws ?? this.raws,
    checked: checked ?? this.checked,
    alreadyMine: alreadyMine ?? this.alreadyMine,
    partnerHas: partnerHas ?? this.partnerHas,
  );
}

/// What the user reviews before "Mark N": the items of a [ReceiptReading] matched with
/// the catalog, merged by product, with the user's choices (checked, amount, new name).
/// Immutable: every change returns a new review. Nothing here writes anything.
///
/// Rules (receipt-design.md): a matched row starts checked, a new one unchecked (a
/// receipt holds things that must not enter the catalog); a product I already marked
/// stays checked; a product the partner marked is locked; two lines of one product are
/// one row; a new name equal to a catalog name turns the row into that product.
class ReceiptReview {
  const ReceiptReview({
    required this.rows,
    required this.products,
    required this.myMarkIds,
    required this.partnerMarkIds,
    this.skipped = 0,
    this.store,
    this.date,
    this.pricesMayBeWrong = false,
  });

  /// Builds the review. [products] are the ACTIVE products; [myMarkIds] and
  /// [partnerMarkIds] are the product ids marked in the open trips of the group.
  factory ReceiptReview.from(
    ReceiptReading reading, {
    required List<Product> products,
    required Set<String> myMarkIds,
    required Set<String> partnerMarkIds,
  }) {
    final byName = {
      for (final p in products) ProductNames.normalize(p.name).toLowerCase(): p,
    };
    var review = ReceiptReview(
      rows: const [],
      products: products,
      myMarkIds: myMarkIds,
      partnerMarkIds: partnerMarkIds,
      skipped: reading.lines
          .where((l) => l.kind != ReceiptLineKind.item)
          .length,
      store: reading.store,
      date: reading.date,
      pricesMayBeWrong: reading.linesMatchTotal == false,
    );
    var next = 0;
    for (final line in reading.items) {
      final product = line.match == null
          ? null
          : byName[ProductNames.normalize(line.match!).toLowerCase()];
      final name = product?.name ?? line.name ?? line.raw;
      final row = review._fresh(
        'r${next++}',
        product: product,
        name: name,
        proposed: line.name ?? line.raw,
        amount: line.amount,
        price: line.price,
        discount: line.discount,
        raws: [line.raw],
      );
      review = review._add(row);
    }
    return review;
  }

  final List<ReviewRow> rows;
  final List<Product> products;
  final Set<String> myMarkIds;
  final Set<String> partnerMarkIds;

  /// Lines that are not items (discounts, totals, VAT): shown only as a count.
  final int skipped;
  final String? store;
  final DateTime? date;

  /// The lines do not add up to the printed total: the screen says so without amounts.
  final bool pricesMayBeWrong;

  List<ReviewRow> get found => [
    for (final r in rows)
      if (!r.isNew) r,
  ];
  List<ReviewRow> get fresh => [
    for (final r in rows)
      if (r.isNew) r,
  ];

  /// Rows "Mark N" will act on: checked and not locked.
  List<ReviewRow> get chosen => [
    for (final r in rows)
      if (r.checked && !r.locked) r,
  ];

  int get checkedCount => chosen.length;

  ReviewRow? row(String id) {
    for (final r in rows) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ---- changes --------------------------------------------------------------------

  /// Check or uncheck a row; a locked row does not change.
  ReceiptReview toggle(String id) =>
      _replace(id, (r) => r.locked ? r : r.copyWith(checked: !r.checked));

  /// Check or uncheck every unlocked New row (the select-all icon of the New card).
  ReceiptReview setAllNew(bool checked) => _copy([
    for (final r in rows)
      if (r.isNew && !r.locked) r.copyWith(checked: checked) else r,
  ]);

  ReceiptReview setAmount(String id, Amount amount) =>
      _replace(id, (r) => r.copyWith(amount: amount));

  /// Renames a NEW row. Empty text changes nothing. A name equal to a catalog product
  /// turns the row into that product (it moves to Found, checked); a name equal to
  /// another new row merges the two.
  ReceiptReview rename(String id, String raw) {
    final current = row(id);
    if (current == null || !current.isNew) return this;
    final name = ProductNames.normalize(raw);
    if (name.isEmpty) return this;
    final product = _productNamed(name);
    if (product != null) return pick(id, product);
    final twin = rows
        .where((r) => r.id != id && r.isNew && ProductNames.same(r.name, name))
        .firstOrNull;
    final renamed = current.copyWith(name: name);
    if (twin == null) return _replace(id, (_) => renamed);
    return _merge(twin, renamed);
  }

  /// Points a row at another catalog product, or at no product ([product] null: "New
  /// product", the row returns to its proposed name). When another row already holds
  /// that product the two merge.
  ReceiptReview pick(String id, Product? product) {
    final current = row(id);
    if (current == null) return this;
    if (product == null) {
      if (current.isNew) return this;
      final back = _stateFor(
        current.copyWith(clearProduct: true, name: current.proposed),
        checked: false,
      );
      final twin = rows
          .where(
            (r) =>
                r.id != id && r.isNew && ProductNames.same(r.name, back.name),
          )
          .firstOrNull;
      return twin == null ? _replace(id, (_) => back) : _merge(twin, back);
    }
    final moved = _stateFor(
      current.copyWith(product: product, name: product.name),
      checked: true,
    );
    final twin = rows
        .where((r) => r.id != id && r.product?.id == product.id)
        .firstOrNull;
    return twin == null ? _replace(id, (_) => moved) : _merge(twin, moved);
  }

  // ---- internals ------------------------------------------------------------------

  Product? _productNamed(String name) {
    for (final p in products) {
      if (ProductNames.same(p.name, name)) return p;
    }
    return null;
  }

  ReceiptReview _copy(List<ReviewRow> rows) => ReceiptReview(
    rows: rows,
    products: products,
    myMarkIds: myMarkIds,
    partnerMarkIds: partnerMarkIds,
    skipped: skipped,
    store: store,
    date: date,
    pricesMayBeWrong: pricesMayBeWrong,
  );

  ReceiptReview _replace(String id, ReviewRow Function(ReviewRow) change) =>
      _copy([for (final r in rows) r.id == id ? change(r) : r]);

  /// A row in its starting state for [product]: found rows start checked, new ones
  /// not; marks decide the rest.
  ReviewRow _fresh(
    String id, {
    Product? product,
    required String name,
    required String proposed,
    required Amount amount,
    Money? price,
    Money? discount,
    required List<String> raws,
  }) => _stateFor(
    ReviewRow(
      id: id,
      product: product,
      name: name,
      proposed: proposed,
      amount: amount,
      price: price,
      discount: discount,
      raws: raws,
      checked: false,
    ),
    checked: product != null,
  );

  /// Sets the mark flags and the checked state of a row that now stands for its
  /// product (or for a new one): mine = checked, the partner's = locked and unchecked.
  ReviewRow _stateFor(ReviewRow r, {required bool checked}) {
    final id = r.product?.id;
    final mine = id != null && myMarkIds.contains(id);
    final partner = id != null && partnerMarkIds.contains(id);
    return r.copyWith(
      alreadyMine: mine,
      partnerHas: partner,
      checked: mine ? true : (partner ? false : checked),
    );
  }

  /// Adds a row, merging it into a row of the same product (or the same new name).
  ReceiptReview _add(ReviewRow row) {
    final twin = rows
        .where(
          (r) => row.product != null
              ? r.product?.id == row.product!.id
              : r.isNew && ProductNames.same(r.name, row.name),
        )
        .firstOrNull;
    if (twin == null) return _copy([...rows, row]);
    return _merge(twin, row);
  }

  /// Merges [other] into [into] (which stays in the list in its place; [other] is
  /// removed, whether or not it is already in the list).
  ReceiptReview _merge(ReviewRow into, ReviewRow other) {
    final price = _sumPrice(into.price, other.price);
    final discount = _sumDiscount(into.discount, other.discount);
    final merged = into.copyWith(
      amount: mergeAmounts(into.amount, other.amount),
      price: price,
      clearPrice: price == null,
      discount: discount,
      clearDiscount: discount == null,
      raws: [...into.raws, ...other.raws],
      checked: into.checked || other.checked,
    );
    return _copy([
      for (final r in rows)
        if (r.id == other.id)
          ...const <ReviewRow>[]
        else if (r.id == into.id)
          merged
        else
          r,
    ]);
  }

  /// Two lines of one product: the same size of one unit adds the counts (2 x 500 ml
  /// and 1 x 500 ml are 3 x 500 ml); two weighed lines (count 1, one measure) add the
  /// weights; anything else keeps the first size and adds the counts (assumption: a
  /// receipt rarely shows one product in two different sizes).
  static Amount mergeAmounts(Amount a, Amount b) {
    if (a.grams == b.grams && a.millilitres == b.millilitres) {
      return a.copyWith(count: a.count + b.count);
    }
    final weighed =
        a.count == 1 &&
        b.count == 1 &&
        ((a.grams != null &&
                b.grams != null &&
                a.millilitres == null &&
                b.millilitres == null) ||
            (a.millilitres != null &&
                b.millilitres != null &&
                a.grams == null &&
                b.grams == null));
    if (weighed) {
      return a.grams != null
          ? a.copyWith(grams: a.grams! + b.grams!)
          : a.copyWith(millilitres: a.millilitres! + b.millilitres!);
    }
    return a.copyWith(count: a.count + b.count);
  }

  /// An unknown price stays unknown: nothing is added as 0.
  static Money? _sumPrice(Money? a, Money? b) =>
      a == null || b == null ? null : a.copyWith(minor: a.minor + b.minor);

  /// No discount printed is no discount: only what is known is added.
  static Money? _sumDiscount(Money? a, Money? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.copyWith(minor: a.minor + b.minor);
  }
}
