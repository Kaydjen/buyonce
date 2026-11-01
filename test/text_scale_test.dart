import 'package:flutter/rendering.dart';
import 'package:buyonce/data/services/in_memory_group_service.dart';
import 'package:buyonce/data/services/in_memory_list_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/app_settings.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';
import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/settings/settings_view_model.dart';
import 'package:buyonce/presentation/view_models/users/user_names_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 360 dp wide, the narrow end of phones; the text scale is set in Settings.
Future<void> pumpAt(
  WidgetTester tester,
  TextScaleChoice scale, {
  bool seed = true,
}) async {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        inMemoryListServiceProvider.overrideWithValue(
          InMemoryListService(seed: seed),
        ),
        inMemoryGroupServiceProvider.overrideWithValue(
          InMemoryGroupService(seed: seed),
        ),
      ],
      child: const BuyOnceApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  await container.read(settingsProvider.notifier).setTextScale(scale);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> closeTop(WidgetTester tester) async {
  await tester.tapAt(const Offset(180, 20));
  await tester.pumpAndSettle();
}

void expectNoOverflow(WidgetTester tester, String where) =>
    expect(tester.takeException(), isNull, reason: where);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the scale choices are System, 130% and 150%', () {
    expect(TextScaleChoice.values.map((c) => c.factor), [null, 1.3, 1.5]);
  });

  for (final scale in TextScaleChoice.values) {
    testWidgets('screens, sheets and dialogs hold at ${scale.name}', (
      tester,
    ) async {
      await pumpAt(tester, scale);
      final media = MediaQuery.of(tester.element(find.byType(Scaffold).first));
      expect(
        media.textScaler.scale(10),
        scale.factor == null ? 10 : 10 * scale.factor!,
      );
      expectNoOverflow(tester, 'Plan');

      // Shop with my mark, the partner's mark, the Send button and the chip.
      await tester.tap(find.byKey(const Key('tabShop')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(listRepositoryProvider)
          .toggleMark('seed4', 'partner');
      await container.read(listViewModelProvider.notifier).refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Milk'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sendButton')), findsOneWidget);
      expectNoOverflow(tester, 'Shop');

      // Menu and the sheets behind it (Sort and Templates are Plan items).
      await tester.tap(find.byKey(const Key('tabPlan')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      expectNoOverflow(tester, 'menu');
      await tapText(tester, 'Sort');
      expectNoOverflow(tester, 'sort sheet');
      await closeTop(tester);
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Templates');
      expectNoOverflow(tester, 'templates sheet');
      await closeTop(tester);

      // Group sheet, dialogs, group screen.
      await tester.tap(find.byKey(const Key('groupButton')));
      await tester.pumpAndSettle();
      expectNoOverflow(tester, 'group sheet');
      await tapText(tester, 'New group');
      expectNoOverflow(tester, 'new group dialog');
      await tapText(tester, 'Cancel');
      await tester.tap(find.byKey(const Key('groupButton')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Join group');
      expectNoOverflow(tester, 'join dialog');
      await tapText(tester, 'Cancel');
      await tester.tap(find.byKey(const Key('groupButton')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Group settings');
      expectNoOverflow(tester, 'group screen');
      await tester.scrollUntilVisible(
        find.text('Delete group'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expectNoOverflow(tester, 'group screen bottom');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // History (the debug data has several days).
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      await tapText(tester, 'History');
      expectNoOverflow(tester, 'history');
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Settings, both selectors and the period sheet.
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      await tapText(tester, 'Settings');
      expectNoOverflow(tester, 'settings');
      await tester.scrollUntilVisible(
        find.byKey(const Key('versionRow')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expectNoOverflow(tester, 'settings bottom');
      // Account: the name dialog and the delete confirmation.
      for (final (key, button) in [
        ('accountName', 'Cancel'),
        ('deleteAccount', 'Keep account'),
      ]) {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expectNoOverflow(tester, key);
        await tapText(tester, button);
      }
      await tester.scrollUntilVisible(
        find.byKey(const Key('autoSendPeriod')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('autoSendPeriod')));
      await tester.pumpAndSettle();
      expectNoOverflow(tester, 'period sheet');
    });

    testWidgets('a fresh install (personal list) holds at ${scale.name}', (
      tester,
    ) async {
      await pumpAt(tester, scale, seed: false);
      expect(find.byKey(const Key('tabShop')), findsOneWidget);
      expectNoOverflow(tester, 'fresh install');
    });
  }

  testWidgets('the setting is stored and replaces the phone font scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAt(tester, TextScaleChoice.system);
    BuildContext ctx() => tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.of(ctx()).textScaler.scale(10), closeTo(11, 0.01));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container
        .read(settingsProvider.notifier)
        .setTextScale(TextScaleChoice.large);
    await tester.pumpAndSettle();
    expect(MediaQuery.of(ctx()).textScaler.scale(10), closeTo(13, 0.01));
    expect(container.read(activeGroupIdProvider), isNotNull);
  });

  for (final scale in [1.1, 1.3, 1.5]) {
    testWidgets('a 10-character name fits on a Shop row at $scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpAt(tester, TextScaleChoice.system);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      await container
          .read(userNamesProvider.notifier)
          .setName('partner', 'MMMMMMMMMM');
      await tester.tap(find.byKey(const Key('tabShop')));
      await tester.pumpAndSettle();
      await container
          .read(listRepositoryProvider)
          .toggleMark('seed4', 'partner');
      await container.read(listViewModelProvider.notifier).refresh();
      await tester.pumpAndSettle();
      final name = find.text('MMMMMMMMMM');
      expect(name, findsOneWidget);
      // The whole name is drawn: not cut by an ellipsis.
      final text = tester.widget<Text>(name);
      expect(text.overflow, TextOverflow.ellipsis);
      final box = tester.renderObject<RenderParagraph>(name);
      expect(box.didExceedMaxLines, isFalse);
      expect(tester.getRect(name).right, lessThanOrEqualTo(360));
      expectNoOverflow(tester, 'Shop row');
    });
  }
}
