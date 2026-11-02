import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, StyleVariant variant) async {
  await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(styleVariantProvider.notifier).select(variant);
  await tester.pumpAndSettle();
}

/// The visible plate of a card action (its Ink).
Rect _plate(WidgetTester tester, String key) => tester.getRect(
  find
      .descendant(of: find.byKey(Key(key)), matching: find.byType(Ink))
      .first,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The flat design 1 uses stock buttons (already 48 dp); the soft one has plates.
  testWidgets('card icon action reacts 4 dp outside its plate', (tester) async {
    await _pump(tester, StyleVariant.d7);
    final plate = _plate(tester, 'findButton');
    expect(plate.size, const Size(38, 38));
    final fields = find.byType(TextField).evaluate().length;

    // Just outside the plate on its left, inside the 48 dp area.
    await tester.tapAt(Offset(plate.left - 4, plate.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).evaluate().length, greaterThan(fields));
  });

  testWidgets('card icon action ignores a tap 8 dp outside', (tester) async {
    await _pump(tester, StyleVariant.d7);
    final plate = _plate(tester, 'findButton');
    final fields = find.byType(TextField).evaluate().length;

    await tester.tapAt(Offset(plate.left - 8, plate.center.dy));
    await tester.pumpAndSettle();
    expect(find.byType(TextField).evaluate().length, fields);
  });

  testWidgets('card text action reacts 4 dp above its plate', (tester) async {
    await _pump(tester, StyleVariant.d7);
    final plate = _plate(tester, 'markAll');
    // The touch area is 48 dp high, symmetric around the plate.
    expect(plate.height, greaterThanOrEqualTo(38));
    expect(plate.height, lessThanOrEqualTo(43));

    await tester.tapAt(Offset(plate.center.dx, plate.top - 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('markAll')), findsNothing);
  });

  testWidgets('card text action ignores a tap 8 dp above', (tester) async {
    await _pump(tester, StyleVariant.d7);
    final plate = _plate(tester, 'markAll');

    await tester.tapAt(Offset(plate.center.dx, plate.top - 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('markAll')), findsOneWidget);
  });

  testWidgets('segments are 48 dp high', (tester) async {
    await _pump(tester, StyleVariant.d7);
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final segment = find.ancestor(
      of: find.text('Dark'),
      matching: find.byType(InkWell),
    );
    expect(segment, findsWidgets);
    expect(tester.getSize(segment.first).height, 48);
  });
}
