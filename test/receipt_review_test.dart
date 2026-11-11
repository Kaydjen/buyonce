import 'package:buyonce/domain/models/amount.dart';
import 'package:buyonce/domain/models/money.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/receipt_reading.dart';
import 'package:buyonce/domain/models/receipt_review.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:buyonce/domain/models/trip_mark.dart';
import 'package:buyonce/presentation/view_models/list/list_state.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_review_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Product _p(String id, String name) =>
    Product(id: id, groupId: 'g', name: name, position: 1);

final _milk = _p('milk', 'Milk');
final _bread = _p('bread', 'Bread');
final _eggs = _p('eggs', 'Eggs');
final _products = [_milk, _bread, _eggs];

ReceiptLine _item(
  String raw, {
  String? match,
  String? name,
  Amount amount = Amount.none,
  int? price,
  int? discount,
}) => ReceiptLine(
  raw: raw,
  kind: ReceiptLineKind.item,
  match: match,
  name: name,
  amount: amount,
  price: price == null ? null : Money(price, 'PLN'),
  discount: discount == null ? null : Money(discount, 'PLN'),
);

ReceiptReview _review(
  List<ReceiptLine> lines, {
  Set<String> mine = const {},
  Set<String> partner = const {},
  List<ReceiptLine> others = const [],
}) => ReceiptReview.from(
  ReceiptReading(lines: [...lines, ...others], store: 'Auchan'),
  products: _products,
  myMarkIds: mine,
  partnerMarkIds: partner,
);

