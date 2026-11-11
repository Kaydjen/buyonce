import 'package:buyonce/presentation/widgets/product_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_test.dart' show goShop, pumpApp, rowNamed;

Finder rowAmount(String name) => find.descendant(
  of: find.ancestor(of: rowNamed(name), matching: find.byType(ProductRow)),
  matching: find.byKey(const Key('amountButton')),
);

Future<void> openEditor(WidgetTester tester, String name) async {
  await tester.longPress(rowNamed(name));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('menuAmount')));
  await tester.pumpAndSettle();
}

/// Closes the card the way a user does: a tap on the veil.
Future<void> closeEditor(WidgetTester tester) async {
  await tester.tapAt(const Offset(4, 4));
  await tester.pumpAndSettle();
}

Future<void> times(WidgetTester tester, String key, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.tap(find.byKey(Key(key)));
    await tester.pump();
  }
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  testWidgets('a row without an amount shows none; the menu sets it', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(rowAmount('Bread'), findsNothing);

    await openEditor(tester, 'Bread');
    expect(textOf(tester, 'amountCount'), 'x1');
    expect(textOf(tester, 'amountSize'), '–');
    await times(tester, 'countMore', 1);
    expect(textOf(tester, 'amountCount'), 'x2');
    await closeEditor(tester);

    expect(rowAmount('Bread'), findsOneWidget);
    expect(
      find.descendant(of: rowAmount('Bread'), matching: find.text('x2')),
      findsOneWidget,
    );
  });

  testWidgets(
    'count and size are set together; a tap on the number edits both',
    (tester) async {
      await pumpApp(tester);
      await openEditor(tester, 'Bread');
      await times(tester, 'countMore', 1);
      await times(tester, 'sizeMore', 15);
      expect(textOf(tester, 'amountSize'), '1.5');
      await tester.tap(find.byKey(const Key('unitL')));
      await tester.pump();
      await closeEditor(tester);
      expect(
        find.descendant(
          of: rowAmount('Bread'),
          matching: find.text('x2 1.5 l'),
        ),
        findsOneWidget,
      );

      await tester.tap(rowAmount('Bread'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'amountCount'), 'x2');
      expect(textOf(tester, 'amountSize'), '1.5');
      await times(tester, 'countLess', 3);
      expect(textOf(tester, 'amountCount'), 'x1');
      await closeEditor(tester);
      expect(
        find.descendant(of: rowAmount('Bread'), matching: find.text('1.5 l')),
        findsOneWidget,
      );
    },
  );

  testWidgets('minus down to the default clears the amount', (tester) async {
    await pumpApp(tester);
    await openEditor(tester, 'Bread');
    await times(tester, 'countMore', 2);
    await closeEditor(tester);
    expect(rowAmount('Bread'), findsOneWidget);

    await tester.tap(rowAmount('Bread'));
    await tester.pumpAndSettle();
    await times(tester, 'countLess', 2);
    await closeEditor(tester);
    expect(rowAmount('Bread'), findsNothing);
  });

  testWidgets('the amount follows the product to Shop and into the mark', (
    tester,
  ) async {
    await pumpApp(tester);
    await openEditor(tester, 'Bread');
    await times(tester, 'countMore', 2);
    await closeEditor(tester);

    await goShop(tester);
    expect(
      find.descendant(of: rowAmount('Bread'), matching: find.text('x3')),
      findsOneWidget,
    );
    // A tap marks the product; the mark carries the amount, which can then be edited.
    await tester.tap(rowNamed('Bread'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: rowAmount('Bread'), matching: find.text('x3')),
      findsOneWidget,
    );
    await tester.tap(rowAmount('Bread'));
    await tester.pumpAndSettle();
    await times(tester, 'countMore', 1);
    await closeEditor(tester);
    expect(
      find.descendant(of: rowAmount('Bread'), matching: find.text('x4')),
      findsOneWidget,
    );
  });
}
