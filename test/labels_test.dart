import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/data/services/in_memory_update_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:buyonce/presentation/view_models/update/update_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _step = Duration(milliseconds: 10);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  StyleVariant variant,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateCheckDelayProvider.overrideWithValue(_step),
        updateServiceProvider.overrideWithValue(
          InMemoryUpdateService(progressStep: _step),
        ),
      ],
      child: const BuyOnceApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(styleVariantProvider.notifier).select(variant);
  await tester.pumpAndSettle();
  return container;
}

/// Every tooltip a screen reader can announce on the current screen (needs
/// `ensureSemantics`).
Set<String> _announced(WidgetTester tester) => {
  for (final node in tester.semantics.simulatedAccessibilityTraversal())
    if (node.tooltip.isNotEmpty) node.tooltip,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Flat (design 1) and soft (design 7) build their icon buttons differently.
  for (final variant in [StyleVariant.d1, StyleVariant.d7]) {
    group('icon-only buttons are named in design ${variant.label}', () {
      testWidgets('Shop and Plan', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, variant);
        // The update check finishes: the menu button says so.
        await tester.pump(_step * 3);
        await tester.pumpAndSettle();

        expect(
          _announced(tester),
          containsAll(['Menu, update available', 'Search']),
        );

        await tester.tap(find.byKey(const Key('tabPlan')));
        await tester.pumpAndSettle();
        expect(
          _announced(tester),
          containsAll([
            // The flat top bar has a text button "Add", nothing to name.
            if (variant == StyleVariant.d7) 'Add products',
            'Search',
            'Menu, update available',
          ]),
        );

        await tester.tap(find.byKey(const Key('findButton')));
        await tester.pumpAndSettle();
        expect(_announced(tester), contains('Close search'));
        handle.dispose();
      });

      testWidgets('group screen', (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, variant);
        await tester.tap(find.byKey(const Key('groupButton')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Group settings'));
        await tester.pumpAndSettle();
        expect(_announced(tester), contains('Copy code'));
        handle.dispose();
      });
    });
  }
}
