import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show openMenu, pumpApp, rowNamed;

Future<void> deleteRow(WidgetTester tester, String name) async {
  await tester.longPress(rowNamed(name));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('menuDelete')));
  await tester.pumpAndSettle();
}

Finder get field => find.descendant(
  of: find.byType(CardDialog),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('the menu has no Archive until something is deleted', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsNothing);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await deleteRow(tester, 'Bread');
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('Shop has no Archive item', (tester) async {
    await pumpApp(tester);
    await deleteRow(tester, 'Bread');
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('the archive lists the latest deleted first', (tester) async {
    await pumpApp(tester);
    await deleteRow(tester, 'Bread');
    await tester.pump(const Duration(milliseconds: 20));
    await deleteRow(tester, 'Eggs');
    await openMenu(tester, 'Archive');
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(find.text('Bread'), findsOneWidget);
    expect(top('Eggs') < top('Bread'), isTrue);
  });

  testWidgets(
    'a tap asks for the name; Restore brings the product to the top, not needed',
    (tester) async {
      await pumpApp(tester);
      await deleteRow(tester, 'Milk'); // a needed product
      await deleteRow(tester, 'Bread');
      await openMenu(tester, 'Archive');
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, 'Bread');

      await tester.enterText(field, 'Rye bread');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Restore'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDialog), findsNothing);
      // Still in the archive: Milk is left, Bread is gone from it.
      expect(find.text('Milk'), findsOneWidget);
      expect(find.text('Bread'), findsNothing);
      expect(find.text('Rye bread'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(rowNamed('Rye bread'), findsOneWidget);
      final first = tester.getTopLeft(find.byType(ListView).first).dy;
      expect(
        tester.getTopLeft(rowNamed('Rye bread')).dy -
            tester.getTopLeft(rowNamed('Eggs')).dy,
        lessThan(0),
        reason: 'on top of the list',
      );
      expect(first, isNotNull);
    },
  );

  testWidgets('a name a product of the list has is refused', (tester) async {
    await pumpApp(tester);
    await deleteRow(tester, 'Bread');
    await openMenu(tester, 'Archive');
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    await tester.enterText(field, 'eggs');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(find.text('Already in the list'), findsOneWidget);
    expect(find.byType(CardDialog), findsOneWidget);
  });

  testWidgets('restoring the last product closes the archive', (tester) async {
    await pumpApp(tester);
    await deleteRow(tester, 'Bread');
    await openMenu(tester, 'Archive');
    await tester.tap(find.text('Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();
    expect(find.byType(CardDialog), findsNothing);
    expect(find.byKey(const Key('menuButton')), findsOneWidget);
    expect(rowNamed('Bread'), findsOneWidget);
  });
}
