import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/settings_repository.dart';
import 'package:buyonce/data/services/settings_service.dart';
import 'package:buyonce/domain/models/app_settings.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/settings/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SettingsRepository repo() => SettingsRepository(SettingsService());

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults when nothing is stored', () async {
    final result = await repo().load();
    expect((result as Ok<AppSettings>).value, const AppSettings());
  });

  test(
    'saved values are read back by a new repository (app restart)',
    () async {
      const saved = AppSettings(
        autoSendEnabled: false,
        autoSendSeconds: 900,
        theme: ThemeChoice.light,
      );
      expect(await repo().save(saved), isA<Ok<void>>());
      final result = await repo().load();
      expect((result as Ok<AppSettings>).value, saved);
    },
  );

  test('an unknown stored period or theme falls back to the default', () async {
    SharedPreferences.setMockInitialValues({
      'autoSendSeconds': 7,
      'theme': 'purple',
    });
    final result = await repo().load();
    expect((result as Ok<AppSettings>).value, const AppSettings());
  });

  test('the view model loads stored values and saves changes', () async {
    SharedPreferences.setMockInitialValues({'autoSendSeconds': 1800});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(settingsProvider).autoSendSeconds, 3600);
    await pumpEventQueue();
    expect(container.read(settingsProvider).autoSendSeconds, 1800);

    await container.read(settingsProvider.notifier).setTheme(ThemeChoice.dark);
    final stored = await repo().load();
    expect((stored as Ok<AppSettings>).value.theme, ThemeChoice.dark);
  });

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
  }

  for (final shop in [false, true]) {
    testWidgets('Settings opens from the menu on ${shop ? 'Shop' : 'Plan'}', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
      await tester.pumpAndSettle();
      if (shop) {
        await tester.tap(find.byKey(const Key('tabShop')));
        await tester.pumpAndSettle();
      }
      await openMenu(tester);
      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('60 min'), findsOneWidget);
      for (final section in [
        'AUTO-SEND',
        'THEME',
        'TEXT SIZE',
        'ACCOUNT',
        'VERSION',
      ]) {
        await tester.scrollUntilVisible(find.text(section), 100);
        expect(find.text(section), findsOneWidget);
      }
    });
  }

  Future<void> openSettings(WidgetTester tester) async {
    await openMenu(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  Future<void> markMilkInShop(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the period offers 30 s and the new period sets the next deadline',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('autoSendPeriod')));
      await tester.pumpAndSettle();
      expect(find.text('30 s'), findsOneWidget);
      expect(find.text('120 min'), findsOneWidget);
      await tester.tap(find.byKey(const Key('period-300')));
      await tester.pumpAndSettle();
      expect(find.text('5 min'), findsOneWidget);
      await back(tester);

      await markMilkInShop(tester);
      expect(find.text('Auto · in 5 min'), findsOneWidget);
    },
  );

  testWidgets('switching auto-send off hides the chip and stops the timer', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    await markMilkInShop(tester);
    expect(find.byKey(const Key('autoChip')), findsOneWidget);

    await openSettings(tester);
    await tester.tap(find.byKey(const Key('autoSendSwitch')));
    await tester.pumpAndSettle();
    await back(tester);
    expect(find.byKey(const Key('autoChip')), findsNothing);

    // A new mark does not start a countdown either.
    await tester.tap(find.text('Buns'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('autoChip')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    expect(container.read(idleTimersProvider), isEmpty);
  });
}
