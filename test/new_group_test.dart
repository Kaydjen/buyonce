import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/widgets/product_row.dart';
import 'package:buyonce/presentation/view_models/session/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'add_products_test.dart' show draft, openAdd;
import 'widget_test.dart'
    show goPlan, goShop, inToBuy, pumpApp, rowNamed, typeInField;

Future<void> switchTo(WidgetTester tester, String label) async {
  await tester.longPress(find.byKey(const Key('groupButton')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Anna adds three products in Plan, then Alex is back.
Future<void> annaAddsThree(WidgetTester tester) async {
  await switchTo(tester, 'Anna');
  await openAdd(tester);
  for (final name in ['Pears', 'Plums', 'Honey']) {
    await draft(tester, name);
  }
  await tester.tap(find.byKey(const Key('addCommit')));
  await tester.pumpAndSettle();
  await switchTo(tester, 'Alex');
}

Finder inNew(String name) => find.descendant(
  of: find.byKey(const Key('newGroup')),
  matching: find.text(name),
);

void main() {
  testWidgets('what another member added is one New group on top of Plan', (
    tester,
  ) async {
    await pumpApp(tester);
    await annaAddsThree(tester);

    expect(find.text('NEW · ANNA'), findsOneWidget);
    for (final name in ['Pears', 'Plums', 'Honey']) {
      expect(inNew(name), findsOneWidget);
    }
    expect(inNew('Milk'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('newGroup'))).dy,
      lessThan(tester.getTopLeft(rowNamed('Milk')).dy),
    );
  });

  testWidgets('in Shop there is no group: new rows name their author', (
    tester,
  ) async {
    await pumpApp(tester);
    await annaAddsThree(tester);
    await goShop(tester);

    expect(find.byKey(const Key('newGroup')), findsNothing);
    expect(find.text('NEW · ANNA'), findsNothing);
    for (final name in ['Pears', 'Plums', 'Honey']) {
      expect(inToBuy(name), findsOneWidget);
      expect(
        find.descendant(
          of: find.ancestor(
            of: inToBuy(name),
            matching: find.byType(ProductRow),
          ),
          matching: find.byKey(const Key('addedBy')),
        ),
        findsOneWidget,
      );
    }
    // Three new products, so three author lines and none on the older rows.
    expect(find.byKey(const Key('addedBy')), findsNWidgets(3));
    expect(find.text('Anna'), findsNWidgets(3));
  });

  testWidgets('Mark all takes the New products too', (tester) async {
    await pumpApp(tester);
    await annaAddsThree(tester);
    await goShop(tester);

    await tester.tap(find.byKey(const Key('markAll')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('markAll')), findsNothing);
    expect(find.text('Send 7'), findsOneWidget);
  });

  testWidgets('marking a new product in Shop keeps its author line', (
    tester,
  ) async {
    await pumpApp(tester);
    await annaAddsThree(tester);
    await goShop(tester);
    await tester.tap(rowNamed('Plums'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('addedBy')), findsNWidgets(3));
    expect(find.byKey(const Key('sendButton')), findsOneWidget);
  });

  testWidgets('a new session puts the products back in their places', (
    tester,
  ) async {
    await pumpApp(tester);
    await annaAddsThree(tester);
    expect(find.byKey(const Key('newGroup')), findsOneWidget);

    await ProviderScope.containerOf(tester.element(find.byType(Scaffold)))
        .read(listViewModelProvider.notifier)
        .startNewVisit(DateTime.now());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('newGroup')), findsNothing);
    expect(find.text('NEW · ANNA'), findsNothing);
    expect(rowNamed('Pears'), findsOneWidget);
  });

  testWidgets('my own additions and the first visit have no New group', (
    tester,
  ) async {
    await pumpApp(tester);
    await openAdd(tester);
    await draft(tester, 'Pears');
    await tester.tap(find.byKey(const Key('addCommit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newGroup')), findsNothing);

    // Anna has no earlier session in this group: Alex's addition is not new for her.
    await switchTo(tester, 'Anna');
    expect(find.byKey(const Key('newGroup')), findsNothing);
  });

  testWidgets('searching dissolves the group into flat results', (
    tester,
  ) async {
    await pumpApp(tester);
    await annaAddsThree(tester);
    await typeInField(tester, 'P');
    expect(find.byKey(const Key('newGroup')), findsNothing);
    expect(rowNamed('Pears'), findsOneWidget);
    await typeInField(tester, '');
    expect(find.byKey(const Key('newGroup')), findsOneWidget);
  });

  testWidgets('an un-planned New product leaves the group', (tester) async {
    await pumpApp(tester);
    await annaAddsThree(tester);
    await tester.tap(rowNamed('Honey'));
    await tester.pumpAndSettle();
    expect(inNew('Honey'), findsNothing);
    expect(inNew('Pears'), findsOneWidget);
    await goShop(tester);
    await goPlan(tester);
    expect(inNew('Pears'), findsOneWidget);
  });

  test(
    'VisitTracker: baseline is the end of the last session that saw the group',
    () {
      final tracker = VisitTracker();
      final t0 = DateTime(2026, 1, 1, 10);
      final t1 = DateTime(2026, 1, 1, 12);
      expect(tracker.enter('home', 'me'), isNull);
      expect(tracker.enter('home', 'me'), isNull);
      // Another group is not opened in this session.
      tracker.end('me', t0);
      expect(tracker.enter('home', 'me'), t0);
      expect(tracker.enter('home', 'me'), t0);
      tracker.end('me', t1);
      // A session without looking at home changes nothing for it.
      expect(tracker.enter('work', 'me'), isNull);
      tracker.end('me', DateTime(2026, 1, 1, 14));
      expect(tracker.enter('home', 'me'), t1);
      // Another user has sessions of their own.
      expect(tracker.enter('home', 'anna'), isNull);
    },
  );
}
