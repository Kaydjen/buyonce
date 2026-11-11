import 'dart:convert';
import 'dart:typed_data';

import 'package:buyonce/core/utils/result.dart';
import 'package:buyonce/data/services/gemini_api.dart';
import 'package:buyonce/data/services/gemini_key_service.dart';
import 'package:buyonce/data/services/photo_service.dart';
import 'package:buyonce/data/services/scripted_gemini_api.dart';
import 'package:buyonce/data/repositories/receipt_alias_repository.dart';
import 'package:buyonce/domain/models/receipt_matching.dart';
import 'package:buyonce/main.dart';
import 'package:buyonce/presentation/view_models/groups/groups_view_model.dart';

import 'receipt_fixtures.dart';

import 'package:buyonce/presentation/view_models/list/list_view_model.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_review_view_model.dart';
import 'package:buyonce/presentation/view_models/receipt/receipt_scan_view_model.dart';
import 'package:buyonce/presentation/widgets/card_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _jpeg = Uint8List.fromList([9, 8, 7]);

final _answer = jsonEncode({
  'store': 'Auchan',
  'currency': 'PLN',
  'total': '35,00',
  'lines': [
    {
      'raw': 'MLEKO',
      'kind': 'item',
      'evidence': 'MLEKO',
      'meaning': 'mleko = milk',
      'match': 'Milk',
      'confidence': 'high',
      'price': '10,00',
    },
    {'raw': 'KOMIN', 'kind': 'item', 'name': 'Komin', 'price': '25,00'},
  ],
});

/// Opens the app on Shop (its start screen) with a scripted camera and Gemini.
Future<(ProviderContainer, ScriptedPhotoService, ScriptedGeminiApi)> openShop(
  WidgetTester tester, {
  Result<GeminiReply> Function(GeminiCall call)? script,
  List<Uint8List?>? photos,
  bool photoError = false,
  bool withKey = true,
}) async {
  if (withKey) await GeminiKeyService().write('key-1');
  final camera = ScriptedPhotoService(
    photos ?? [_jpeg, _jpeg, _jpeg, _jpeg],
    error: photoError,
  );
  final api = ScriptedGeminiApi(script ?? (c) => receiptReply(c, _answer));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        photoServiceProvider.overrideWithValue(camera),
        geminiApiProvider.overrideWithValue(api),
      ],
      child: const BuyOnceApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return (container, camera, api);
}

