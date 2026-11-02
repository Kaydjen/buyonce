import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, StyleVariant variant) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(styleVariantProvider.notifier).select(variant);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final variant in [StyleVariant.d7]) {
    testWidgets(
      '${variant.name}: the Plan button fades in, the menu keeps its place',
      (tester) async {
        await _pump(tester, variant);
        expect(find.byKey(const Key('addProducts')), findsNothing);
        final menuShop = tester.getCenter(find.byKey(const Key('menuButton')));

        await tester.tap(find.byKey(const Key('tabPlan')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final add = find.byKey(const Key('addProducts'));
        expect(add, findsOneWidget);
        final opacity = tester.widget<Opacity>(
          find.ancestor(of: add, matching: find.byType(Opacity)).first,
        );
        expect(opacity.opacity, inExclusiveRange(0, 1), reason: 'mid-fade');

        await tester.pumpAndSettle();
        expect(
          tester.getCenter(find.byKey(const Key('menuButton'))),
          menuShop,
          reason: 'the button does not push the menu',
        );
        await tester.tap(find.byKey(const Key('tabShop')));
        await tester.pumpAndSettle();
        expect(add, findsNothing);
      },
    );
  }
}
