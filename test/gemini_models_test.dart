import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/gemini_models_repository.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/data/services/settings_service.dart';
import 'package:buyonce/domain/models/gemini_task.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/gemini_models_view_model.dart';
import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _gen = ['generateContent', 'countTokens'];

GeminiModelsRepository repoWith(ScriptedGeminiApi api) =>
    GeminiModelsRepository(SettingsService(), api, GeminiKeyService());

ScriptedGeminiApi emptyApi() =>
    ScriptedGeminiApi((_) => ScriptedGeminiApi.broken);

void main() {
  group('stored list', () {
    test('the default until the user changes it', () async {
      final repo = repoWith(emptyApi());
      expect(await repo.load(GeminiTask.items), defaultItemModels);
    });

    test('a saved list is read back by a new repository', () async {
      await repoWith(emptyApi()).save(GeminiTask.items, ['b', 'a']);
      expect(await repoWith(emptyApi()).load(GeminiTask.items), ['b', 'a']);
    });

    test(
      'an unreadable or empty stored list falls back to the default',
      () async {
        final settings = SettingsService();
        for (final bad in ['not json', '{}', '[]', '["", "  "]', '[1, 2]']) {
          await settings.setString('geminiModels.items', bad);
          expect(
            await repoWith(emptyApi()).load(GeminiTask.items),
            defaultItemModels,
            reason: bad,
          );
        }
      },
    );

    test('reset returns to the default', () async {
      final repo = repoWith(emptyApi());
      await repo.save(GeminiTask.items, ['x']);
      await repo.reset(GeminiTask.items);
      expect(await repo.load(GeminiTask.items), defaultItemModels);
    });
  });

  group('the models a key can use', () {
    test('only text models that can generate content', () {
      final models = GeminiModelsRepository.usable([
        {
          'name': 'models/gemini-3.5-flash-lite',
          'displayName': 'Gemini 3.5 Flash Lite',
          'supportedGenerationMethods': _gen,
        },
        {
          'name': 'models/gemma-4-31b-it',
          'displayName': 'Gemma 4 31B IT',
          'supportedGenerationMethods': _gen,
        },
        for (final id in [
          'gemini-3.8-flash-tts',
          'gemini-3.1-flash-image',
          'nano-banana-pro-preview',
          'gemini-live-2.5-flash',
          'gemini-embedding-001',
          'gemini-robotics-er-2-preview',
          'gemini-2.5-computer-use-preview',
          'gemini-3.5-transcribe',
          'lyria-3.5',
          'deep-research-max-preview',
          'antigravity-preview-latest',
          'native-audio-model',
        ])
          {
            'name': 'models/$id',
            'displayName': id,
            'supportedGenerationMethods': _gen,
          },
        {
          'name': 'models/embed-only',
          'displayName': 'x',
          'supportedGenerationMethods': ['embedContent'],
        },
        {'name': 'models/no-methods', 'displayName': 'y'},
      ]);
      expect(
        [for (final m in models) m.id],
        ['gemini-3.5-flash-lite', 'gemma-4-31b-it'],
      );
      expect(models.first.displayName, 'Gemini 3.5 Flash Lite');
    });

    test('all pages are read and sorted by display name', () async {
      await GeminiKeyService().write('key');
      final api = ScriptedGeminiApi(
        (_) => ScriptedGeminiApi.broken,
        respondList: (token) => token == null
            ? ScriptedGeminiApi.modelPage([
                ('z-model', 'Zeta', _gen),
              ], next: 'p2')
            : ScriptedGeminiApi.modelPage([('a-model', 'alpha', _gen)]),
      );
      final result = await repoWith(api).available();
      expect(
        [for (final m in (result as Ok<List<GeminiModelInfo>>).value) m.id],
        ['a-model', 'z-model'],
      );
      expect(api.listCalls, [null, 'p2']);
    });

    test('no key, a refused key, no network, a server error', () async {
      expect(
        ((await repoWith(emptyApi()).available()) as Failure).error,
        ModelListError.noKey,
      );
      await GeminiKeyService().write('key');
      Future<Object> why(Result<GeminiReply> reply) async =>
          ((await repoWith(
                    ScriptedGeminiApi(
                      (_) => ScriptedGeminiApi.broken,
                      respondList: (_) => reply,
                    ),
                  ).available())
                  as Failure)
              .error;
      expect(
        await why(ScriptedGeminiApi.error(400, 'API key not valid')),
        ModelListError.badKey,
      );
      expect(
        await why(ScriptedGeminiApi.error(403, 'denied')),
        ModelListError.badKey,
      );
      expect(await why(ScriptedGeminiApi.offline), ModelListError.offline);
      expect(
        await why(ScriptedGeminiApi.error(500, 'oops')),
        ModelListError.failed,
      );
    });
  });

  group('GeminiModelsViewModel', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    final provider = geminiModelsProvider(GeminiTask.items);

    test('reorder puts a model where it was dropped', () async {
      final c = container();
      await c.read(provider.future);
      final vm = c.read(provider.notifier);
      await vm.reorder(2, 0);
      expect(c.read(provider).value, [
        'gemini-3.8-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
      ]);
      await vm.reorder(0, 1);
      expect(c.read(provider).value!.first, 'gemini-3.5-flash-lite');
      await vm.reorder(1, 1); // no move
      await vm.reorder(0, 9); // out of range
      expect(c.read(provider).value!.length, 3);
    });

    test('every change is stored, a new container reads it', () async {
      final c = container();
      await c.read(provider.future);
      await c.read(provider.notifier).remove('gemini-3.1-flash-lite');
      final again = container();
      expect(await again.read(provider.future), [
        'gemini-3.5-flash-lite',
        'gemini-3.8-flash',
      ]);
    });

    test('the last model cannot be removed', () async {
      final c = container();
      await c.read(provider.future);
      final vm = c.read(provider.notifier);
      await vm.remove('gemini-3.1-flash-lite');
      await vm.remove('gemini-3.8-flash');
      await vm.remove('gemini-3.5-flash-lite');
      expect(c.read(provider).value, ['gemini-3.5-flash-lite']);
    });

    test(
      'add: new ids at the end; blank, doubled and spaced ones refused',
      () async {
        final c = container();
        await c.read(provider.future);
        final vm = c.read(provider.notifier);
        expect(await vm.add(' models/gemma-4-31b-it '), isTrue);
        expect(c.read(provider).value!.last, 'gemma-4-31b-it');
        expect(await vm.add('gemma-4-31b-it'), isFalse);
        expect(await vm.add('  '), isFalse);
        expect(await vm.add('two words'), isFalse);
        expect(c.read(provider).value!.length, 4);
      },
    );

    test('reset and isDefault', () async {
      final c = container();
      await c.read(provider.future);
      final vm = c.read(provider.notifier);
      expect(vm.isDefault, isTrue);
      await vm.add('x');
      expect(vm.isDefault, isFalse);
      await vm.reset();
      expect(vm.isDefault, isTrue);
      expect(c.read(provider).value, defaultItemModels);
    });
  });

  group('Models screen', () {
    Future<void> openModels(WidgetTester tester, ScriptedGeminiApi api) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [geminiApiProvider.overrideWithValue(api)],
          child: const BuyOnceApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('menuButton')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('modelsRow')));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byKey(const Key('modelsRow')));
      await tester.pumpAndSettle();
    }

    List<String> order(WidgetTester tester) =>
        [
          for (final id in defaultItemModels)
            if (find.text(id).evaluate().isNotEmpty) id,
        ]..sort(
          (a, b) => tester
              .getTopLeft(find.text(a))
              .dy
              .compareTo(tester.getTopLeft(find.text(b)).dy),
        );

    testWidgets('rows with numbers; drag by the handle, remove, reset', (
      tester,
    ) async {
      await openModels(tester, emptyApi());
      for (final id in defaultItemModels) {
        expect(find.text(id), findsOneWidget);
      }
      expect(find.text('1'), findsOneWidget);
      expect(find.byKey(const Key('resetModels')), findsNothing);

      // The last one is dragged to the top.
      await tester.drag(
        find.byIcon(Icons.drag_indicator).at(2),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(order(tester), [
        'gemini-3.8-flash',
        'gemini-3.5-flash-lite',
        'gemini-3.1-flash-lite',
      ]);
      expect(find.byKey(const Key('resetModels')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('removeModel-gemini-3.1-flash-lite')),
      );
      await tester.pumpAndSettle();
      expect(find.text('gemini-3.1-flash-lite'), findsNothing);

      await tester.tap(find.byKey(const Key('resetModels')));
      await tester.pumpAndSettle();
      expect(order(tester), defaultItemModels);
      expect(find.byKey(const Key('resetModels')), findsNothing);
    });

    testWidgets('the picker offers the key\'s models; picking adds one', (
      tester,
    ) async {
      await GeminiKeyService().write('key');
      final api = ScriptedGeminiApi(
        (_) => ScriptedGeminiApi.broken,
        respondList: (_) => ScriptedGeminiApi.modelPage([
          ('gemma-4-31b-it', 'Gemma 4 31B IT', _gen),
          ('gemini-3.5-flash-lite', 'Gemini 3.5 Flash Lite', _gen),
          ('gemini-3.8-flash-tts', 'TTS', _gen),
        ]),
      );
      await openModels(tester, api);
      await tester.tap(find.byKey(const Key('addModel')));
      await tester.pumpAndSettle();
      expect(find.text('Gemma 4 31B IT'), findsOneWidget);
      expect(find.text('TTS'), findsNothing);
      // A model already in the list is ticked and cannot be picked again.
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.byKey(const Key('pick-gemma-4-31b-it')));
      await tester.pumpAndSettle();
      expect(find.text('gemma-4-31b-it'), findsOneWidget);
      expect(find.byKey(const Key('resetModels')), findsOneWidget);
    });

    testWidgets('the picker says why there is no list; a hand-typed id works', (
      tester,
    ) async {
      await openModels(tester, emptyApi()); // no key stored
      await tester.tap(find.byKey(const Key('addModel')));
      await tester.pumpAndSettle();
      expect(find.text('Add an API key first'), findsOneWidget);
      expect(find.byKey(const Key('retryModels')), findsOneWidget);

      await tester.tap(find.byKey(const Key('otherModel')));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(CardDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'gemini-3.5-flash-lite');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      expect(find.text('Already in the list'), findsOneWidget);

      await tester.enterText(field, 'my-model');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await tester.pumpAndSettle();
      // Back on the Models screen with the new row.
      expect(find.text('my-model'), findsOneWidget);
    });
  });
}