Future<void> tapScan(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('scanReceipt')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the scan icon is in Shop, not in Plan', (tester) async {
    await openShop(tester);
    expect(find.byKey(const Key('scanReceipt')), findsOneWidget);
    expect(find.byKey(const Key('addProducts')), findsNothing);
    await tester.tap(find.byKey(const Key('tabPlan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanReceipt')), findsNothing);
    expect(find.byKey(const Key('addProducts')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tabShop')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scanReceipt')), findsOneWidget);
  });

  testWidgets('one photo: Read sends it and the review is ready', (
    tester,
  ) async {
    final (c, camera, api) = await openShop(tester);
    await tapScan(tester);
    expect(camera.taken, 1);
    expect(api.warmUps, 1);
    expect(find.byType(CardDialog), findsOneWidget);
    expect(find.text('Photos: 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiptRead')));
    await tester.pumpAndSettle();
    final parts =
        ((api.calls.first.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 2); // prompt + one photo
    expect((parts[0] as Map)['text'], contains('Milk'));
    expect(c.read(receiptReviewProvider), isNotNull);
    final review = c.read(receiptReviewProvider)!;
    expect(review.store, 'Auchan');
    expect(review.fresh.single.name, 'Komin');
  });

  testWidgets('Add photo opens the camera again; three photos read at once', (
    tester,
  ) async {
    final (c, camera, api) = await openShop(tester);
    await tapScan(tester);
    await tester.tap(find.byKey(const Key('receiptMore')));
    await tester.pumpAndSettle();
    expect(camera.taken, 2);
    expect(find.text('Photos: 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('receiptMore')));
    await tester.pumpAndSettle();
    // The third shot is the last: no question, the reading starts.
    expect(camera.taken, 3);
    expect(find.byType(CardDialog), findsNothing);
    final parts =
        ((api.calls.first.body['contents'] as List).single as Map)['parts']
            as List;
    expect(parts.length, 4);
    expect(c.read(receiptReviewProvider), isNotNull);
  });

  testWidgets('closing the dialog throws the photo away', (tester) async {
    final (c, _, api) = await openShop(tester);
    await tapScan(tester);
    await tester.tapAt(const Offset(5, 5)); // the veil
    await tester.pumpAndSettle();
    expect(find.byType(CardDialog), findsNothing);
    expect(api.calls, isEmpty);
    expect(c.read(receiptScanProvider).photos, 0);
  });

  testWidgets('a closed camera does nothing', (tester) async {
    final (_, camera, api) = await openShop(tester, photos: [null]);
    await tapScan(tester);
    expect(camera.taken, 1);
    expect(find.byType(CardDialog), findsNothing);
    expect(api.calls, isEmpty);
  });

  testWidgets('no key: the key dialog first, no camera', (tester) async {
    final (_, camera, _) = await openShop(tester, withKey: false);
    await tapScan(tester);
    expect(find.byType(CardDialog), findsOneWidget);
    expect(camera.taken, 0);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(camera.taken, 0);
  });

  testWidgets('a failure: a message with Retry that reads the same photo', (
    tester,
  ) async {
    var n = 0;
    final (c, camera, api) = await openShop(
      tester,
      script: (c) {
        if (isMatcherCall(c)) return receiptReply(c, _answer);
        return ++n == 1
            ? ScriptedGeminiApi.text('not json')
            : receiptReply(c, _answer);
      },
    );
    await tapScan(tester);
    await tester.tap(find.byKey(const Key('receiptRead')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    expect(c.read(receiptReviewProvider), isNull);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(camera.taken, 1); // no new shot
    expect(api.calls.length, greaterThanOrEqualTo(2));
    expect(c.read(receiptReviewProvider), isNotNull);
  });

  testWidgets('a broken camera is told the same way', (tester) async {
    await openShop(tester, photoError: true);
    await tapScan(tester);
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    expect(find.byType(CardDialog), findsNothing);
  });

  group('review screen', () {
    // The reader and the second reader disagree about the milk line.
    final disagree = jsonEncode({
      'matches': [
        {'index': 0, 'evidence': 'MLEKO', 'match': null},
      ],
    });

    Future<ProviderContainer> openReview(
      WidgetTester tester, {
      String? answer,
      String? matcher,
    }) async {
      final (c, _, _) = await openShop(
        tester,
        script: (call) =>
            receiptReply(call, answer ?? _answer, matcher: matcher),
      );
      await tapScan(tester);
      await tester.tap(find.byKey(const Key('receiptRead')));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('opens after reading: the list against the receipt', (
      tester,
    ) async {
      final c = await openReview(tester);
      expect(find.text('Auchan'), findsOneWidget);
      // Milk is one of the four planned products and is on the receipt.
      expect(find.text('Bought 1 of 4'), findsOneWidget);
      expect(find.byKey(const Key('inCard')), findsOneWidget);
      expect(find.byKey(const Key('checkCard')), findsNothing);
      expect(find.text('Milk'), findsWidgets);
      // The printed text is beside the match, to check it against.
      expect(find.byKey(const Key('printed-r0')), findsOneWidget);
      expect(find.text('MLEKO'), findsOneWidget);
      // What the list wanted and the receipt does not show.
      expect(find.byKey(const Key('missingCard')), findsOneWidget);
      expect(find.text('Salad'), findsOneWidget);
      // The other line is folded away and nothing is asked about it.
      expect(find.text('1 more receipt lines'), findsOneWidget);
      expect(find.text('Komin'), findsNothing);
      expect(find.text('Check off 1'), findsOneWidget);
      expect(c.read(receiptScanProvider).reviewReady, isFalse);
    });

    testWidgets(
      'Check off writes the mark, the trace, the receipt; learns the pair',
      (tester) async {
        final c = await openReview(tester);
        await tester.tap(find.byKey(const Key('markReceipt')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('markReceipt')), findsNothing);
        expect(find.text('Marked: 1'), findsOneWidget);
        final s = c.read(listViewModelProvider).requireValue;
        final milk = s.products.firstWhere((p) => p.name == 'Milk');
        expect(s.products.any((p) => p.name == 'Komin'), isFalse);
        final trip = s.trips.firstWhere((t) => t.userId == s.userId);
        expect(trip.marks.single.productId, milk.id);
        expect(trip.marks.single.receiptText, 'MLEKO');
        expect(trip.marks.single.price?.minor, 1000);
        expect(trip.receipts.single.store, 'Auchan');
        expect(c.read(receiptReviewProvider), isNull);
        // The photos are gone with the review.
        expect(c.read(receiptScanProvider.notifier).photos, isEmpty);
        final learned = await c
            .read(receiptAliasRepositoryProvider)
            .load(c.read(activeGroupIdProvider)!);
        expect(learned[printedKey('MLEKO')], milk.id);
      },
    );

    testWidgets('a line that is not on the list is added only when ticked', (
      tester,
    ) async {
      final c = await openReview(tester);
      await tester.tap(find.byKey(const Key('moreLines')));
      await tester.pumpAndSettle();
      expect(find.text('Komin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('check-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Check off 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('markReceipt')));
      await tester.pumpAndSettle();
      final s = c.read(listViewModelProvider).requireValue;
      final komin = s.products.firstWhere((p) => p.name == 'Komin');
      expect(komin.planned, isFalse);
      expect(s.myMarkIds, contains(komin.id));
    });

    testWidgets('back writes nothing and drops the review and the photos', (
      tester,
    ) async {
      final c = await openReview(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inCard')), findsNothing);
      expect(c.read(receiptReviewProvider), isNull);
      expect(c.read(receiptScanProvider.notifier).photos, isEmpty);
      final s = c.read(listViewModelProvider).requireValue;
      expect(s.products.any((p) => p.name == 'Komin'), isFalse);
      expect(s.trips.where((t) => t.userId == s.userId), isEmpty);
    });

    testWidgets(
      'a doubtful match is shown first, unticked, with the printed text and its reading',
      (tester) async {
        final c = await openReview(tester, matcher: disagree);
        expect(find.byKey(const Key('checkCard')), findsOneWidget);
        expect(find.byKey(const Key('inCard')), findsNothing);
        expect(find.byKey(const Key('printed-r0')), findsOneWidget);
        expect(find.text('mleko = milk'), findsOneWidget);
        // Nothing is ticked, so the button is on screen but off.
        expect(find.text('Check off 0'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('markReceipt')))
              .onPressed,
          isNull,
        );
        expect(find.text('Bought 0 of 4'), findsOneWidget);
        // The user looks at it and agrees.
        await tester.tap(find.byKey(const Key('check-r0')));
        await tester.pumpAndSettle();
        expect(find.text('Check off 1'), findsOneWidget);
        expect(find.text('Bought 1 of 4'), findsOneWidget);
        expect(c.read(receiptReviewProvider)!.chosen.single.name, 'Milk');
      },
    );

    testWidgets('a wrong match: pick another product, or "None of these"', (
      tester,
    ) async {
      final c = await openReview(tester, matcher: disagree);
      await tester.tap(find.byKey(const Key('name-r0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('pickerSearch')), 'bread');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bread'));
      await tester.pumpAndSettle();
      var row = c.read(receiptReviewProvider)!.found.single;
      expect(row.name, 'Bread');
      expect(row.checked, isTrue); // chosen by hand: a decision
      expect(find.byKey(const Key('checkCard')), findsNothing);

      await tester.tap(find.byKey(const Key('name-r0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pickNone')));
      await tester.pumpAndSettle();
      final review = c.read(receiptReviewProvider)!;
      expect(review.found, isEmpty);
      expect(review.fresh.map((r) => r.name), contains('MLEKO'));
      expect(review.fresh.every((r) => !r.checked), isTrue);
      expect(find.text('2 more receipt lines'), findsOneWidget);
    });

    testWidgets(
      'a product the receipt does not show can be pointed at a line',
      (tester) async {
        final c = await openReview(tester);
        // "Salad" is wanted, the receipt shows no salad; the spare line is its.
        await tester.tap(find.byKey(const ValueKey('missing-seed4')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('link-r1')));
        await tester.pumpAndSettle();
        final review = c.read(receiptReviewProvider)!;
        expect(review.confirmed.map((r) => r.name), contains('Salad'));
        expect(review.fresh, isEmpty);
        expect(find.byKey(const ValueKey('missing-seed4')), findsNothing);
        expect(find.text('Bought 2 of 4'), findsOneWidget);
      },
    );

    testWidgets('the photos of the receipt open for checking', (tester) async {
      await openReview(tester);
      await tester.tap(find.byKey(const Key('viewReceipt')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('receiptPhotos')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('inCard')), findsOneWidget);
    });

    testWidgets(
      'a spare line is renamed in place; a catalog name moves it up',
      (tester) async {
        final c = await openReview(tester);
        await tester.tap(find.byKey(const Key('moreLines')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('name-r1')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Eggs');
        await tester.tap(find.widgetWithText(TextButton, 'Save'));
        await tester.pumpAndSettle();
        final review = c.read(receiptReviewProvider)!;
        expect(review.fresh, isEmpty);
        expect(review.confirmed.map((r) => r.name), ['Milk', 'Eggs']);
        expect(find.text('Check off 2'), findsOneWidget);
      },
    );
  });
}
