import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/domain/models/amount.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/domain/models/money.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/receipt.dart';
import 'package:buyonce/domain/models/receipt_reading.dart';
import 'package:buyonce/domain/models/receipt_review.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:buyonce/domain/models/trip_mark.dart';
import 'package:flutter_test/flutter_test.dart';

late InMemoryListService lists;

ListRepository newRepo() {
  lists = InMemoryListService();
  return ListRepository(
    lists,
    GroupRepository(InMemoryGroupService(), lists),
    groupId: defaultGroupId,
  );
}

Future<List<Product>> products(ListRepository repo) async =>
    ((await repo.getProducts()) as Ok<List<Product>>).value;

Future<List<Trip>> openTrips() async =>
    ((await lists.getOpenTrips(defaultGroupId)) as Ok<List<Trip>>).value;

ReceiptLine item(
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

ReceiptReview review(
  ReceiptReading reading,
  List<Product> all, {
  Set<String> mine = const {},
  Set<String> partner = const {},
  bool checkNew = true,
}) {
  var r = ReceiptReview.from(
    reading,
    products: all,
    myMarkIds: mine,
    partnerMarkIds: partner,
  );
  if (checkNew) r = r.setAllNew(true);
  return r;
}

void main() {
  test(
    'found and new rows become my marks in one trip with the receipt',
    () async {
      final repo = newRepo();
      final all = await products(repo);
      final milk = all.firstWhere((p) => p.name == 'Milk');
      final r = review(
        ReceiptReading(
          store: 'Auchan',
          date: DateTime(2025, 11, 17),
          total: const Money(3500, 'PLN'),
          lines: [
            item(
              'MLEKO',
              match: 'Milk',
              amount: const Amount(count: 2, millilitres: 1000),
              price: 700,
            ),
            item('KOMIN', name: 'Komin', price: 2800, discount: 300),
          ],
        ),
        all,
      );
      final n = await repo.applyReceipt(r.chosen, r.receipt, 'me');
      expect((n as Ok<int>).value, 2);

      final after = await products(repo);
      final komin = after.firstWhere((p) => p.name == 'Komin');
      expect(komin.planned, isFalse); // a new product is not planned
      expect(after.first.id, komin.id); // on top

      final trip = (await openTrips()).single;
      expect(trip.userId, 'me');
      final markMilk = trip.marks.firstWhere((m) => m.productId == milk.id);
      expect(markMilk.amount, const Amount(count: 2, millilitres: 1000));
      expect(markMilk.price, const Money(700, 'PLN'));
      final markKomin = trip.marks.firstWhere((m) => m.productId == komin.id);
      expect(markKomin.price, const Money(2800, 'PLN'));
      expect(markKomin.discount, const Money(300, 'PLN'));
      expect(trip.receipts.single.store, 'Auchan');
      expect(trip.receipts.single.total, const Money(3500, 'PLN'));
    },
  );

  test(
    'an unchecked new row creates nothing; nothing chosen writes nothing',
    () async {
      final repo = newRepo();
      final all = await products(repo);
      final r = review(
        ReceiptReading(lines: [item('KOMIN', name: 'Komin')]),
        all,
        checkNew: false,
      );
      expect(r.chosen, isEmpty);
      final n = await repo.applyReceipt(r.chosen, r.receipt, 'me');
      expect((n as Ok<int>).value, 0);
      expect((await products(repo)).length, all.length);
      expect(await openTrips(), isEmpty);
    },
  );

  test('my own mark keeps its amount unless the receipt has one, and takes the price', () async {
    final repo = newRepo();
    final all = await products(repo);
    final milk = all.firstWhere((p) => p.name == 'Milk');
    await lists.createTrip(
      Trip(
        id: 't',
        groupId: defaultGroupId,
        userId: 'me',
        startedAt: DateTime(2026, 11, 11),
        marks: [
          TripMark(
            productId: milk.id,
            userId: 'me',
            markedAt: DateTime(2026, 11, 11),
            amount: const Amount(count: 3),
          ),
        ],
        receipts: [const Receipt(store: 'Older')],
      ),
    );
    final r = review(
      ReceiptReading(
        store: 'Auchan',
        lines: [item('MLEKO', match: 'Milk', price: 700)],
      ),
      all,
      mine: {milk.id},
    );
    await repo.applyReceipt(r.chosen, r.receipt, 'me');
    final trip = (await openTrips()).single;
    expect(trip.marks.single.amount, const Amount(count: 3));
    expect(trip.marks.single.price, const Money(700, 'PLN'));
    expect(trip.receipts.map((x) => x.store), ['Older', 'Auchan']);
  });

  test('a product the partner marked is skipped', () async {
    final repo = newRepo();
    final all = await products(repo);
    final milk = all.firstWhere((p) => p.name == 'Milk');
    final bread = all.firstWhere((p) => p.name == 'Bread');
    await lists.createTrip(
      Trip(
        id: 'tp',
        groupId: defaultGroupId,
        userId: 'partner',
        startedAt: DateTime(2026, 11, 11),
        marks: [
          TripMark(
            productId: milk.id,
            userId: 'partner',
            markedAt: DateTime(2026, 11, 11),
          ),
        ],
      ),
    );
    // The review was made before the partner marked milk: the write checks again.
    final r = review(
      ReceiptReading(
        lines: [
          item('MLEKO', match: 'Milk', price: 700),
          item('CHLEB', match: 'Bread', price: 400),
        ],
      ),
      all,
    );
    expect(r.chosen.length, 2);
    final n = await repo.applyReceipt(r.chosen, r.receipt, 'me');
    expect((n as Ok<int>).value, 1);
    final mine = (await openTrips()).firstWhere((t) => t.userId == 'me');
    expect(mine.marks.map((m) => m.productId), [bread.id]);
  });

  test('a product deleted meanwhile comes back by its name; a same-name product is reused', () async {
    final repo = newRepo();
    final all = await products(repo);
    final milk = all.firstWhere((p) => p.name == 'Milk');
    final bread = all.firstWhere((p) => p.name == 'Bread');
    final r = review(
      ReceiptReading(
        lines: [
          item('MLEKO', match: 'Milk'),
          item('X', name: 'bread'), // a new row named like an existing product
        ],
      ),
      all,
    );
    await repo.deleteProduct(milk, 'me');
    final n = await repo.applyReceipt(r.chosen, r.receipt, 'me');
    expect((n as Ok<int>).value, 2);
    final after = await products(repo);
    expect(
      after.where((p) => p.name == 'Milk').length,
      1,
    ); // restored, not doubled
    expect(after.where((p) => p.name.toLowerCase() == 'bread').length, 1);
    final ids = (await openTrips()).single.marks
        .map((m) => m.productId)
        .toSet();
    expect(ids, {milk.id, bread.id});
  });

  test('a receipt that told nothing leaves no record', () async {
    final repo = newRepo();
    final all = await products(repo);
    final r = review(
      ReceiptReading(lines: [item('MLEKO', match: 'Milk')]),
      all,
    );
    expect(r.receipt, isNull);
    await repo.applyReceipt(r.chosen, r.receipt, 'me');
    expect((await openTrips()).single.receipts, isEmpty);
  });
}
