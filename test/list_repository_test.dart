import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/domain/models/plan.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/domain/models/sort_key.dart';
import 'package:buyonce/domain/models/trip.dart';
import 'package:flutter_test/flutter_test.dart';

/// A list repository over fresh seeded services; the group defaults to Home.
ListRepository newRepo([InMemoryListService? service, String? groupId]) {
  final lists = service ?? InMemoryListService();
  return ListRepository(
    lists,
    GroupRepository(InMemoryGroupService(), lists),
    groupId: groupId ?? defaultGroupId,
  );
}

Future<List<String>> names(ListRepository repo) async {
  final result = await repo.getProducts() as Ok<List<Product>>;
  return [for (final p in result.value) p.name];
}

void main() {
  test('sort by frequency puts the most bought first', () async {
    final repo = newRepo();
    await repo.sortBy(SortKey.frequency);
    final list = await names(repo);
    expect(list.take(3), ['Milk', 'Bread', 'Eggs']);
  });

  test(
    'sort by recent puts last trip first, unbought keep their order',
    () async {
      final repo = newRepo();
      await repo.sortBy(SortKey.recent);
      final list = await names(repo);
      expect(list.take(3).toSet(), {'Milk', 'Eggs', 'Bananas'});
      expect(list.indexOf('Buns') < list.indexOf('Salad'), isTrue);
    },
  );

  group('daily clearing of Bought', () {
    Future<List<Trip>> open(ListRepository repo) async =>
        ((await repo.getOpenTrips()) as Ok<List<Trip>>).value;

    test('a trip from a past day is sent and notifies the partner', () async {
      final repo = newRepo();
      await repo.toggleMark('seed0', 'me');
      expect(await open(repo), hasLength(1));
      await repo.sendStaleTrips(
        now: DateTime.now().add(const Duration(days: 2)),
      );
      expect(await open(repo), isEmpty);
      final notices = ((await repo.getNotices('partner')) as Ok).value as List;
      expect(notices, hasLength(1));
      // history stays: the frequency sort still counts the cleared trip
      await repo.sortBy(SortKey.frequency);
      expect((await names(repo)).take(2), ['Milk', 'Bread']);
    });

    test('a trip with a mark from today stays', () async {
      final repo = newRepo();
      await repo.toggleMark('seed0', 'me');
      await repo.sendStaleTrips();
      expect(await open(repo), hasLength(1));
    });

    test('the boundary follows the zone of the group', () async {
      // 22:00 UTC is already the next day at +3 (Home) but not yet at +7 minus 5 h.
      final now = DateTime.utc(2026, 10, 31, 22);
      final mark = DateTime.utc(2026, 10, 31, 19);
      expect(mark.isBefore(dayStart(now, const Duration(hours: 3))), isTrue);
      expect(mark.isBefore(dayStart(now, const Duration(hours: 7))), isFalse);
    });
  });

  test('new product goes to the end', () async {
    final repo = newRepo();
    await repo.addProduct('Nuts', planned: false);
    expect((await names(repo)).last, 'Nuts');
  });

  test('send saves the sent products as a plan, not the whole plan', () async {
    final repo = newRepo();
    Future<List<Plan>> plans() async =>
        ((await repo.getPlans()) as Ok<List<Plan>>).value;
    final before = (await plans()).length;
    final planned = ((await repo.getProducts()) as Ok<List<Product>>).value
        .where((p) => p.planned)
        .toList();
    final bought = planned.first;
    final other = planned.last;

    await repo.toggleMark(bought.id, 'me');
    await repo.toggleMark('seed2', 'me');
    await repo.sendTrip('me');
    final after = await plans();
    expect(after.length, before + 1);
    final saved = after.firstWhere(
      (p) =>
          p.productIds.toSet().containsAll([bought.id, 'seed2']) &&
          p.productIds.length == 2,
    );
    expect(saved.productIds, isNot(contains(other.id)));

    // The same products sent again only refresh the plan.
    await repo.setPlanned(bought, true);
    await repo.toggleMark(bought.id, 'me');
    await repo.toggleMark('seed2', 'me');
    await repo.sendTrip('me');
    expect((await plans()).length, before + 1);
  });

  test('every group sees only its own products, plans and trips', () async {
    final service = InMemoryListService();
    final home = newRepo(service);
    final other = newRepo(service, 'other');
    expect(await names(other), isEmpty);
    expect(((await other.getPlans()) as Ok<List<Plan>>).value, isEmpty);

    await other.addProduct('Nuts', planned: true);
    expect(await names(other), ['Nuts']);
    expect((await names(home)).contains('Nuts'), isFalse);

    final nuts =
        ((await other.getProducts()) as Ok<List<Product>>).value.single;
    await other.toggleMark(nuts.id, 'me');
    expect(
      ((await other.getOpenTrips()) as Ok<List<Trip>>).value,
      hasLength(1),
    );
    expect(((await home.getOpenTrips()) as Ok<List<Trip>>).value, isEmpty);

    await other.sendTrip('me');
    expect(((await other.getPlans()) as Ok<List<Plan>>).value.length, 1);
    expect(((await home.getPlans()) as Ok<List<Plan>>).value.length, 2);
  });

  test('trips are per user: a partner mark does not touch mine', () async {
    final repo = newRepo();
    Future<List<Trip>> open() async =>
        ((await repo.getOpenTrips()) as Ok<List<Trip>>).value;

    await repo.toggleMark('seed1', 'me');
    await repo.toggleMark('seed2', 'partner');
    final trips = await open();
    expect(trips, hasLength(2));
    expect(
      {
        for (final t in trips)
          t.userId: t.marks.map((m) => m.productId).toList(),
      },
      {
        'me': ['seed1'],
        'partner': ['seed2'],
      },
    );

    // Notify closes only my trip; the partner's marks stay open.
    expect(((await repo.sendTrip('me')) as Ok<int>).value, 1);
    final after = await open();
    expect(after.map((t) => t.userId), ['partner']);

    // A mark after Notify opens a new trip.
    await repo.toggleMark('seed3', 'me');
    expect(await open(), hasLength(2));

    // The same tap again removes my mark.
    await repo.toggleMark('seed3', 'me');
    expect((await open()).where((t) => t.userId == 'me').single.marks, isEmpty);
  });

  test('pinned plans come first', () async {
    final repo = newRepo();
    final plans = ((await repo.getPlans()) as Ok<List<Plan>>).value;
    expect(plans.first.pinned, isTrue);
    await repo.setPinned(plans.last, true);
    final after = ((await repo.getPlans()) as Ok<List<Plan>>).value;
    expect(after.where((p) => p.pinned).length, 2);
  });

  test('a deleted plan is gone and can be restored', () async {
    final repo = newRepo();
    Future<List<Plan>> plans() async =>
        ((await repo.getPlans()) as Ok<List<Plan>>).value;
    final all = await plans();
    final plan = all.last;
    await repo.deletePlan(plan);
    expect((await plans()).length, all.length - 1);
    await repo.restorePlan(plan);
    expect((await plans()).map((p) => p.id), contains(plan.id));
  });
}
