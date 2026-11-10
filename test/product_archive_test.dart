import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/firebase_list_service.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/list_snapshot.dart';
import 'package:buyonce/domain/models/plan.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/purchase.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';

ListRepository newRepo() {
  final lists = InMemoryListService();
  return ListRepository(
    lists,
    GroupRepository(InMemoryGroupService(), lists),
    groupId: defaultGroupId,
  );
}

Future<List<Product>> active(ListRepository repo) async =>
    ((await repo.getProducts()) as Ok<List<Product>>).value;

Future<Product> named(ListRepository repo, String name) async =>
    (await active(repo)).firstWhere((p) => p.name == name);

Future<List<Product>> archive(ListRepository repo) async =>
    ((await repo.watchArchive().first) as Ok<List<Product>>).value;

void main() {
  group('Product', () {
    const base = Product(id: 'p', groupId: 'g', name: 'Milk', position: 1);

    test('deleting stamps the time, coming back clears it', () {
      final at = DateTime(2026, 11, 10);
      final gone = base.copyWith(deleted: true, deletedAt: at);
      expect(gone.deleted, isTrue);
      expect(gone.deletedAt, at);
      final back = gone.copyWith(deleted: false);
      expect(back.deleted, isFalse);
      expect(back.deletedAt, isNull);
      // Other changes keep the deleted state.
      expect(gone.copyWith(name: 'Oat milk').deletedAt, at);
    });
  });

  group('Firestore mapping', () {
    test(
      'a product without the flag is not deleted; a deleted one has its time',
      () {
        final live = productFromData('g', 'a', {'name': 'x', 'position': 1});
        expect(live.deleted, isFalse);
        expect(live.deletedAt, isNull);
        final gone = productFromData('g', 'b', {
          'name': 'x',
          'position': 1,
          'deleted': true,
        });
        expect(gone.deleted, isTrue);
      },
    );

    test('an update writes the deleted fields only when the state changes', () {
      const base = Product(id: 'p', groupId: 'g', name: 'Milk', position: 1);
      final deleting = productChange(
        base.copyWith(deleted: true, deletedAt: DateTime(2026)),
        wasPlanned: false,
        me: 'a',
      );
      expect(deleting['deleted'], isTrue);
      expect(deleting.containsKey('deletedAt'), isTrue);

      final stays = productChange(
        base.copyWith(
          deleted: true,
          deletedAt: DateTime(2026),
          name: 'Renamed',
        ),
        wasPlanned: false,
        wasDeleted: true,
        me: 'a',
      );
      expect(stays.keys, ['name', 'position', 'planned']);

      final restoring = productChange(
        base,
        wasPlanned: false,
        wasDeleted: true,
        me: 'a',
      );
      expect(restoring.containsKey('deleted'), isTrue);
      expect(restoring.containsKey('deletedAt'), isTrue);

      final plain = productChange(base, wasPlanned: false, me: 'a');
      expect(plain.keys, ['name', 'position', 'planned']);
    });
  });

  test(
    'the saved local list keeps the deleted state, an old save has none',
    () {
      final snapshot = ListSnapshot(
        products: [
          const Product(id: 'a', groupId: 'g', name: 'A', position: 1),
          Product(
            id: 'b',
            groupId: 'g',
            name: 'B',
            position: 2,
            deleted: true,
            deletedAt: DateTime.utc(2026, 11, 10, 8),
          ),
        ],
        plans: const [],
        trips: const [],
      );
      final back = ListSnapshot.tryParse(snapshot.toJson())!;
      expect(back.products[0].deleted, isFalse);
      expect(back.products[1].deleted, isTrue);
      expect(
        back.products[1].deletedAt!.toUtc(),
        DateTime.utc(2026, 11, 10, 8),
      );

      final json = snapshot.toJson();
      for (final p in json['products'] as List) {
        (p as Map).remove('deleted');
        p.remove('deletedAt');
      }
      expect(
        ListSnapshot.tryParse(json)!.products.every((p) => !p.deleted),
        isTrue,
      );
    },
  );

  group('ListRepository', () {
    test(
      'a deleted product leaves the lists and shows in the archive',
      () async {
        final repo = newRepo();
        final milk = await named(repo, 'Milk');
        await repo.deleteProduct(milk, 'me');
        expect((await active(repo)).any((p) => p.id == milk.id), isFalse);
        expect((await archive(repo)).map((p) => p.name), ['Milk']);
        expect((await archive(repo)).single.deletedAt, isNotNull);
      },
    );

    test('the archive lists the latest deleted first', () async {
      final repo = newRepo();
      final milk = await named(repo, 'Milk');
      final eggs = await named(repo, 'Eggs');
      await repo.deleteProduct(milk, 'me');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.deleteProduct(eggs, 'me');
      expect((await archive(repo)).map((p) => p.name), ['Eggs', 'Milk']);
    });

    test('deleting takes my mark away, a partner\'s mark stays', () async {
      final repo = newRepo();
      final milk = await named(repo, 'Milk');
      await repo.toggleMark(milk.id, 'me');
      await repo.toggleMark(milk.id, 'partner');
      await repo.deleteProduct(milk, 'me');
      final trips = ((await repo.getOpenTrips()) as Ok<List<Trip>>).value;
      final mine = trips.where((t) => t.userId == 'me');
      expect(mine.every((t) => t.marks.isEmpty), isTrue);
      final theirs = trips.firstWhere((t) => t.userId == 'partner');
      expect(theirs.marks.single.productId, milk.id);
    });

    test('a needed product stops being needed when deleted; Undo brings it back as it was', () async {
      final repo = newRepo();
      final need = (await active(repo)).firstWhere((p) => p.planned);
      await repo.deleteProduct(need, 'me');
      expect((await archive(repo)).single.planned, isFalse);
      await repo.undeleteProduct(need, 'me');
      final back = (await active(repo)).firstWhere((p) => p.id == need.id);
      expect(back.planned, isTrue);
      expect(back.deleted, isFalse);
      expect(await archive(repo), isEmpty);
    });

    test('rename changes only the name', () async {
      final repo = newRepo();
      final milk = await named(repo, 'Milk');
      await repo.renameProduct(milk, '  Oat   milk ');
      final renamed = (await active(repo)).firstWhere((p) => p.id == milk.id);
      expect(renamed.name, 'Oat milk');
      expect(renamed.position, milk.position);
      expect(renamed.usage, milk.usage);
    });

    test('Restore brings an archived product back not needed, on top, usage kept, new name', () async {
      final repo = newRepo();
      final milk = await named(repo, 'Milk');
      await repo.deleteProduct(milk, 'me');
      final archived = (await archive(repo)).single;
      await repo.restoreProduct(archived, 'Milk 1l');
      final all = await active(repo);
      expect(all.first.name, 'Milk 1l');
      expect(all.first.planned, isFalse);
      expect(all.first.usage, milk.usage);
      expect(all.first.deleted, isFalse);
      expect(await archive(repo), isEmpty);
    });

    test(
      'adding the name of a deleted product brings that product back',
      () async {
        final repo = newRepo();
        final milk = await named(repo, 'Milk');
        await repo.deleteProduct(milk, 'me');
        final added = await repo.addProduct(
          'milk',
          planned: true,
          userId: 'me',
        );
        final product = (added as Ok<Product>).value;
        expect(product.id, milk.id, reason: 'the same product, not a copy');
        expect(product.planned, isTrue);
        expect(product.usage, milk.usage);
        final all = ((await repo.getProducts()) as Ok<List<Product>>).value;
        expect(all.where((p) => p.name.toLowerCase() == 'milk').length, 1);
        expect(await archive(repo), isEmpty);
      },
    );

    test(
      'Add products brings back a deleted name and makes it needed',
      () async {
        final repo = newRepo();
        final milk = await named(repo, 'Milk');
        await repo.deleteProduct(milk, 'me');
        final changed = await repo.addProducts(['Milk', 'Pears'], 'me');
        expect((changed as Ok<int>).value, 2);
        final all = await active(repo);
        final back = all.firstWhere((p) => p.id == milk.id);
        expect(back.planned, isTrue);
        expect(all.take(2).map((p) => p.name).toSet(), {'Milk', 'Pears'});
      },
    );

    test('applying a plan skips a deleted product', () async {
      final repo = newRepo();
      final milk = await named(repo, 'Milk');
      final bread = await named(repo, 'Bread');
      await repo.deleteProduct(milk, 'me');
      await repo.applyPlan(
        Plan(
          id: 'pl',
          groupId: defaultGroupId,
          productIds: [milk.id, bread.id],
          createdAt: DateTime(2026),
        ),
        'me',
      );
      final all = await active(repo);
      expect(all.firstWhere((p) => p.id == bread.id).planned, isTrue);
      expect(all.any((p) => p.id == milk.id), isFalse);
      expect((await archive(repo)).single.planned, isFalse);
    });

    test('the history still names a deleted product', () async {
      final repo = newRepo();
      final milk = await named(repo, 'Milk');
      await repo.toggleMark(milk.id, 'partner');
      await repo.deleteProduct(milk, 'me'); // the partner's mark stays
      final history = ((await repo.getHistory()) as Ok<List<Purchase>>).value;
      expect(history.any((p) => p.productName == 'Milk'), isTrue);
    });
  });
}
