import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/local_list_merger.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/list_snapshot.dart';
import 'package:buyonce/data/services/local_list_store.dart';
import 'package:buyonce/data/services/settings_service.dart';
import 'package:buyonce/domain/models/plan.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:buyonce/domain/models/trip_mark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _local = 'personal-me';
const _cloud = 'personal-uid-1';

Product _p(String id, String name, double pos, {bool planned = false}) =>
    Product(
      id: id,
      groupId: _local,
      name: name,
      position: pos,
      planned: planned,
      plannedBy: planned ? 'me' : null,
      plannedAt: planned ? DateTime(2026, 11, 3, 10) : null,
    );

Future<InMemoryListService> _filled() async {
  final s = InMemoryListService(seed: false);
  await s.createProduct(_p('a', 'Milk', 1, planned: true));
  await s.createProduct(_p('b', 'Bread', 2));
  await s.createPlan(
    Plan(
      id: 'pl',
      groupId: _local,
      productIds: const ['a'],
      createdAt: DateTime(2026, 11, 2),
      pinned: true,
    ),
  );
  await s.createTrip(
    Trip(
      id: 't',
      groupId: _local,
      userId: 'me',
      startedAt: DateTime(2026, 11, 3, 9),
      marks: [
        TripMark(
          productId: 'b',
          userId: 'me',
          markedAt: DateTime(2026, 11, 3, 9, 5),
        ),
      ],
    ),
  );
  return s;
}

void main() {
  test('a snapshot survives JSON and rejects damaged data', () async {
    final source = await _filled();
    final json = source.snapshotOf(_local).toJson();
    final copy = ListSnapshot.tryParse(json)!;
    expect(
      copy.products.map((p) => p.name),
      unorderedEquals(['Milk', 'Bread']),
    );
    expect(copy.products.firstWhere((p) => p.id == 'a').planned, isTrue);
    expect(copy.plans.single.pinned, isTrue);
    expect(copy.trips.single.marks.single.productId, 'b');
    expect(copy.trips.single.isOpen, isTrue);
    expect(ListSnapshot.tryParse({'products': 5}), isNull);
    expect(ListSnapshot.tryParse(null), isNull);
  });

  test('the store saves changes and a new start restores them', () async {
    final storage = SettingsService();
    final first = InMemoryListService(seed: false);
    final store = LocalListStore(storage, delay: Duration.zero);
    await store.attach(first, _local);
    await first.createProduct(_p('a', 'Milk', 1));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final second = InMemoryListService(seed: false);
    await LocalListStore(storage).attach(second, _local);
    final products =
        (await second.getProducts(_local) as Ok<List<Product>>).value;
    expect(products.single.name, 'Milk');
    store.dispose();
  });

  test('damaged saved data is dropped', () async {
    SharedPreferences.setMockInitialValues({'localList': '{not json'});
    final service = InMemoryListService(seed: false);
    await LocalListStore(SettingsService()).attach(service, _local);
    expect(service.snapshotOf(_local).isEmpty, isTrue);
  });

  group('merge into the account', () {
    test(
      'adds the missing products by name and clears the local copy',
      () async {
        final local = await _filled();
        final cloud = InMemoryListService(seed: false);
        await cloud.createProduct(
          Product(id: 'x', groupId: _cloud, name: ' milk ', position: 5),
        );
        final merger = LocalListMerger(local: local, cloud: cloud);

        expect(await merger.merge('uid-1'), isA<Ok<bool>>());

        final products =
            ((await cloud.getProducts(_cloud)) as Ok<List<Product>>).value
              ..sort(byPosition);
        expect(products.map((p) => p.name), [' milk ', 'Bread']);
        expect(products.last.position, 6); // below the existing ones
        expect(local.snapshotOf(_local).isEmpty, isTrue);
      },
    );

    test('a planned product stays needed, owned by the account', () async {
      final local = await _filled();
      final cloud = InMemoryListService(seed: false);
      await LocalListMerger(local: local, cloud: cloud).merge('uid-1');
      final milk = ((await cloud.getProducts(_cloud)) as Ok<List<Product>>)
          .value
          .firstWhere((p) => p.name == 'Milk');
      expect(milk.planned, isTrue);
      expect(milk.plannedBy, 'uid-1');
    });

    test(
      'an empty local list does nothing; a second run adds nothing',
      () async {
        final local = InMemoryListService(seed: false);
        final cloud = InMemoryListService(seed: false);
        final merger = LocalListMerger(local: local, cloud: cloud);
        expect((await merger.merge('uid-1') as Ok<bool>).value, isFalse);

        final filled = await _filled();
        final again = LocalListMerger(local: filled, cloud: cloud);
        await again.merge('uid-1');
        await again.merge('uid-1');
        expect(
          ((await cloud.getProducts(_cloud)) as Ok<List<Product>>).value,
          hasLength(2),
        );
      },
    );

    test('a failed read keeps the local copy for the next try', () async {
      final local = await _filled();
      final merger = LocalListMerger(local: local, cloud: _Broken());
      expect(await merger.merge('uid-1'), isA<Failure<bool>>());
      expect(local.snapshotOf(_local).products, hasLength(2));
    });
  });
}

class _Broken extends InMemoryListService {
  _Broken() : super(seed: false);
  @override
  Future<Result<List<Product>>> getProducts(String groupId) async =>
      const Failure('offline');
}
