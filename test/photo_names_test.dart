import 'dart:async';
import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/photo_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/core/theme/style_variant.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/style_variant_view_model.dart';
import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _jpeg = Uint8List.fromList([9, 8, 7]);

Result<GeminiReply> _names(List<String> names) => ScriptedGeminiApi.text(
  '{"names":[${[for (final n in names) '"$n"'].join(',')}]}',
);

/// Opens "Add products" with a scripted camera and a scripted Gemini.
Future<(ScriptedPhotoService, ScriptedGeminiApi)> openAdd(
  WidgetTester tester, {
  required Result<GeminiReply> Function(GeminiCall call) script,
  List<Uint8List?>? photos,
  bool photoError = false,
  bool withKey = true,
  List<String>? models,
  bool narrow = false,
  bool design7 = false,
}) async {
  if (narrow) {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  if (withKey) await GeminiKeyService().write('key-1');
  if (models != null) {
    SharedPreferences.setMockInitialValues({
      'geminiModels.items': '[${[for (final m in models) '"$m"'].join(',')}]',
    });
  }
  final camera = ScriptedPhotoService(photos ?? [_jpeg], error: photoError);
  final api = ScriptedGeminiApi((c) => script(c));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        photoServiceProvider.overrideWithValue(camera),
        geminiApiProvider.overrideWithValue(api),
      ],
      child: const BuyOnceApp(),
    ),
  );
  if (design7) {
    // The product's own look: the accent is a dot (the flat test look has none).
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(styleVariantProvider.notifier)
        .select(StyleVariant.d7);
  }
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('tabPlan')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('addProducts')));
  await tester.pumpAndSettle();
  return (camera, api);
}

Future<void> tapCamera(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('photoButton')));
  await tester.pumpAndSettle();
}

TextEditingController fieldOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('draftField'))).controller!;

