import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/amount_codec.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/list_snapshot.dart';
import 'package:buyonce/domain/models/amount.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:buyonce/domain/models/trip_mark.dart';
import 'package:flutter_test/flutter_test.dart';

ListRepository newRepo() {
  final lists = InMemoryListService();
  return ListRepository(
    lists,
    GroupRepository(InMemoryGroupService(), lists),
    groupId: defaultGroupId,
  );
}

Future<Product> product(ListRepository repo, String name) async =>
    ((await repo.getProducts()) as Ok<List<Product>>).value.firstWhere(
      (p) => p.name == name,
    );

Future<Trip?> openTrip(ListRepository repo, String user) async =>
    ((await repo.getOpenTrips()) as Ok<List<Trip>>).value
        .where((t) => t.userId == user)
        .firstOrNull;

void main() {
  group('Amount', () {
    test('nothing set is none; a count above 1 or a measure is not', () {
      expect(Amount.none.isNone, isTrue);
      expect(const Amount(count: 2).isNone, isFalse);
      expect(const Amount(grams: 500).isNone, isFalse);
      expect(const Amount(millilitres: 1500).isNone, isFalse);
    });

    test('copyWith brings values into range and clears a measure', () {
      expect(Amount.none.copyWith(count: 0).count, 1);
      expect(Amount.none.copyWith(count: 1000).count, Amount.maxCount);
      expect(Amount.none.copyWith(grams: 0).grams, isNull);
      const full = Amount(count: 2, grams: 500, millilitres: 1500);
      expect(full.copyWith(clearGrams: true).grams, isNull);
      expect(full.copyWith(clearGrams: true).millilitres, 1500);
      expect(full.copyWith(clearMillilitres: true).grams, 500);
      expect(full.copyWith(count: 3).grams, 500);
    });

    test('equal values are equal', () {
      expect(
        const Amount(count: 2, grams: 5),
        const Amount(count: 2, grams: 5),
      );
      expect(const Amount(count: 2), isNot(const Amount(count: 3)));
    });

    test('the data form leaves defaults out and reads back', () {
      expect(amountToData(Amount.none), isEmpty);
      const a = Amount(count: 2, grams: 500, millilitres: 1500);
      expect(amountToData(a), {'count': 2, 'g': 500, 'ml': 1500});
      expect(amountFromData(amountToData(a)), a);
    });

    test('damaged data gives the defaults', () {
      expect(amountFromData(null), Amount.none);
      expect(amountFromData('x'), Amount.none);
      expect(amountFromData({'count': -4, 'g': 'a', 'ml': 1.5}), Amount.none);
    });
  });

  group('Product need', () {
    const base = Product(id: 'p', groupId: 'g', name: 'Milk', position: 1);

    test('lives only while planned', () {
      final planned = base.copyWith(
        planned: true,
        need: const Amount(count: 2),
      );
      expect(planned.need.count, 2);
      expect(planned.copyWith(name: 'Oat').need.count, 2);
      expect(planned.copyWith(planned: false).need, Amount.none);
      expect(base.copyWith(need: const Amount(count: 3)).need, Amount.none);
    });
  });

  group('Repository', () {
    test('an amount on an unplanned product plans it with that need', () async {
      final repo = newRepo();
      final bread = await product(repo, 'Bread');
      expect(bread.planned, isFalse);
      await repo.setAmount(bread, 'me', const Amount(count: 2));
      final after = await product(repo, 'Bread');
      expect(after.planned, isTrue);
      expect(after.plannedBy, 'me');
      expect(after.need.count, 2);
    });

    test('an amount on a planned product keeps who planned it', () async {
      final repo = newRepo();
      final bread = await product(repo, 'Bread');
      await repo.setPlanned(bread, true, 'partner');
      await repo.setAmount(
        await product(repo, 'Bread'),
        'me',
        const Amount(millilitres: 1500),
      );
      final after = await product(repo, 'Bread');
      expect(after.plannedBy, 'partner');
      expect(after.need.millilitres, 1500);
    });

    test(
      'a mark copies the need; the need changes later do not touch it',
      () async {
        final repo = newRepo();
        final bread = await product(repo, 'Bread');
        await repo.setAmount(bread, 'me', const Amount(count: 2, grams: 500));
        await repo.toggleMark(bread.id, 'me');
        var mark = (await openTrip(repo, 'me'))!.marks.single;
        expect(mark.amount, const Amount(count: 2, grams: 500));

        // The product is now marked: an amount edit changes the mark, not the need.
        await repo.setAmount(
          await product(repo, 'Bread'),
          'me',
          const Amount(count: 5),
        );
        mark = (await openTrip(repo, 'me'))!.marks.single;
        expect(mark.amount.count, 5);
        expect((await product(repo, 'Bread')).need.count, 2);
      },
    );

    test('a product without a need is marked with no amount', () async {
      final repo = newRepo();
      final bread = await product(repo, 'Bread');
      await repo.toggleMark(bread.id, 'me');
      expect((await openTrip(repo, 'me'))!.marks.single.amount, Amount.none);
    });

    test('Mark all copies each need', () async {
      final repo = newRepo();
      final bread = await product(repo, 'Bread');
      final eggs = await product(repo, 'Eggs');
      await repo.setAmount(bread, 'me', const Amount(count: 3));
      await repo.setMarks([bread.id, eggs.id], 'me', marked: true);
      final marks = (await openTrip(repo, 'me'))!.marks;
      expect(marks.firstWhere((m) => m.productId == bread.id).amount.count, 3);
      expect(
        marks.firstWhere((m) => m.productId == eggs.id).amount,
        Amount.none,
      );
    });

    test('un-planning and sending clear the need', () async {
      final repo = newRepo();
      final bread = await product(repo, 'Bread');
      final eggs = await product(repo, 'Eggs');
      await repo.setAmount(bread, 'me', const Amount(count: 2));
      await repo.setAmount(eggs, 'me', const Amount(count: 4));
      await repo.setPlanned(await product(repo, 'Bread'), false, 'me');
      expect((await product(repo, 'Bread')).need, Amount.none);

      await repo.toggleMark(eggs.id, 'me');
      await repo.sendTrip('me');
      final sent = await product(repo, 'Eggs');
      expect(sent.planned, isFalse);
      expect(sent.need, Amount.none);
    });

    test('the sent trip keeps the amounts of its marks', () async {
      final lists = InMemoryListService();
      final repo = ListRepository(
        lists,
        GroupRepository(InMemoryGroupService(), lists),
        groupId: defaultGroupId,
      );
      final eggs = await product(repo, 'Eggs');
      await repo.setAmount(eggs, 'me', const Amount(count: 4));
      await repo.toggleMark(eggs.id, 'me');
      await repo.sendTrip('me');
      final trips = ((await lists.getTrips(
        defaultGroupId,
        limit: 50,
      )) as Ok<List<Trip>>).value;
      expect(
        trips
            .where((t) => !t.isOpen)
            .expand((t) => t.marks)
            .any((m) => m.productId == eggs.id && m.amount.count == 4),
        isTrue,
      );
    });

    test('deleting and undoing keeps the need', () async {
      final repo = newRepo();
      final eggs = await product(repo, 'Eggs');
      await repo.setAmount(eggs, 'me', const Amount(count: 4));
      final original = await product(repo, 'Eggs');
      await repo.deleteProduct(original, 'me');
      await repo.undeleteProduct(original, 'me');
      expect((await product(repo, 'Eggs')).need.count, 4);
    });
  });

  group('Snapshot', () {
    test('needs and mark amounts round-trip; an old save reads as none', () {
      final snap = ListSnapshot(
        products: const [
          Product(
            id: 'a',
            groupId: 'g',
            name: 'Milk',
            position: 1,
            planned: true,
            need: Amount(count: 2, millilitres: 1500),
          ),
          Product(id: 'b', groupId: 'g', name: 'Tea', position: 2),
        ],
        plans: const [],
        trips: [
          Trip(
            id: 't',
            groupId: 'g',
            userId: 'me',
            startedAt: DateTime(2026, 11, 11),
            marks: [
              TripMark(
                productId: 'a',
                userId: 'me',
                markedAt: DateTime(2026, 11, 11),
                amount: const Amount(count: 2, millilitres: 1500),
              ),
            ],
          ),
        ],
      );
      final back = ListSnapshot.tryParse(snap.toJson())!;
      expect(
        back.products.first.need,
        const Amount(count: 2, millilitres: 1500),
      );
      expect(back.products.last.need, Amount.none);
      expect(
        back.trips.single.marks.single.amount,
        const Amount(count: 2, millilitres: 1500),
      );

      final json = snap.toJson();
      for (final p in json['products']! as List) {
        (p as Map).remove('need');
      }
      for (final t in json['trips']! as List) {
        for (final m in (t as Map)['marks'] as List) {
          (m as Map).remove('amount');
        }
      }
      final old = ListSnapshot.tryParse(json)!;
      expect(old.products.first.need, Amount.none);
      expect(old.trips.single.marks.single.amount, Amount.none);
    });
  });
}
