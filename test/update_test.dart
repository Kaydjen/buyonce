import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/in_memory_update_service.dart';
import 'package:buyonce/data/services/service_providers.dart';
import 'package:buyonce/domain/models/app_settings.dart';
import 'package:buyonce/domain/models/update_info.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/settings_view_model.dart';
import 'package:buyonce/presentation/view_models/update/update_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const step = Duration(milliseconds: 10);

Future<ProviderContainer> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateCheckDelayProvider.overrideWithValue(step),
        updateServiceProvider.overrideWithValue(
          InMemoryUpdateService(progressStep: step),
        ),
      ],
      child: const BuyOnceApp(),
    ),
  );
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}

Future<void> wait(WidgetTester tester, int steps) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(step);
  }
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('menuButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  // The Version section is at the bottom of the list.
  await tester.drag(find.byType(ListView), const Offset(0, -2000));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('version comparison', () {
    expect(isNewerVersion('1.1.0', '1.0.0'), isTrue);
    expect(isNewerVersion('1.10.0', '1.9.3'), isTrue);
    expect(isNewerVersion('1.0.0', '1.0.0'), isFalse);
    expect(isNewerVersion('1.0.1', '1.1.0'), isFalse);
  });

  test('the fake offers 1.1.0 to 1.0.0 and nothing to 1.1.0', () async {
    final service = InMemoryUpdateService(progressStep: step);
    final newer = await service.checkForUpdate('1.0.0');
    expect((newer as Ok<UpdateInfo?>).value!.version, '1.1.0');
    final none = await service.checkForUpdate('1.1.0');
    expect((none as Ok<UpdateInfo?>).value, isNull);
  });

  test('the first download fails halfway, the second completes', () async {
    final service = InMemoryUpdateService(progressStep: step);
    final first = await service.download(const UpdateInfo('1.1.0')).toList();
    expect(first.last, isA<Failure<double>>());
    final second = await service.download(const UpdateInfo('1.1.0')).toList();
    expect((second.last as Ok<double>).value, 1.0);
  });

  testWidgets(
    'the whole story: dot, available, progress, failure, retry, install',
    (tester) async {
      await pumpApp(tester);
      await tester.pump();
      expect(find.byKey(const Key('updateDot')), findsNothing);

      // The check runs when the app has opened: the dot appears on the menu icon.
      await wait(tester, 3);
      expect(find.byKey(const Key('updateDot')), findsOneWidget);

      await openSettings(tester);
      expect(find.text('Update to 1.1.0'), findsOneWidget);
      expect(find.byKey(const Key('updateDownload')), findsOneWidget);

      await tester.tap(find.byKey(const Key('updateDownload')));
      await wait(tester, 2);
      expect(find.byKey(const Key('updateProgress')), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);

      // The first download breaks halfway: a retry button.
      await wait(tester, 5);
      expect(find.byKey(const Key('updateRetry')), findsOneWidget);
      expect(find.byKey(const Key('updateProgress')), findsNothing);

      await tester.tap(find.byKey(const Key('updateRetry')));
      await wait(tester, 12);
      expect(find.byKey(const Key('updateInstall')), findsOneWidget);

      await tester.tap(find.byKey(const Key('updateInstall')));
      await tester.pump();
      await tester.pump();
      expect(find.text('1.1.0'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('updateDot')), findsNothing);
    },
  );

  testWidgets('the dot is on the menu of Shop too', (tester) async {
    await pumpApp(tester);
    await wait(tester, 3);
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('updateDot')), findsOneWidget);
  });

  testWidgets('every state of the row fits at 150% on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await pumpApp(tester);
    await container
        .read(settingsProvider.notifier)
        .setTextScale(TextScaleChoice.larger);
    await wait(tester, 3);
    await openSettings(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('versionRow')), 100);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('updateDownload')));
    await wait(tester, 2);
    expect(tester.takeException(), isNull);
    await wait(tester, 5);
    expect(find.byKey(const Key('updateRetry')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('updateRetry')));
    await wait(tester, 12);
    expect(find.byKey(const Key('updateInstall')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
