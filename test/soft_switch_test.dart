import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/settings_view_model.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _openSettings(
  WidgetTester tester,
  StyleVariant variant,
) async {
  await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(styleVariantProvider.notifier).select(variant);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('menuButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Design 1 is flat (tint track), design 7 is soft (pressed track, raised thumb).
  for (final variant in [StyleVariant.d1, StyleVariant.d7]) {
    group(variant.name, () {
      testWidgets('a tap anywhere on the row toggles auto-send', (
        tester,
      ) async {
        final container = await _openSettings(tester, variant);
        expect(container.read(settingsProvider).autoSendEnabled, isTrue);

        // The row centre is the title, far from the track.
        await tester.tap(find.byKey(const Key('autoSendSwitch')));
        await tester.pumpAndSettle();
        expect(container.read(settingsProvider).autoSendEnabled, isFalse);

        await tester.tap(find.text('Auto-send'));
        await tester.pumpAndSettle();
        expect(container.read(settingsProvider).autoSendEnabled, isTrue);
      });

      testWidgets('the thumb moves right when on and the row is a switch', (
        tester,
      ) async {
        final container = await _openSettings(tester, variant);
        final row = find.byKey(const Key('autoSendSwitch'));
        final thumb = find.descendant(
          of: row,
          matching: find.byType(AnimatedAlign),
        );
        expect(
          tester.widget<AnimatedAlign>(thumb).alignment,
          Alignment.centerRight,
        );

        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(container.read(settingsProvider).autoSendEnabled, isFalse);
        expect(
          tester.widget<AnimatedAlign>(thumb).alignment,
          Alignment.centerLeft,
        );
      });

      testWidgets('the row is at least 56 dp high', (tester) async {
        await _openSettings(tester, variant);
        final size = tester.getSize(find.byKey(const Key('autoSendSwitch')));
        expect(size.height, greaterThanOrEqualTo(56));
      });

      testWidgets(
        'the period value is dimmed and inert while auto-send is off',
        (tester) async {
          await _openSettings(tester, variant);
          Opacity pill() => tester.widget<Opacity>(
            find
                .ancestor(
                  of: find.text('60 min'),
                  matching: find.byType(Opacity),
                )
                .first,
          );
          expect(pill().opacity, 1);

          await tester.tap(find.byKey(const Key('autoSendSwitch')));
          await tester.pumpAndSettle();
          expect(pill().opacity, 0.5);

          await tester.tap(find.byKey(const Key('autoSendPeriod')));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('period-300')), findsNothing);
        },
      );
    });
  }
}
