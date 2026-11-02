import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/purchase.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/history/history_days.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Purchase buy(String name, String user, DateTime at) =>
    Purchase(productName: name, userId: user, markedAt: at);

void main() {
  group('groupByDay', () {
    final now = DateTime.utc(2026, 11, 1, 12);
    test('Today, Yesterday, a date, a date with the year', () {
      final days = groupByDay(
        [
          buy('Milk', 'me', DateTime.utc(2026, 11, 1, 9)),
          buy('Tea', 'me', DateTime.utc(2026, 10, 31, 20)),
          buy('Jam', 'me', DateTime.utc(2026, 10, 28, 8)),
          buy('Oat', 'me', DateTime.utc(2025, 12, 30, 8)),
        ],
        Duration.zero,
        now,
      );
      expect(days.map((d) => d.label), [
        'Today',
        'Yesterday',
        'Wed, 28 Oct',
        'Tue, 30 Dec 2025',
      ]);
    });

    test('days follow the zone of the group, not UTC', () {
      // 23:30 UTC on 31 Oct is already 1 Nov at +3.
      final days = groupByDay(
        [buy('Milk', 'me', DateTime.utc(2026, 10, 31, 23, 30))],
        const Duration(hours: 3),
        now,
      );
      expect(days.single.label, 'Today');
      expect(
        timeLabel(DateTime.utc(2026, 10, 31, 23, 30), const Duration(hours: 3)),
        '02:30',
      );
    });

    test('purchases of one day stay together in order', () {
      final days = groupByDay(
        [
          buy('B', 'me', DateTime.utc(2026, 11, 1, 10)),
          buy('A', 'me', DateTime.utc(2026, 11, 1, 9)),
        ],
        Duration.zero,
        now,
      );
      expect(days.single.purchases.map((p) => p.productName), ['B', 'A']);
    });
  });

  test(
    'history holds sent and open marks, newest first, minus removed ones',
    () async {
      final lists = InMemoryListService(seed: false);
      final groups = GroupRepository(InMemoryGroupService(seed: false), lists);
      final g = (await groups.ensurePersonal('me') as Ok).value;
      final repo = ListRepository(lists, groups, groupId: g.id);
      final tea = ((await repo.addProduct('Tea', planned: true)) as Ok).value;
      final jam = ((await repo.addProduct('Jam', planned: true)) as Ok).value;
      await repo.toggleMark(tea.id, 'me');
      await repo.sendTrip('me');
      await repo.toggleMark(jam.id, 'me');
      var history = ((await repo.getHistory()) as Ok<List<Purchase>>).value;
      expect(history.map((p) => p.productName), ['Jam', 'Tea']);
      await repo.toggleMark(jam.id, 'me'); // taken back
      history = ((await repo.getHistory()) as Ok<List<Purchase>>).value;
      expect(history.map((p) => p.productName), ['Tea']);
    },
  );

  Future<void> openHistory(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
  }

  for (final shop in [false, true]) {
    testWidgets(
      'History sits above Settings in the menu on ${shop ? 'Shop' : 'Plan'}',
      (tester) async {
        await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
        await tester.pumpAndSettle();
        if (shop) {
          await tester.tap(find.byKey(const Key('tabShop')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('menuButton')));
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.text('History')).dy,
          lessThan(tester.getTopLeft(find.text('Settings')).dy),
        );
      },
    );
  }

  testWidgets(
    'debug data: days, my purchases bare, the partner\'s with a name',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
      await tester.pumpAndSettle();
      await openHistory(tester);
      expect(find.text('Yesterday'), findsOneWidget);
      // Seed trips alternate between me and the partner (Anna), five days back.
      expect(find.textContaining(RegExp(r'^Anna  \d\d:\d\d$')), findsWidgets);
      expect(find.textContaining(RegExp(r'^\d\d:\d\d$')), findsWidgets);
      expect(find.textContaining('Alex'), findsNothing);
    },
  );

  testWidgets('a mark of the open trip is in the history under Today', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await openHistory(tester);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Milk'), findsWidgets);
  });

  testWidgets('empty list: a short note', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inMemoryListServiceProvider.overrideWithValue(
            InMemoryListService(seed: false),
          ),
          inMemoryGroupServiceProvider.overrideWithValue(
            InMemoryGroupService(seed: false),
          ),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await openHistory(tester);
    expect(find.text('No purchases yet'), findsOneWidget);
  });
}
