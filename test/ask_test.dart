import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_products_test.dart' show draft, openAdd;
import 'groups_ui_test.dart' as groups;
import 'new_group_test.dart' show switchTo;
import 'widget_test.dart' show goShop, pumpApp, typeAndSubmit;

final askButton = find.byKey(const Key('askButton'));

Future<void> addDrafts(WidgetTester tester, List<String> names) async {
  await openAdd(tester);
  for (final name in names) {
    await draft(tester, name);
  }
  await tester.tap(find.byKey(const Key('addCommit')));
  await tester.pumpAndSettle();
}

/// Timestamps come from the device clock, which is coarse on Windows.
Future<void> tick(WidgetTester tester) => tester.runAsync(
  () => Future<void>.delayed(const Duration(milliseconds: 50)),
);

void main() {
  testWidgets('Ask N tells the other member what I need; then it is gone', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(askButton.hitTestable(), findsNothing);
    await addDrafts(tester, ['Pears', 'Plums']);
    expect(find.text('Notify 2'), findsOneWidget);

    await tester.tap(askButton);
    await tester.pumpAndSettle();
    expect(find.text('Notified 2'), findsOneWidget);
    expect(askButton.hitTestable(), findsNothing);

    await switchTo(tester, 'Anna');
    expect(find.textContaining('Alex needs: Plums, Pears'), findsOneWidget);
    // Anna added nothing herself.
    expect(askButton.hitTestable(), findsNothing);
    await switchTo(tester, 'Alex');
    expect(askButton.hitTestable(), findsNothing);
  });

  testWidgets('silent additions go along with a later Ask', (tester) async {
    await pumpApp(tester);
    await addDrafts(tester, ['Pears']);
    await tester.tap(askButton);
    await tester.pumpAndSettle();
    await tick(tester);

    await addDrafts(tester, ['Plums']);
    await addDrafts(tester, ['Honey']);
    expect(find.text('Notify 2'), findsOneWidget);
    await tester.tap(askButton);
    await tester.pumpAndSettle();

    await switchTo(tester, 'Anna');
    expect(find.text('Alex needs: Pears, Honey, Plums'), findsOneWidget);
  });

  testWidgets('a product somebody has already taken is not asked for', (
    tester,
  ) async {
    await pumpApp(tester);
    await addDrafts(tester, ['Pears', 'Plums']);
    await goShop(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('toBuyCard')),
        matching: find.text('Pears'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    expect(find.text('Notify 1'), findsOneWidget);
  });

  testWidgets('Ask is only in Plan and only for my additions', (tester) async {
    await pumpApp(tester);
    await addDrafts(tester, ['Pears']);
    expect(askButton.hitTestable(), findsOneWidget);
    await goShop(tester);
    await tester.pumpAndSettle();
    expect(askButton.hitTestable(), findsNothing);

    // The seeded needed products have no author: nothing to ask for.
    await switchTo(tester, 'Anna');
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    expect(askButton.hitTestable(), findsNothing);
  });

  testWidgets('no Ask in the personal list or in a one-member group', (
    tester,
  ) async {
    await groups.pumpApp(tester, seed: false);
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    await typeAndSubmit(tester, 'Tea');
    expect(find.text('Tea'), findsOneWidget);
    expect(askButton.hitTestable(), findsNothing);

    await groups.openSheet(tester);
    await groups.tapText(tester, 'New group');
    await groups.createGroup(tester, 'Cabin');
    await typeAndSubmit(tester, 'Jam');
    expect(find.text('Jam'), findsOneWidget);
    expect(askButton.hitTestable(), findsNothing);
  });
}
