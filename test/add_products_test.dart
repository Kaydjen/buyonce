import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show goPlan, needIn, pumpApp, rowNamed;

Future<void> openAdd(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('addProducts')));
  await tester.pumpAndSettle();
}

/// Types a name and presses Enter, like on the keyboard.
Future<void> draft(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(const Key('draftField')), name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Finder draftRow(String name) => find.byKey(ValueKey(name));

void main() {
  testWidgets('the Add button is in the Plan header only', (tester) async {
    await pumpApp(tester, plan: false);
    expect(find.byKey(const Key('addProducts')), findsNothing);
    await goPlan(tester);
    expect(find.byKey(const Key('addProducts')), findsOneWidget);
  });

  testWidgets('five products are added without leaving the keyboard', (
    tester,
  ) async {
    await pumpApp(tester);
    await openAdd(tester);
    expect(find.byKey(const Key('addCommit')).hitTestable(), findsNothing);
    for (final name in ['Pears', 'Plums', 'Honey', 'Salt', 'Oil']) {
      await draft(tester, name);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(draftRow(name), findsOneWidget);
    }
    expect(find.text('Add 5'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('draftField')))
          .controller!
          .text,
      '',
    );

    await tester.tap(find.byKey(const Key('addCommit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('draftField')), findsNothing);
    expect(find.text('Added: 5'), findsOneWidget);
    expect(find.text('9 to buy'), findsOneWidget);
    for (final name in ['Pears', 'Plums', 'Honey', 'Salt', 'Oil']) {
      expect(needIn(name), findsOneWidget);
    }
  });

  testWidgets('drafts keep the typed order, first name on top of the plan', (
    tester,
  ) async {
    await pumpApp(tester);
    await openAdd(tester);
    await draft(tester, 'Pears');
    await draft(tester, 'Plums');
    // Newest draft is right under the field.
    expect(
      tester.getTopLeft(draftRow('Plums')).dy,
      lessThan(tester.getTopLeft(draftRow('Pears')).dy),
    );
    await tester.tap(find.byKey(const Key('addCommit')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(rowNamed('Plums')).dy,
      lessThan(tester.getTopLeft(rowNamed('Pears')).dy),
    );
  });

  testWidgets('back keeps the drafts for the next opening', (tester) async {
    await pumpApp(tester);
    await openAdd(tester);
    await draft(tester, 'Pears');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Added: 1'), findsNothing);
    expect(rowNamed('Pears'), findsNothing);

    await openAdd(tester);
    expect(draftRow('Pears'), findsOneWidget);
    expect(find.text('Add 1'), findsOneWidget);
  });

  testWidgets('the same name merges, case-insensitive; remove drops a draft', (
    tester,
  ) async {
    await pumpApp(tester);
    await openAdd(tester);
    await draft(tester, 'Pears');
    await draft(tester, 'pears ');
    await draft(tester, 'Plums');
    expect(find.text('Add 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('remove-Plums')));
    await tester.pumpAndSettle();
    expect(draftRow('Plums'), findsNothing);
    expect(find.text('Add 1'), findsOneWidget);
  });

  testWidgets('a catalog name becomes needed, a planned one changes nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    final before = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    ).read(listViewModelProvider).requireValue.products.length;
    await openAdd(tester);
    await draft(tester, 'cheese');
    await draft(tester, 'MILK');
    await tester.tap(find.byKey(const Key('addCommit')));
    await tester.pumpAndSettle();
    // Only Cheese changed; Milk was needed already.
    expect(find.text('Added: 1'), findsOneWidget);
    expect(needIn('Cheese'), findsOneWidget);
    final state = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    ).read(listViewModelProvider).requireValue;
    expect(state.products.length, before);
  });

  testWidgets('a name typed without Enter goes along with Add', (tester) async {
    await pumpApp(tester);
    await openAdd(tester);
    await draft(tester, 'Pears');
    await tester.enterText(find.byKey(const Key('draftField')), 'Plums');
    await tester.pumpAndSettle();
    expect(find.text('Add 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('addCommit')));
    await tester.pumpAndSettle();
    expect(needIn('Pears'), findsOneWidget);
    expect(needIn('Plums'), findsOneWidget);
  });

  testWidgets('the repository creates no duplicates', (tester) async {
    await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    final repo = container.read(listRepositoryProvider);
    final before = (await repo.getProducts()).toString();
    expect(before, isNotEmpty);
    await repo.addProducts(['Pears', 'PEARS', ' pears'], 'me');
    final names = container
        .read(listViewModelProvider)
        .requireValue
        .products
        .map((p) => p.name.toLowerCase());
    // The view model state is not reloaded by a direct repository call.
    expect(names.where((n) => n == 'pears'), isEmpty);
    await container.read(listViewModelProvider.notifier).refresh();
    final after = container
        .read(listViewModelProvider)
        .requireValue
        .products
        .where((p) => p.name.toLowerCase() == 'pears');
    expect(after.length, 1);
  });
}