void main() {
  group('start', () {
    test(
      'matched rows start checked, new ones not; skipped lines are counted',
      () {
        final r = _review(
          [
            _item('MLEKO', match: 'Milk', price: 350),
            _item('SER', name: 'Cheese', price: 900),
          ],
          others: const [
            ReceiptLine(raw: 'SUMA', kind: ReceiptLineKind.total),
            ReceiptLine(raw: 'PTU', kind: ReceiptLineKind.other),
          ],
        );
        expect(r.found.single.product, _milk);
        expect(r.found.single.checked, isTrue);
        expect(r.found.single.price, const Money(350, 'PLN'));
        expect(r.fresh.single.name, 'Cheese');
        expect(r.fresh.single.checked, isFalse);
        expect(r.skipped, 2);
        expect(r.store, 'Auchan');
        expect(r.checkedCount, 1);
      },
    );

    test('a match to an unknown product (deleted since) becomes new', () {
      final r = _review([_item('X', match: 'Gone', name: 'Gone')]);
      expect(r.found, isEmpty);
      expect(r.fresh.single.name, 'Gone');
    });

    test('a bad total sets the prices warning', () {
      final r = ReceiptReview.from(
        ReceiptReading(
          lines: [_item('A', match: 'Milk', price: 100)],
          total: const Money(999, 'PLN'),
        ),
        products: _products,
        myMarkIds: const {},
        partnerMarkIds: const {},
      );
      expect(r.pricesMayBeWrong, isTrue);
      expect(
        _review([_item('A', match: 'Milk', price: 100)]).pricesMayBeWrong,
        isFalse,
      );
    });
  });

  group('marks', () {
    test('my own mark: checked and flagged, the receipt attaches to it', () {
      final r = _review([_item('M', match: 'Milk')], mine: {'milk'});
      expect(r.found.single.alreadyMine, isTrue);
      expect(r.found.single.checked, isTrue);
      expect(r.found.single.locked, isFalse);
    });

    test('the partner\'s mark: unchecked, locked, cannot be toggled', () {
      final r = _review([_item('M', match: 'Milk')], partner: {'milk'});
      final row = r.found.single;
      expect(row.locked, isTrue);
      expect(row.checked, isFalse);
      expect(r.toggle(row.id).found.single.checked, isFalse);
      expect(r.checkedCount, 0);
    });

    test('both marked: mine wins', () {
      final r = _review(
        [_item('M', match: 'Milk')],
        mine: {'milk'},
        partner: {'milk'},
      );
      expect(r.found.single.locked, isFalse);
      expect(r.found.single.checked, isTrue);
    });
  });

  group('merging', () {
    test(
      'two lines of one product are one row: counts, prices, discounts add',
      () {
        final r = _review([
          _item(
            'M1',
            match: 'Milk',
            amount: const Amount(count: 2, millilitres: 500),
            price: 700,
            discount: 100,
          ),
          _item(
            'M2',
            match: 'milk',
            amount: const Amount(millilitres: 500),
            price: 350,
          ),
        ]);
        final row = r.found.single;
        expect(row.amount, const Amount(count: 3, millilitres: 500));
        expect(row.price, const Money(1050, 'PLN'));
        expect(row.discount, const Money(100, 'PLN'));
        expect(row.raws, ['M1', 'M2']);
      },
    );

    test('an unknown price stays unknown after a merge', () {
      final r = _review([
        _item('A', match: 'Milk', price: 700),
        _item('B', match: 'Milk'),
      ]);
      expect(r.found.single.price, isNull);
    });

    test('two weighed lines add the weights; two plain lines count 2', () {
      expect(
        ReceiptReview.mergeAmounts(
          const Amount(grams: 300),
          const Amount(grams: 450),
        ),
        const Amount(grams: 750),
      );
      expect(
        ReceiptReview.mergeAmounts(Amount.none, Amount.none),
        const Amount(count: 2),
      );
      // Different sizes with counts: the first size stays, counts add (assumption).
      expect(
        ReceiptReview.mergeAmounts(
          const Amount(count: 2, millilitres: 500),
          const Amount(count: 1, millilitres: 1000),
        ),
        const Amount(count: 3, millilitres: 500),
      );
    });

    test('new lines with the same proposed name merge', () {
      final r = _review([
        _item('S1', name: 'Cheese', price: 100),
        _item('S2', name: 'cheese', price: 200),
      ]);
      expect(r.fresh.length, 1);
      expect(r.fresh.single.price, const Money(300, 'PLN'));
    });
  });

  group('choices', () {
    final base = _review([
      _item('MLEKO', match: 'Milk'),
      _item('SER', name: 'Cheese'),
      _item('JAJA', name: 'Eggz'),
    ]);

    test('toggle and select-all of New', () {
      final cheese = base.fresh.first.id;
      expect(base.toggle(cheese).fresh.first.checked, isTrue);
      expect(base.toggle(cheese).toggle(cheese).fresh.first.checked, isFalse);
      final all = base.setAllNew(true);
      expect(all.fresh.every((r) => r.checked), isTrue);
      expect(all.checkedCount, 3);
      expect(all.setAllNew(false).checkedCount, 1);
    });

    test('amount is set on a row', () {
      final id = base.found.single.id;
      expect(
        base.setAmount(id, const Amount(count: 3)).found.single.amount,
        const Amount(count: 3),
      );
    });

    test('renaming a new row to a catalog name moves it to Found, checked', () {
      final id = base.fresh.last.id;
      final r = base.rename(id, ' eggs ');
      expect(r.fresh.length, 1);
      expect(r.found.map((x) => x.product), [_milk, _eggs]);
      expect(r.found.last.checked, isTrue);
    });

    test(
      'renaming to another new name merges; plain rename and empty text',
      () {
        final id = base.fresh.last.id;
        expect(base.rename(id, 'Cheese').fresh.length, 1);
        expect(base.rename(id, 'Eggs 10').fresh.last.name, 'Eggs 10');
        expect(base.rename(id, '   '), same(base));
        // A found row is not renamed.
        expect(base.rename(base.found.single.id, 'x'), same(base));
      },
    );

    test('picking another product, merging into a row that has it', () {
      final id = base.found.single.id;
      final bread = base.pick(id, _bread);
      expect(bread.found.single.product, _bread);
      expect(bread.found.single.name, 'Bread');
      // Eggs is a new row; pick Milk for it: the two rows with Milk merge.
      final merged = base.pick(base.fresh.last.id, _milk);
      expect(merged.found.length, 1);
      expect(merged.found.single.raws, ['MLEKO', 'JAJA']);
    });

    test('picking "New product" returns to the proposed name, unchecked', () {
      final r = base.pick(base.found.single.id, null);
      expect(r.found, isEmpty);
      expect(r.fresh.first.name, 'MLEKO');
      expect(r.fresh.first.checked, isFalse);
    });

    test('picking a product the partner marked locks the row', () {
      final r = ReceiptReview.from(
        ReceiptReading(lines: [_item('SER', name: 'Cheese')]),
        products: _products,
        myMarkIds: const {},
        partnerMarkIds: const {'bread'},
      );
      final picked = r.pick(r.fresh.single.id, _bread);
      expect(picked.found.single.locked, isTrue);
      expect(picked.found.single.checked, isFalse);
      expect(picked.checkedCount, 0);
    });
  });

  group('view model', () {
    test(
      'begin reads the list, choices change the review, discard clears it',
      () async {
        final container = ProviderContainer(
          overrides: [listViewModelProvider.overrideWith(_FakeList.new)],
        );
        addTearDown(container.dispose);
        final vm = container.read(receiptReviewProvider.notifier);
        // Not loaded yet: nothing starts.
        expect(
          vm.begin(ReceiptReading(lines: [_item('M', match: 'Milk')])),
          isFalse,
        );
        expect(container.read(receiptReviewProvider), isNull);

        await container.read(listViewModelProvider.future);
        expect(
          vm.begin(
            ReceiptReading(
              lines: [
                _item('M', match: 'Milk'),
                _item('S', name: 'Cheese'),
              ],
            ),
          ),
          isTrue,
        );
        var review = container.read(receiptReviewProvider)!;
        expect(
          review.found.single.alreadyMine,
          isTrue,
        ); // the fake list has my mark on Milk
        expect(review.found.single.checked, isTrue);
        vm.toggle(review.fresh.single.id);
        review = container.read(receiptReviewProvider)!;
        expect(review.fresh.single.checked, isTrue);
        vm.setAllNew(false);
        vm.rename(
          container.read(receiptReviewProvider)!.fresh.single.id,
          'Bread',
        );
        review = container.read(receiptReviewProvider)!;
        expect(review.found.map((r) => r.product!.id), ['milk', 'bread']);
        vm.discard();
        expect(container.read(receiptReviewProvider), isNull);
        vm.toggle('r0'); // no review: nothing happens
        expect(container.read(receiptReviewProvider), isNull);
      },
    );
  });
}

class _FakeList extends ListViewModel {
  @override
  Future<ListState> build() async => ListState(
    products: _products,
    userId: 'me',
    trips: [
      Trip(
        id: 't',
        groupId: 'g',
        userId: 'me',
        startedAt: DateTime(2026, 11, 1),
        marks: [
          TripMark(
            productId: 'milk',
            userId: 'me',
            markedAt: DateTime(2026, 11, 1),
          ),
        ],
      ),
    ],
  );
}
