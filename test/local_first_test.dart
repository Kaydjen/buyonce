import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/group_repository.dart';
import 'package:buyonce/data/repositories/list_repository.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/list_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/group.dart';
import 'package:buyonce/domain/models/product.dart';
import 'package:buyonce/presentation/view_models/list/list_state.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show goShop, pumpApp;

ListRepository _repo(InMemoryListService service) =>
    ListRepository(service, GroupRepository(InMemoryGroupService(), service));

List<Product> _products(Result<List<Product>> r) =>
    (r as Ok<List<Product>>).value;

void main() {
  group('live lists', () {
    test('a new listener gets the current value, then every change', () async {
      final service = InMemoryListService();
      final repo = _repo(service);
      final seen = <int>[];
      final sub = repo.watchProducts().listen(
        (r) => seen.add(_products(r).length),
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen, [27], reason: 'the current value comes first');
      await repo.addProduct('Jam', planned: false);
      expect(seen, [27, 28], reason: 'a local write shows before any answer');
      await sub.cancel();
      await repo.addProduct('Honey', planned: false);
      expect(seen, [27, 28], reason: 'a cancelled listener hears nothing');
    });

    test(
      'a change in one group does not reach the listener of another',
      () async {
        final service = InMemoryListService();
        final seen = <int>[];
        final sub = _repo(service)
            .watchProducts()
            .listen((r) => seen.add(_products(r).length));
        await ListRepository(
          service,
          GroupRepository(InMemoryGroupService(), service),
          groupId: 'mom',
        ).addProduct('Jam', planned: false);
        expect(seen, [27]);
        await sub.cancel();
      },
    );

    test('products come in catalog order, ties by id', () async {
      final service = InMemoryListService(seed: false);
      for (final id in ['b', 'a']) {
        await service.updateProduct(
          Product(id: id, groupId: defaultGroupId, name: id, position: 1),
        );
      }
      final first = await _repo(service).watchProducts().first;
      expect(_products(first).map((p) => p.id), ['a', 'b']);
    });
  });

  group('writes never wait for the server', () {
    test('a refused write is taken back later and reported', () async {
      final service = InMemoryListService()
        ..failWrites = true
        ..ackDelay = const Duration(milliseconds: 20);
      final repo = _repo(service);
      final counts = <int>[];
      final sub = repo.watchProducts().listen(
        (r) => counts.add(_products(r).length),
      );
      final errors = <ListWriteError>[];
      final errorSub = repo.writeErrors.listen(errors.add);

      final saved = await repo.addProduct('Jam', planned: false);
      expect(
        saved,
        isA<Ok<Product>>(),
        reason: 'the call does not wait for the answer',
      );
      expect(counts, [27, 28]);
      expect(errors, isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(counts, [
        27,
        28,
        27,
      ], reason: 'the list shows the real data again');
      expect(errors, hasLength(1));
      await sub.cancel();
      await errorSub.cancel();
    });

    test('an offline service reports it and keeps taking writes', () async {
      final service = InMemoryListService();
      final repo = _repo(service);
      final states = <bool>[];
      final sub = repo.online.listen(states.add);
      service.setOnline(false);
      final saved = await repo.addProduct('Jam', planned: false);
      expect(saved, isA<Ok<Product>>());
      service.setOnline(true);
      expect(states, [true, false, true]);
      await sub.cancel();
    });
  });

  group('on the screen', () {
    testWidgets('a refused mark goes back and a toast says so', (tester) async {
      await pumpApp(tester, plan: false);
      await goShop(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final service = container.read(inMemoryListServiceProvider)
        ..failWrites = true
        ..ackDelay = const Duration(seconds: 1);
      ListState state() => container.read(listViewModelProvider).requireValue;

      final milk = state().products.firstWhere((p) => p.name == 'Milk');
      await container.read(listViewModelProvider.notifier).tap(milk);
      await tester.pump();
      expect(state().myMarkIds, contains(milk.id), reason: 'shown at once');
      expect(find.text("Couldn't save, try again"), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(state().myMarkIds, isEmpty, reason: 'back to the real data');
      expect(find.text("Couldn't save, try again"), findsOneWidget);
      expect(find.text('Failed to load'), findsNothing);
      service.failWrites = false;
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('the offline sign shows only while offline', (tester) async {
      await pumpApp(tester, plan: false);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      final service = container.read(inMemoryListServiceProvider);
      expect(find.byKey(const Key('offlineSign')), findsNothing);

      service.setOnline(false);
      await tester.pump();
      expect(find.byKey(const Key('offlineSign')), findsOneWidget);
      expect(find.byTooltip('Offline'), findsOneWidget);

      // A mark placed offline stays on screen.
      final vm = container.read(listViewModelProvider.notifier);
      final milk = container
          .read(listViewModelProvider)
          .requireValue
          .products
          .firstWhere((p) => p.name == 'Milk');
      await vm.tap(milk);
      await tester.pump();
      expect(
        container.read(listViewModelProvider).requireValue.myMarkIds,
        contains(milk.id),
      );

      service.setOnline(true);
      await tester.pump();
      expect(find.byKey(const Key('offlineSign')), findsNothing);
    });
  });
}
