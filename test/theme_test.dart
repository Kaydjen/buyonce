import 'dart:io';

import 'package:buyonce/core/theme/app_tokens.dart';
import 'package:buyonce/core/theme/palette.dart';
import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/domain/models/app_settings.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/settings_view_model.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppTokens _colours(Brightness b) => Palette.colours(StyleVariant.vaulto, b);

Color scaffoldColor(WidgetTester tester) =>
    tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
    Theme.of(tester.element(find.byType(Scaffold).first))
        .scaffoldBackgroundColor;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('screens take colours from tokens, not from the palette or Colors', () {
    final offenders = <String>[];
    for (final file in Directory(
      'lib/presentation',
    ).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (text.contains('palette.dart') ||
          text.contains('AppColors') ||
          RegExp(r'\bColors\.').hasMatch(text)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  testWidgets('System / Light / Dark switch live and change every screen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final vm = container.read(settingsProvider.notifier);

    await vm.setTheme(ThemeChoice.dark);
    await tester.pumpAndSettle();
    expect(scaffoldColor(tester), _colours(Brightness.dark).background);

    await vm.setTheme(ThemeChoice.light);
    await tester.pumpAndSettle();
    expect(scaffoldColor(tester), _colours(Brightness.light).background);

    // Plan, Shop and Settings build in both themes without errors.
    for (final theme in [ThemeChoice.dark, ThemeChoice.light]) {
      await vm.setTheme(theme);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tabShop')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('themeSelector')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tabPlan')));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selector in Settings changes the theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(scaffoldColor(tester), _colours(Brightness.dark).background);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(scaffoldColor(tester), _colours(Brightness.light).background);
  });

  testWidgets(
    'every style variant builds Plan, Shop and Settings in both themes',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      for (final variant in StyleVariant.values) {
        container.read(styleVariantProvider.notifier).select(variant);
        for (final theme in [ThemeChoice.dark, ThemeChoice.light]) {
          await container.read(settingsProvider.notifier).setTheme(theme);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('tabPlan')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('tabShop')));
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}
