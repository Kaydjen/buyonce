import 'dart:convert';
import 'dart:io';

import 'package:buyonce/data/repositories/settings_repository.dart';
import 'package:buyonce/data/services/settings_service.dart';
import 'package:buyonce/domain/models/app_settings.dart';
import 'package:buyonce/domain/models/purchase.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/history/history_days.dart';
import 'package:buyonce/core/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
        as Map<String, dynamic>;

Set<String> placeholders(String text) => {
  for (final m in RegExp(r'\{(\w+)\}').allMatches(text)) m.group(1)!,
};

void main() {
  group('translations', () {
    test('every English key has a Ukrainian one and the other way round', () {
      final en = arb('en').keys.where((k) => !k.startsWith('@')).toSet();
      final uk = arb('uk').keys.where((k) => !k.startsWith('@')).toSet();
      expect(en.difference(uk), isEmpty, reason: 'missing in app_uk.arb');
      expect(uk.difference(en), isEmpty, reason: 'only in app_uk.arb');
    });

    test('both languages use the same placeholders in every message', () {
      final en = arb('en');
      final uk = arb('uk');
      for (final key in en.keys.where((k) => !k.startsWith('@'))) {
        expect(
          placeholders(uk[key] as String),
          placeholders(en[key] as String),
          reason: key,
        );
      }
    });

    test('no message is empty', () {
      for (final lang in ['en', 'uk']) {
        final messages = arb(lang);
        for (final key in messages.keys.where((k) => !k.startsWith('@'))) {
          if (key == '@@locale') continue;
          expect((messages[key] as String).trim(), isNotEmpty, reason: key);
        }
      }
    });
  });

  test('the language is stored and read back', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SettingsRepository(SettingsService());
    await repo.save(const AppSettings(language: LanguageChoice.uk));
    final loaded = (await repo.load() as Ok<AppSettings>).value;
    expect(loaded.language, LanguageChoice.uk);
    expect(const AppSettings().language, LanguageChoice.system);
  });

  test('history days are named in the language asked for', () {
    final days = groupByDay(
      [],
      Duration.zero,
      DateTime.utc(2026, 11, 3),
      locale: 'uk',
    );
    expect(days, isEmpty);
    final purchases = groupByDay(
      [
        Purchase(
          productName: 'Milk',
          userId: 'me',
          markedAt: DateTime.utc(2026, 10, 28, 9),
        ),
      ],
      Duration.zero,
      DateTime.utc(2026, 11, 3),
      locale: 'uk',
    );
    expect(purchases.single.label, 'ср, 28 жовт.');
  });

  Future<void> openSettings(WidgetTester tester, String menu) async {
    await tester.tap(find.byKey(const Key('menuButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(menu));
    await tester.pumpAndSettle();
  }

  testWidgets('a Ukrainian phone gets Ukrainian text, any other gets English', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('uk', 'UA')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    expect(find.text('Купити'), findsWidgets);

    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    await tester.pumpAndSettle();
    expect(find.text('To buy'), findsWidgets);
  });

  testWidgets('the switch in Settings changes the language and is kept', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
    await tester.pumpAndSettle();
    await openSettings(tester, 'Settings');
    await tester.scrollUntilVisible(
      find.byKey(const Key('languageSelector')),
      100,
    );
    await tester.tap(find.text('Українська'));
    await tester.pumpAndSettle();
    expect(find.text('Налаштування'), findsOneWidget);
    expect(find.text('Мова'), findsOneWidget);
    final stored = await SettingsRepository(SettingsService()).load();
    expect((stored as Ok<AppSettings>).value.language, LanguageChoice.uk);
  });
}
