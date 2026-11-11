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
    // The amount does not make the row taller.
    double height(String n) => tester
        .getSize(
          find.ancestor(of: rowNamed(n), matching: find.byType(ProductRow)),
        )
        .height;
    expect(height('Bread'), closeTo(height('Eggs'), 1.5)); // a divider is 1 px
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
      // 20 steps of 50 reach 1000, one more of 100 gives 1.1.
      await times(tester, 'sizeMore', 21);
      expect(textOf(tester, 'amountSize'), '1.1 kg');
      await tester.tap(find.byKey(const Key('unitL')));
      await tester.pump();
      expect(textOf(tester, 'amountSize'), '1.1 l');
      await closeEditor(tester);
      expect(
        find.descendant(
          of: rowAmount('Bread'),
          matching: find.text('2 × 1.1 l'),
        ),
        findsOneWidget,
      );

      await tester.tap(rowAmount('Bread'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'amountCount'), 'x2');
      expect(textOf(tester, 'amountSize'), '1.1 l');
      await times(tester, 'countLess', 3);
      expect(textOf(tester, 'amountCount'), 'x1');
      await closeEditor(tester);
      // Count 1: no sign at all, only the size.
      expect(
        find.descendant(of: rowAmount('Bread'), matching: find.text('1.1 l')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'small sizes: 50 steps up to 1 kg, 150 g and 450 ml are reachable',
    (tester) async {
      await pumpApp(tester);
      await openEditor(tester, 'Bread');
      await times(tester, 'sizeMore', 3);
      expect(textOf(tester, 'amountSize'), '150 g');
      await times(tester, 'sizeMore', 17);
      expect(textOf(tester, 'amountSize'), '1 kg');
      await times(tester, 'sizeLess', 1);
      expect(textOf(tester, 'amountSize'), '950 g');
      await tester.tap(find.byKey(const Key('unitL')));
      await tester.pump();
      await times(tester, 'sizeLess', 10);
      expect(textOf(tester, 'amountSize'), '450 ml');
      await closeEditor(tester);
      expect(
        find.descendant(of: rowAmount('Bread'), matching: find.text('450 ml')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a tap on a number types it', (tester) async {
    await pumpApp(tester);
    await openEditor(tester, 'Bread');
    await tester.tap(find.byKey(const Key('amountSize')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sizeField')), '175');
    await tester.tap(find.byKey(const Key('amountCount')));
    await tester.pumpAndSettle();
    // Typing the size ended when the count was tapped; the size shows as typed.
    await tester.enterText(find.byKey(const Key('countField')), '3');
    await closeEditor(tester);
    expect(
      find.descendant(of: rowAmount('Bread'), matching: find.text('3 × 175 g')),
      findsOneWidget,
    );

    // An empty size field clears the size.
    await tester.tap(rowAmount('Bread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('amountSize')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sizeField')), '');
    await closeEditor(tester);
    expect(
      find.descendant(of: rowAmount('Bread'), matching: find.text('x3')),
      findsOneWidget,
    );
  });

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