void main() {
  testWidgets(
    'a photo gives chips; a chip fills the field; adding clears them',
    (tester) async {
      final (camera, api) = await openAdd(
        tester,
        script: (_) => _names(['Piątnica Skyr', 'Skyr', 'Jogurt pitny']),
      );
      await tapCamera(tester);
      expect(camera.taken, 1);
      for (final n in ['Piątnica Skyr', 'Skyr', 'Jogurt pitny']) {
        expect(find.byKey(ValueKey('chip-$n')), findsOneWidget);
      }
      // The photo and the app language reach the request.
      final parts =
          ((api.calls.single.body['contents'] as List).single as Map)['parts']
              as List;
      expect((parts[0] as Map)['text'], contains('in English'));
      expect((parts[1] as Map)['inlineData']['data'], 'CQgH');

      await tester.tap(find.byKey(const ValueKey('chip-Skyr')));
      await tester.pumpAndSettle();
      final field = fieldOf(tester);
      expect(field.text, 'Skyr');
      expect(field.selection, const TextSelection.collapsed(offset: 4));

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('Skyr')), findsOneWidget); // a draft row
      expect(find.byKey(const ValueKey('chip-Skyr')), findsNothing);
      expect(find.byKey(const ValueKey('chip-Jogurt pitny')), findsNothing);
    },
  );

  testWidgets('a closed camera changes nothing', (tester) async {
    final (camera, api) = await openAdd(
      tester,
      script: (_) => _names(['x']),
      photos: [null],
    );
    await tapCamera(tester);
    expect(camera.taken, 1);
    expect(api.calls, isEmpty);
    expect(find.byKey(const Key('photoButton')), findsOneWidget);
  });

  testWidgets('no key: the key dialog first, then the camera', (tester) async {
    final (camera, api) = await openAdd(
      tester,
      script: (_) => _names(['Milk']),
      withKey: false,
    );
    await tapCamera(tester);
    expect(find.byType(CardDialog), findsOneWidget);
    expect(camera.taken, 0);

    // Cancelled: no camera.
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(camera.taken, 0);

    await tapCamera(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(CardDialog),
        matching: find.byType(TextField),
      ),
      'AIza-key',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(camera.taken, 1);
    expect(api.calls.single.apiKey, 'AIza-key');
    expect(find.byKey(const ValueKey('chip-Milk')), findsOneWidget);
  });

  testWidgets(
    'while a photo is read a spinner replaces the icon and the field works',
    (tester) async {
      final gate = Completer<void>();
      final (_, api) = await openAdd(tester, script: (_) => _names(['Tea']));
      api.gate = gate.future;
      await tester.tap(find.byKey(const Key('photoButton')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('photoBusy')), findsOneWidget);
      expect(find.byKey(const Key('photoButton')), findsNothing);
      await tester.enterText(find.byKey(const Key('draftField')), 'Bread');
      expect(fieldOf(tester).text, 'Bread');

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('photoBusy')), findsNothing);
      expect(find.byKey(const Key('photoButton')), findsOneWidget);
      expect(find.byKey(const ValueKey('chip-Tea')), findsOneWidget);
      expect(fieldOf(tester).text, 'Bread'); // what the user typed stays
    },
  );

  group('what the user is told', () {
    testWidgets(
      'the only model is limited: its name, and a way to add models',
      (tester) async {
        await openAdd(
          tester,
          models: ['only-model'],
          script: (_) => ScriptedGeminiApi.error(
            429,
            'quota',
            quotaId: 'GenerateRequestsPerDayPerProjectPerModel-FreeTier',
          ),
        );
        await tapCamera(tester);
        expect(find.text('only-model: limit reached'), findsOneWidget);
        await tester.tap(find.text('Add models'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('addModel')),
          findsOneWidget,
        ); // Models screen
        expect(find.text('only-model'), findsOneWidget);
      },
    );

    testWidgets('every model is limited', (tester) async {
      await openAdd(
        tester,
        script: (_) => ScriptedGeminiApi.error(
          429,
          'quota',
          quotaId: 'GenerateRequestsPerMinutePerProjectPerModel-FreeTier',
          retryDelay: '30s',
        ),
      );
      await tapCamera(tester);
      expect(find.text('All models reached their limit'), findsOneWidget);
      expect(find.text('Add models'), findsOneWidget);
    });

    testWidgets('no network: Retry asks about the same photo, no new shot', (
      tester,
    ) async {
      var online = false;
      final (camera, api) = await openAdd(
        tester,
        design7: true,
        script: (_) => online ? _names(['Rice']) : ScriptedGeminiApi.offline,
      );
      await tapCamera(tester);
      expect(find.text('No connection'), findsOneWidget);
      // The accent dot sits in the button of this message.
      expect(find.byKey(const Key('toastAccentDot')), findsOneWidget);
      online = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(camera.taken, 1);
      expect(api.calls.length, 2);
      expect(find.byKey(const ValueKey('chip-Rice')), findsOneWidget);
    });

    testWidgets('nothing worked: a message with Retry', (tester) async {
      await openAdd(
        tester,
        design7: true,
        script: (_) => ScriptedGeminiApi.error(503, 'high demand'),
      );
      await tapCamera(tester);
      expect(find.text("Couldn't name this item"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Only the "No connection" button carries the accent dot.
      expect(find.byKey(const Key('toastAccentDot')), findsNothing);
    });

    testWidgets(
      'a camera that fails is told the same way, Retry opens it again',
      (tester) async {
        final (camera, _) = await openAdd(
          tester,
          script: (_) => _names(['x']),
          photoError: true,
        );
        await tapCamera(tester);
        expect(find.text("Couldn't name this item"), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(camera.taken, 2);
      },
    );

    testWidgets('a refused key: a button to the key dialog, then it retries', (
      tester,
    ) async {
      var good = false;
      final (_, api) = await openAdd(
        tester,
        script: (c) =>
            good ? _names(['Salt']) : ScriptedGeminiApi.error(403, 'denied'),
      );
      await tapCamera(tester);
      expect(find.text('Google did not accept the API key'), findsOneWidget);
      await tester.tap(find.text('API key'));
      await tester.pumpAndSettle();
      good = true;
      await tester.enterText(
        find.descendant(
          of: find.byType(CardDialog),
          matching: find.byType(TextField),
        ),
        'AIza-new',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(api.calls.last.apiKey, 'AIza-new');
      expect(find.byKey(const ValueKey('chip-Salt')), findsOneWidget);
    });
  });

  testWidgets('a photo saved before the app was killed is read on opening', (
    tester,
  ) async {
    await GeminiKeyService().write('key-1');
    final api = ScriptedGeminiApi((_) => _names(['Lost bread']));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoServiceProvider.overrideWithValue(
            ScriptedPhotoService([], lost: _jpeg),
          ),
          geminiApiProvider.overrideWithValue(api),
        ],
        child: const BuyOnceApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('addProducts')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chip-Lost bread')), findsOneWidget);
  });

  testWidgets(
    'long names at 360 dp and the largest text size do not overflow',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openAdd(
        tester,
        narrow: true,
        script: (_) => _names([
          'Mleczna Dolina Kefir Naturalny Bez Laktozy',
          'Kefir Naturalny Bez Laktozy',
          'Kefir',
        ]),
      );
      await tapCamera(tester);
      expect(find.byKey(const Key('photoButton')), findsOneWidget);
      expect(find.byType(InkWell), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
