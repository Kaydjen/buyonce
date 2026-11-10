import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show needIn, pumpApp, rowNamed;

Future<void> longPress(WidgetTester tester, String name) async {
  await tester.longPress(rowNamed(name));
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String name) =>
    tester.getTopLeft(find.text(name)).dy;

Finder get handle => find.byIcon(Icons.drag_indicator);

Finder get field => find.descendant(
  of: find.byType(CardDialog),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('a long press shows the menu above the row and the drag handle', (
    tester,
  ) async {
    await pumpApp(tester);
    final x = tester.getTopLeft(find.text('Bread')).dx;
    await longPress(tester, 'Bread');
    expect(find.byKey(const Key('menuRename')), findsOneWidget);
    expect(find.byKey(const Key('menuDelete')), findsOneWidget);
    expect(handle, findsOneWidget);
    // The row slid to the right to make room for the handle.
    expect(tester.getTopLeft(find.text('Bread')).dx, greaterThan(x + 20));
  });

  testWidgets('the row is dragged by its handle, not by a long press', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(top(tester, 'Bread') < top(tester, 'Eggs'), isTrue);

    // A long press and a drag on the row itself does not move it any more.
    final press = await tester.startGesture(
      tester.getCenter(find.text('Bread')),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await press.moveBy(const Offset(0, 150));
    await tester.pump();
    await press.up();
    await tester.pumpAndSettle();
    expect(top(tester, 'Bread') < top(tester, 'Eggs'), isTrue);
    await tester.tapAt(const Offset(5, 400)); // closes the menu
    await tester.pumpAndSettle();

    await longPress(tester, 'Bread');
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(top(tester, 'Eggs') < top(tester, 'Bread'), isTrue);
    expect(find.byKey(const Key('menuRename')), findsNothing);
  });

  testWidgets('a tap on a row closes the menu and changes nothing else', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(needIn('Bread'), findsNothing);
    await longPress(tester, 'Bread');
    await tester.tap(rowNamed('Eggs'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menuRename')), findsNothing);
    expect(handle, findsNothing);
    expect(
      needIn('Eggs'),
      findsNothing,
      reason: 'the tap only closed the menu',
    );
    // Without a menu a tap works as before.
    await tester.tap(rowNamed('Eggs'));
    await tester.pumpAndSettle();
    expect(needIn('Eggs'), findsOneWidget);
  });

  testWidgets('scrolling the list closes the menu', (tester) async {
    await pumpApp(tester);
    await longPress(tester, 'Bread');
    expect(find.byKey(const Key('menuRename')), findsOneWidget);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('menuRename')), findsNothing);
  });

  testWidgets('only one row has the menu at a time', (tester) async {
    await pumpApp(tester);
    await longPress(tester, 'Bread');
    await longPress(tester, 'Eggs');
    expect(find.byKey(const Key('menuRename')), findsOneWidget);
    expect(handle, findsOneWidget);
  });

  testWidgets(
    'Shop: the menu is there, no handle where the list cannot be reordered',
    (tester) async {
      await pumpApp(tester, plan: false);
      // Bread is not needed: it is in the Frequent card.
      await tester.longPress(find.text('Bread').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('menuRename')), findsOneWidget);
      expect(handle, findsNothing);
    },
  );

  group('rename', () {
    Future<void> open(WidgetTester tester, String name) async {
      await longPress(tester, name);
      await tester.tap(find.byKey(const Key('menuRename')));
      await tester.pumpAndSettle();
    }

    testWidgets('the dialog starts with the name; Save changes it', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, 'Bread');
      expect(tester.widget<TextField>(field).controller!.text, 'Bread');
      await tester.enterText(field, '  Rye   bread ');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDialog), findsNothing);
      expect(rowNamed('Rye bread'), findsOneWidget);
      expect(rowNamed('Bread'), findsNothing);
    });

    testWidgets('a name another product has is refused, the dialog stays', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, 'Bread');
      await tester.enterText(field, 'eggs');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Already in the list'), findsOneWidget);
      expect(find.byType(CardDialog), findsOneWidget);
      expect(rowNamed('Bread'), findsOneWidget);
    });

    testWidgets('the same name in another letter case is allowed', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, 'Bread');
      await tester.enterText(field, 'BREAD');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDialog), findsNothing);
      expect(rowNamed('BREAD'), findsOneWidget);
    });
  });

  group('delete', () {
    testWidgets('the row goes and Undo brings it back where it was', (
      tester,
    ) async {
      await pumpApp(tester);
      final before = top(tester, 'Bread');
      await longPress(tester, 'Bread');
      await tester.tap(find.byKey(const Key('menuDelete')));
      await tester.pumpAndSettle();
      expect(rowNamed('Bread'), findsNothing);
      expect(find.text('Deleted: Bread'), findsOneWidget);
      expect(find.byKey(const Key('menuRename')), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(rowNamed('Bread'), findsOneWidget);
      expect(top(tester, 'Bread'), before);
    });

    testWidgets('a needed product leaves the To buy count', (tester) async {
      await pumpApp(tester);
      expect(find.text('4 to buy'), findsOneWidget);
      await longPress(tester, 'Milk');
      await tester.tap(find.byKey(const Key('menuDelete')));
      await tester.pumpAndSettle();
      expect(find.text('3 to buy'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('4 to buy'), findsOneWidget);
    });
  });
}
