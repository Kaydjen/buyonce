import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/repositories/gemini_key_repository.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/settings/gemini_key_view_model.dart';
import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openGemini(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: BuyOnceApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('menuButton')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('apiKeyRow')));
  await tester.pumpAndSettle();
}

void main() {
  group('GeminiKeyRepository', () {
    test(
      'saves the key without the spaces around it and reads it back',
      () async {
        final repo = GeminiKeyRepository(GeminiKeyService());
        expect(await repo.load(), isNull);
        final saved = await repo.save('  AIza-test-key-1234 \n');
        expect((saved as Ok<String>).value, 'AIza-test-key-1234');
        // A new service on the same storage = the app after a restart.
        expect(
          await GeminiKeyRepository(GeminiKeyService()).load(),
          'AIza-test-key-1234',
        );
      },
    );

    test('refuses an empty key and a key with a space inside', () async {
      final repo = GeminiKeyRepository(GeminiKeyService());
      for (final bad in ['', '   ', 'two words', 'a\nb']) {
        final result = await repo.save(bad);
        expect(result, isA<Failure<String>>(), reason: bad);
        expect((result as Failure<String>).error, GeminiKeyError.invalid);
      }
      expect(await repo.load(), isNull);
    });

    test('clear removes the key', () async {
      final repo = GeminiKeyRepository(GeminiKeyService());
      await repo.save('AIza-test-key-1234');
      await repo.clear();
      expect(await repo.load(), isNull);
    });
  });

  test('maskedKey shows only the last four characters', () {
    expect(maskedKey('AIza-test-key-1234'), '••••1234');
  });

  testWidgets(
    'Settings > Gemini: add, mask, replace-check and remove the key',
    (tester) async {
      await openGemini(tester);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byKey(const Key('apiKeyRemove')), findsNothing);

      await tester.tap(find.byKey(const Key('apiKeyRow')));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(CardDialog),
        matching: find.byType(TextField),
      );
      // A key with a space inside is refused and the dialog stays.
      await tester.enterText(field, 'bad key');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('That is not an API key'), findsOneWidget);
      expect(find.byType(CardDialog), findsOneWidget);

      await tester.enterText(field, ' AIza-test-key-1234 ');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(CardDialog), findsNothing);
      expect(find.text('••••1234'), findsOneWidget);
      expect(find.text('AIza-test-key-1234'), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(
        await container.read(geminiKeyRepositoryProvider).load(),
        'AIza-test-key-1234',
      );

      await tester.ensureVisible(find.byKey(const Key('apiKeyRemove')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('apiKeyRemove')));
      await tester.pumpAndSettle();
      expect(find.text('Add'), findsOneWidget);
      expect(find.byKey(const Key('apiKeyRemove')), findsNothing);
      expect(await container.read(geminiKeyRepositoryProvider).load(), isNull);
    },
  );
}
